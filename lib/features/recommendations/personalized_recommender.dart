import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database_provider.dart';
import '../library/providers/library_provider.dart';
import '../library/providers/ratings_provider.dart';
import '../settings/providers/adult_filter_provider.dart';
import '../sources/domain/media_item.dart';
import '../sources/providers/sources_provider.dart';

/// A simple rule-based engine that derives genre/keyword/cast/director
/// weights from the user's behavior (ratings + watch history + favorites +
/// watchlist) and scores candidates across the whole catalog.
///
/// "v0": not ML, weighted set-intersection. This scored list can also be
/// fed as input to a prompt ahead of an LLM call.
class PersonalizedRecommender {
  /// The base weight coefficient given to each feature. If the user rated a
  /// movie 9, that movie's genres get a weight like "0.9" and its director
  /// "1.0 * directorW"; it is included in the sum.
  static const double _genreW = 1.0;
  static const double _keywordW = 1.6; // sharpness reward
  static const double _castW = 0.8;
  static const double _directorW = 1.2;

  /// The weight of the signal type. Rating > watchlist > favorite >
  /// completed > skim (negative).
  static double _signalWeight(_SignalKind k) {
    switch (k) {
      case _SignalKind.ratingHigh:
        return 1.0;
      case _SignalKind.ratingMid:
        return 0.4;
      case _SignalKind.ratingLow:
        return -0.6;
      case _SignalKind.watchlist:
        return 0.6;
      case _SignalKind.favorite:
        return 0.5;
      case _SignalKind.completed:
        return 0.4;
      case _SignalKind.skimmed:
        return -0.3;
    }
  }

