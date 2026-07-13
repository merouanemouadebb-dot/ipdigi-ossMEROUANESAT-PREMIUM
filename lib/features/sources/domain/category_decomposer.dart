import 'country_names.dart';

/// The parsed form of a single category name.
///
/// - [country]: short ALL-CAPS prefix or the token that hit the lookup. Null if absent.
/// - [subCategory]: the theme part after the separator (decorative glyphs
///   stripped, parentheses and quality tags preserved).
/// - [segments]: all parts split by the separator - helps sidebar grouping
///   for 3-level names like Live TV (`["TR", "HABER", "TRT 1 HD"]`).
/// - [original]: the raw string from the panel (for debug / fallback).
class CategoryDecomposition {
  final String? country;
  final String subCategory;
  final List<String> segments;
  final String original;

  const CategoryDecomposition({
    required this.country,
    required this.subCategory,
    required this.segments,
    required this.original,
  });
}

/// Parser that heuristically discovers the common separator character of
/// category names per source (and per catalog type).
///
/// A **data-driven** approach instead of a hardcoded regex list: it scores
/// each unique non-alphanumeric character by how many categories it appears
/// in and how consistent its position within the category is; the
/// highest-scoring candidate is picked as the separator. This way, when the
/// panel format shifts from "TR:Netflix" to "TR ✨ Netflix" or "TR » Drama",
/// no code change is needed.
///
/// Workflow:
///   1. [CategoryDecomposer.analyze] - analyzes every category name from
///      the source and derives the splitter + prefix length hint.
///   2. [parse] - splits each category name per the analysis above; if no
///      separator is found it returns "raw name, country=null".
///
/// Design decisions:
///   - **Candidate set:** every character OUTSIDE Latin letter / digit /
///     space / parenthesis. A parenthesis expresses content
///     (`(foreign)`, `(Multi)`) so it isn't counted as a separator candidate.
///   - **Coverage threshold 85%:** it must appear in nearly all categories;
///     15% anomaly is tolerated (panel bugs, single-type categories).
///   - **Position consistency:** the standard deviation of the separator's
///     index/length ratio must be low - characters "sitting randomly
///     everywhere" are content, not a separator.
///   - **Multi-glyph support:** even if the separator is a single character,
///     the surrounding spaces are trimmed when splitting; for `"TR ✨ Netflix"`
///     the separator is `✨`, left token `"TR"`, right token `"Netflix"`.
class CategoryDecomposer {
  /// The detected separator character. Null means no candidate passed the
  /// threshold (the source categories have no separator, left raw).
  final String? splitter;

  /// The split regex that swallows optional spaces around the splitter.
  /// Null when the splitter is also null.
  final RegExp? _splitRegex;

  /// The splitter's coverage ratio across the categories (0.0-1.0).
  final double coverage;

  /// Hint about the left-token (prefix) length:
  ///   - >0: median length of the detected prefixes (between 2-5)
  ///   - 0: no prefix detected
  final int prefixLengthHint;

  const CategoryDecomposer._({
    required this.splitter,
    required RegExp? splitRegex,
    required this.coverage,
    required this.prefixLengthHint,
  }) : _splitRegex = splitRegex;

  /// The no-op decomposer used when there are no categories or no separator
  /// is found - returns each category as-is.
  static const CategoryDecomposer none = CategoryDecomposer._(
    splitter: null,
    splitRegex: null,
    coverage: 0,
    prefixLengthHint: 0,
  );

  /// Learns the separator + prefix hint from the given category names.
  /// Returns [none] for empty or fewer-than-3 inputs (the statistical
  /// signal isn't reliable).
  static CategoryDecomposer analyze(Iterable<String> categoryNames) {
    final names = categoryNames
        .where((n) => n.trim().isNotEmpty)
        .toList(growable: false);
    if (names.length < 3) return none;

    // Count the candidate characters. Candidate = a character OUTSIDE
    // Latin letter/digit/space/parenthesis. Explicitly excluded: parens,
    // brackets, braces (content tags, so not a separator).
    final candidates = <String, _CharStats>{};
    for (final name in names) {
      // If the same character occurs multiple times in the same category,
      // the "occurred" count should still rise by 1 (for the coverage metric).
      final seenInThisName = <String>{};
      for (var i = 0; i < name.length; i++) {
        final ch = name[i];
        if (!_isSeparatorCandidate(ch)) continue;
        seenInThisName.add(ch);
        final stats = candidates.putIfAbsent(ch, () => _CharStats());
        stats.positions.add(i / name.length);
      }
      for (final ch in seenInThisName) {
        candidates[ch]!.coverage++;
      }
    }

    if (candidates.isEmpty) return none;

    // Score those with coverage ≥ 85% + position consistency.
    final total = names.length;
    _Candidate? best;
    candidates.forEach((ch, stats) {
      final coverageRatio = stats.coverage / total;
      if (coverageRatio < 0.85) return;
      final meanPos = stats.positions.isEmpty
          ? 0.5
          : stats.positions.reduce((a, b) => a + b) / stats.positions.length;
      // Standard deviation - should be low for a consistent position.
      double variance = 0;
      for (final p in stats.positions) {
        final d = p - meanPos;
        variance += d * d;
      }
      variance /= stats.positions.length;
      final stddev = _sqrt(variance);

      // The separator typically sits in the first half (the prefix is short).
      // If mean > 0.6 it's probably a content character.
      if (meanPos > 0.6) return;
      // Stddev > 0.25 → "scattered everywhere" → not a separator.
      if (stddev > 0.25) return;

      // Score: coverage * (position consistency). Stddev 0 → 1.0,
      // stddev 0.25 → 0.5.
      final score = coverageRatio * (1.0 - stddev * 2).clamp(0.0, 1.0);
      if (best == null || score > best!.score) {
        best = _Candidate(
          ch: ch,
          score: score,
          coverage: coverageRatio,
        );
      }
    });

    final picked = best;
    if (picked == null) return none;

    // Regex that trims optional spaces around the splitter.
    // RegExp.escape doesn't exist in Dart; for ASCII non-letter characters
    // a backslash escape is enough.
    final escaped = _escapeRegex(picked.ch);
    final regex = RegExp('\\s*$escaped\\s*');

    // Prefix length hint: median length of the split first tokens.
    // 2-5 is the common region/code length.
    final firstTokenLens = <int>[];
    for (final name in names) {
      final parts = name.split(regex);
      if (parts.length < 2) continue;
      final first = parts.first.trim();
      if (first.isEmpty) continue;
      firstTokenLens.add(first.length);
    }
    firstTokenLens.sort();
    final medianLen = firstTokenLens.isEmpty
        ? 0
        : firstTokenLens[firstTokenLens.length ~/ 2];

    return CategoryDecomposer._(
      splitter: picked.ch,
      splitRegex: regex,
      coverage: picked.coverage,
      prefixLengthHint: medianLen,
    );
  }

