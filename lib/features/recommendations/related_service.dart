import 'dart:math' as math;

import '../sources/domain/media_item.dart';

/// Light-weight TF-IDF + cosine similarity over textual features
/// (genre / category / cast / director / plot / year / kind).
/// The index is built once when the IPTV catalog is loaded.
class RelatedService {
  static final _tokenizer = RegExp(r"[A-Za-zÇçĞğİıÖöŞşÜü0-9']+");
  static const _stopwords = {
    'and',
    'the',
    'of',
    'a',
    'an',
    'in',
    'on',
    'to',
    'is',
    'with',
    've',
    'ile',
    'bir',
    'bu',
    'da',
    'de',
    'için',
    'ki',
  };

  final Map<String, Map<String, double>> _docVectors = {};
  final Map<String, double> _idf = {};
  bool _built = false;

  void build(
    Iterable<MediaItem> items, [
    Map<String, MediaDetail> details = const {},
  ]) {
    _docVectors.clear();
    _idf.clear();
    final docTokens = <String, List<String>>{};
    final df = <String, int>{};

    for (final item in items) {
      final detail = details[item.id];
      final tokens = _tokensFor(item, detail);
      docTokens[item.id] = tokens;
      for (final t in tokens.toSet()) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = docTokens.length.toDouble();
    if (n == 0) {
      _built = true;
      return;
    }
    df.forEach((token, count) {
      _idf[token] = math.log((n + 1) / (count + 1)) + 1;
    });

    for (final entry in docTokens.entries) {
      final tf = <String, int>{};
      for (final t in entry.value) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      final vec = <String, double>{};
      double norm = 0;
      tf.forEach((token, count) {
        final w = count.toDouble() * (_idf[token] ?? 0);
        if (w > 0) {
          vec[token] = w;
          norm += w * w;
        }
      });
      norm = math.sqrt(norm);
      if (norm > 0) {
        vec.updateAll((_, v) => v / norm);
      }
      _docVectors[entry.key] = vec;
    }
    _built = true;
  }

  bool get isReady => _built;

  /// Incremental update: enrich a single document's vector with the detail
  /// tokens (genre/cast/director/etc.). Avoids the 150-250ms full rebuild
  /// over the entire library - instead, only this item's vector changes.
  ///
  /// IDF is intentionally NOT recomputed: a fresh detail adds tokens that
  /// were already accounted for during the initial build (or are rare
  /// enough that an approximate weight is acceptable). This keeps the
  /// update O(tokens) instead of O(items).
  void addDetail(MediaItem item, MediaDetail detail) {
    if (!_built) return;
    final tokens = _tokensFor(item, detail);
    final tf = <String, int>{};
    for (final t in tokens) {
      tf[t] = (tf[t] ?? 0) + 1;
    }
    final vec = <String, double>{};
    double norm = 0;
    tf.forEach((token, count) {
      // Approximate IDF for previously-unseen tokens - pretend they appear
      // in exactly one document so they get a high (but not infinite)
      // weight. Tokens already in the index keep their established IDF.
      final idf = _idf[token] ?? (math.log((_docVectors.length + 1) / 2) + 1);
      final w = count.toDouble() * idf;
      if (w > 0) {
        vec[token] = w;
        norm += w * w;
      }
    });
    norm = math.sqrt(norm);
    if (norm > 0) {
      vec.updateAll((_, v) => v / norm);
    }
    _docVectors[item.id] = vec;
  }

  List<MediaItem> related(
    MediaItem source,
    Iterable<MediaItem> universe, {
    int limit = 12,
  }) {
    if (!_built) return const [];
    final src = _docVectors[source.id];
    if (src == null || src.isEmpty) return const [];
    final scored = <(MediaItem, double)>[];
    for (final candidate in universe) {
      if (candidate.id == source.id) continue;
      if (candidate.kind == MediaKind.live) continue;
      final cv = _docVectors[candidate.id];
      if (cv == null || cv.isEmpty) continue;
      final score = _cosine(src, cv);
      if (score > 0.05) scored.add((candidate, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  List<MediaItem> byTag(
    String tag,
    String tagType,
    Iterable<MediaItem> universe, {
    int limit = 40,
    String? excludeId,
  }) {
    final normalized = _normalize(tag);
    final token = '$tagType:$normalized';
    final results = <(MediaItem, double)>[];
    for (final item in universe) {
      if (excludeId != null && item.id == excludeId) continue;
      final vec = _docVectors[item.id];
      if (vec == null) continue;
      final score = vec[token] ?? 0;
      if (score > 0) results.add((item, score));
    }
    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results.take(limit).map((e) => e.$1).toList();
  }

  List<String> _tokensFor(MediaItem item, MediaDetail? detail) {
    final tokens = <String>[];
    tokens.add('kind:${item.kind.name}');
    if (item.categoryName != null) {
      tokens.addAll(_weightedTokens('cat', item.categoryName!, 3));
    }
    if (item.year != null) {
      final bucket = (item.year! ~/ 5) * 5;
      tokens.addAll(List.filled(2, 'year:$bucket'));
    }
    if (detail != null) {
      for (final g in detail.genres) {
        tokens.addAll(List.filled(4, 'genre:${_normalize(g)}'));
      }
      for (final c in detail.cast) {
        tokens.addAll(List.filled(3, 'cast:${_normalize(c)}'));
      }
      for (final d in detail.directors) {
        tokens.addAll(List.filled(3, 'dir:${_normalize(d)}'));
      }
      if (detail.country != null) {
        tokens.add('country:${_normalize(detail.country!)}');
      }
      if (detail.plot != null) {
        for (final t in _wordTokens(detail.plot!)) {
          tokens.add('plot:$t');
        }
      }
    } else if (item.plot != null) {
      for (final t in _wordTokens(item.plot!)) {
        tokens.add('plot:$t');
      }
    }
    return tokens;
  }

  Iterable<String> _weightedTokens(
    String prefix,
    String value,
    int weight,
  ) sync* {
    final norm = _normalize(value);
    if (norm.isEmpty) return;
    for (var i = 0; i < weight; i++) {
      yield '$prefix:$norm';
    }
  }

  Iterable<String> _wordTokens(String text) sync* {
    for (final m in _tokenizer.allMatches(text.toLowerCase())) {
      final t = m.group(0)!;
      if (t.length <= 2) continue;
      if (_stopwords.contains(t)) continue;
      yield t;
    }
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9çğıöşü ]"), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  double _cosine(Map<String, double> a, Map<String, double> b) {
    final smaller = a.length < b.length ? a : b;
    final bigger = identical(smaller, a) ? b : a;
    double sum = 0;
    smaller.forEach((k, v) {
      final w = bigger[k];
      if (w != null) sum += v * w;
    });
    return sum;
  }
}