  /// Scored top-N recommendations. Returns an empty list if there is no
  /// content-related signal (cold start); in that case the UI should not
  /// show the row at all.
  static Future<List<RecommendedItem>> compute({
    required Map<String, MediaDetail> allDetails,
    required List<MediaItem> catalog,
    required Map<String, UserRating> ratings,
    required List<HistoryEntry> history,
    required Set<String> favorites,
    required Set<String> watchlistContentIds,
    int limit = 30,
  }) async {
    // Collect all signals into a single list.
    final signals = <_Signal>[];
    ratings.forEach((id, r) {
      final kind = r.score >= 7.0
          ? _SignalKind.ratingHigh
          : r.score >= 5.0
              ? _SignalKind.ratingMid
              : _SignalKind.ratingLow;
      // For high ratings, also use the score as a multiplier (so 8 and 10 differ).
      final mag = (r.score - 5.0).abs() / 5.0;
      signals.add(_Signal(id, kind, mag));
    });
    for (final id in favorites) {
      signals.add(_Signal(id, _SignalKind.favorite, 1.0));
    }
    for (final id in watchlistContentIds) {
      signals.add(_Signal(id, _SignalKind.watchlist, 1.0));
    }
    for (final h in history) {
      if (h.isCompleted) {
        signals.add(_Signal(h.contentId, _SignalKind.completed, 1.0));
      } else if (h.isSkimmed) {
        signals.add(_Signal(h.contentId, _SignalKind.skimmed, 1.0));
      }
    }
    if (signals.isEmpty) return const [];

    // Reach the details for all signaled content from the map - the bulk
    // cached_details comes from the shared provider.
    final relevantIds = signals.map((s) => s.contentId).toSet();

    // Profile vector: feature → weight. Using Map<String, double> is simple
    // and enough; the vector size is limited to tens per user.
    final genreW = <String, double>{};
    final keywordW = <String, double>{};
    final castW = <String, double>{};
    final directorW = <String, double>{};
    final negativeIds = <String>{};
    for (final s in signals) {
      final detail = allDetails[s.contentId];
      if (detail == null) continue;
      final w = _signalWeight(s.kind) * s.magnitude;
      if (w == 0) continue;
      if (w < 0) negativeIds.add(s.contentId);
      for (final g in detail.genres) {
        genreW[_norm(g)] = (genreW[_norm(g)] ?? 0) + w * _genreW;
      }
      for (final k in detail.keywords) {
        keywordW[_norm(k)] = (keywordW[_norm(k)] ?? 0) + w * _keywordW;
      }
      for (final c in detail.cast.take(8)) {
        castW[_norm(c)] = (castW[_norm(c)] ?? 0) + w * _castW;
      }
      for (final d in detail.directors) {
        directorW[_norm(d)] = (directorW[_norm(d)] ?? 0) + w * _directorW;
      }
    }

    // Exclude content the user already interacted with from recommendations
    // - recommending what they watched or rated again is noise.
    final exclude = <String>{
      ...relevantIds,
      for (final h in history) h.contentId,
    };

    // Score the candidates. In a very large catalog (100k+) a detail lookup
    // per item can be expensive; but detail exists only for TMDB-enriched
    // rows, so as a rough filter we skip the detail-less ones.
    final scored = <RecommendedItem>[];
    for (final item in catalog) {
      if (exclude.contains(item.id)) continue;
      if (item.kind != MediaKind.movie && item.kind != MediaKind.series) {
        continue;
      }
      final d = allDetails[item.id];
      if (d == null) continue;
      double score = 0;
      for (final g in d.genres) {
        score += genreW[_norm(g)] ?? 0;
      }
      for (final k in d.keywords) {
        score += keywordW[_norm(k)] ?? 0;
      }
      for (final c in d.cast.take(8)) {
        score += castW[_norm(c)] ?? 0;
      }
      for (final dr in d.directors) {
        score += directorW[_norm(dr)] ?? 0;
      }
      if (score <= 0) continue;
      // Add the TMDB average rating as a small tiebreaker - between two
      // movies with the same affinity, pick the better-rated one.
      final tmdbRating = d.rating ?? 0;
      score += tmdbRating * 0.05;
      scored.add(RecommendedItem(item: item, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    // Return the scored results; but so that items whose panel did not send
    // a poster URL do not appear empty in the list, we overlay
    // coverUrl/backdrop from cached_details - allDetails was already read
    // above.
    return scored.take(limit).map((r) {
      final item = r.item;
      if (item.logoUrl != null && item.logoUrl!.isNotEmpty) return r;
      final d = allDetails[item.id];
      if (d == null) return r;
      final cover = d.coverUrl;
      final backdrop = d.backdropUrl;
      if ((cover == null || cover.isEmpty) &&
          (backdrop == null || backdrop.isEmpty)) {
        return r;
      }
      return RecommendedItem(
        item: item.copyWith(
          logoUrl: (cover != null && cover.isNotEmpty)
              ? cover
              : item.logoUrl,
          backdropUrl: (backdrop != null && backdrop.isNotEmpty)
              ? backdrop
              : item.backdropUrl,
        ),
        score: r.score,
      );
    }).toList();
  }

  static String _norm(String s) => s.trim().toLowerCase();
}

enum _SignalKind {
  ratingHigh,
  ratingMid,
  ratingLow,
  watchlist,
  favorite,
  completed,
  skimmed,
}

class _Signal {
  final String contentId;
  final _SignalKind kind;
  final double magnitude;
  const _Signal(this.contentId, this.kind, this.magnitude);
}

class RecommendedItem {
  final MediaItem item;
  final double score;
  const RecommendedItem({required this.item, required this.score});
}

/// Provider entry point: watches all user signals and the catalog,
/// computes the score in the background and hands it to the UI.
/// Recomputes automatically as the signals change.
final personalizedRecommendationsProvider =
    FutureProvider<List<RecommendedItem>>((ref) async {
  final allDetails = await ref.watch(cachedDetailsMapProvider.future);
  final catalog = await ref.watch(
    libraryItemsProvider(const LibraryItemsArgs()).future,
  );
  final ratings = await ref.watch(userRatingsProvider.future);
  final history = await ref.watch(historyProvider.future);
  final favs = await ref.watch(favoritesProvider.future);
  // Watchlist content: merge the contentIds across all lists. Watching the
  // items one by one creates a chained dependency through family providers;
  // the simple solution is to fetch them in a single query from the DB.
  final db = ref.watch(databaseProvider);
  final wlItems = await db.select(db.watchlistItems).get();
  final watchlistContentIds = wlItems.map((r) => r.contentId).toSet();
  final filter = ref.watch(adultFilterProvider).value;
  final showAdult = filter?.showAdult ?? false;
  final filtered = showAdult
      ? catalog
      : catalog.where((i) => !isAdult(i)).toList();
  return PersonalizedRecommender.compute(
    allDetails: allDetails,
    catalog: filtered,
    ratings: ratings,
    history: history,
    favorites: favs,
    watchlistContentIds: watchlistContentIds,
  );
});