  /// Parses a category name using the learned splitter. If no splitter was
  /// found, or this particular category has no splitter, it returns "no
  /// country, raw subCategory" - i.e. no mangling at all.
  CategoryDecomposition parse(String input) {
    final raw = input.trim();
    if (_splitRegex == null) {
      return CategoryDecomposition(
        country: null,
        subCategory: raw,
        segments: [raw],
        original: input,
      );
    }
    final segments = raw
        .split(_splitRegex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.length < 2) {
      // This category has no separator - treat it as a single item.
      return CategoryDecomposition(
        country: null,
        subCategory: raw,
        segments: [raw],
        original: input,
      );
    }

    final first = segments.first;
    String? country;
    String subCategory;
    // Is the left token a short prefix like 2-5 chars and ALL CAPS? Check
    // CountryNames first (we're not translating to a localized name from
    // tr.json here - just a "valid code" check). Then the ALL CAPS short
    // fallback.
    final isShortPrefix = first.length >= 2 && first.length <= 5;
    final isAllCaps =
        first == first.toUpperCase() && RegExp(r'[A-Z]').hasMatch(first);
    final isKnownCountry =
        isShortPrefix && CountryNames.lookup(first, locale: 'en') != null;

    if (isKnownCountry) {
      country = first.toUpperCase();
      subCategory = segments.skip(1).join(' · ');
    } else if (isShortPrefix && isAllCaps) {
      // Unknown short ALL CAPS prefix - still treat it as a group but show
      // it raw (CountryNames lookup failed).
      country = first.toUpperCase();
      subCategory = segments.skip(1).join(' · ');
    } else {
      // Left token is long or lowercase - not a prefix, the whole string
      // is the theme.
      country = null;
      subCategory = raw;
    }

    return CategoryDecomposition(
      country: country,
      subCategory: subCategory.isEmpty ? raw : subCategory,
      segments: segments,
      original: input,
    );
  }

  /// Is a character a separator candidate? Latin letters, digits, spaces,
  /// parentheses and braces `( ) [ ] { }` are excluded - these are content
  /// characters.
  static bool _isSeparatorCandidate(String ch) {
    if (ch.length != 1) return false;
    final code = ch.codeUnitAt(0);
    // ASCII space and control characters are not separators.
    if (code <= 0x20) return false;
    // Latin letter (A-Z, a-z).
    if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)) {
      return false;
    }
    // Digit (0-9).
    if (code >= 0x30 && code <= 0x39) return false;
    // Latin extended (ñ, é, ï, etc.) - content character.
    if (code >= 0xC0 && code <= 0x024F) return false;
    // Parentheses and brackets.
    if (ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '{' || ch == '}') {
      return false;
    }
    // Single quote / double quote - usually content.
    if (ch == '\'' || ch == '"') return false;
    return true;
  }

  static String _escapeRegex(String ch) {
    const specials = r'\^$.|?*+()[]{}';
    if (specials.contains(ch)) return '\\$ch';
    return ch;
  }
}

class _CharStats {
  int coverage = 0;
  final List<double> positions = [];
}

class _Candidate {
  final String ch;
  final double score;
  final double coverage;
  _Candidate({required this.ch, required this.score, required this.coverage});
}

/// Newton-Raphson square root - minimal precision without a dart:math
/// dependency. (This file is already the domain layer; we keep extra
/// imports to a minimum.)
double _sqrt(double x) {
  if (x <= 0) return 0;
  var guess = x;
  for (var i = 0; i < 16; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}
