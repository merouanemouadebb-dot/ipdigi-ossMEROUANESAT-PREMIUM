import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/metadata/tmdb_provider.dart';
import '../../recommendations/related_provider.dart';
import '../../sources/data/source_repository.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';

class MovieDetailArgs {
  final String sourceId;
  final String movieId;
  const MovieDetailArgs({required this.sourceId, required this.movieId});

  @override
  bool operator ==(Object other) =>
      other is MovieDetailArgs &&
      other.sourceId == sourceId &&
      other.movieId == movieId;
  @override
  int get hashCode => Object.hash(sourceId, movieId);
}

final movieDetailProvider = FutureProvider.autoDispose
    .family<MediaDetail?, MovieDetailArgs>((ref, args) async {
      final id = MediaItem.makeId(args.sourceId, args.movieId);
      final item = await ref.watch(mediaItemByIdProvider(id).future);
      final src = await ref.watch(sourceByIdProvider(args.sourceId).future);
      if (item == null || src == null) return null;
      final repo = ref.read(sourceRepositoryProvider);
      final cached = await repo.cachedDetail(id);
      if (cached != null) return cached;
      final fresh = await repo.movieDetail(src, item);
      if (fresh != null) {
        await repo.putDetail(item, fresh);
        // Incremental: only this item's vector changes - avoids the 150-250ms
        // full rebuild over the entire 45K-item library that an invalidate
        // would trigger.
        final service = ref.read(relatedServiceProvider);
        if (service.isReady) {
          service.addDetail(item, fresh);
        }
        // Refresh the shared cached_details map - libraryItemsProvider and
        // the recommender watch it; when a new detail is written, the
        // home/continue row poster and cast info refresh immediately.
        ref.invalidate(cachedDetailsMapProvider);
      }
      return fresh;
    });

/// Persists TMDB's original + localized titles for the search index. If it
/// runs without waiting for movieDetailProvider's `repo.putDetail(item,
/// fresh)` call, a later-arriving fresh detail could wipe the title fields
/// (race). So we first await movieDetailProvider's future - once it
/// completes, the cached_details row has been written with the real detail;
/// we then only add the title fields. If there is no title change, no write
/// is done.
final persistTmdbTitlesProvider = FutureProvider.autoDispose
    .family<void, MovieDetailArgs>((ref, args) async {
      final id = MediaItem.makeId(args.sourceId, args.movieId);
      final item = await ref.watch(mediaItemByIdProvider(id).future);
      if (item == null) return;
      // Wait for movieDetailProvider's write phase so that when we overlay
      // afterward we do not reset fields like cast/rating with an empty
      // MediaDetail(). Swallow a future failure silently - title persist is
      // best-effort.
      try {
        await ref.read(movieDetailProvider(args).future);
      } catch (_) {
        /* ignore */
      }
      final tmdb = await ref.watch(
        tmdbDetailProvider(TmdbLookupArgs.fromItem(item)).future,
      );
      if (tmdb == null) return;
      final repo = ref.read(sourceRepositoryProvider);
      // Persist the panel-independent TMDB id: the my_ratings read side ties
      // a rating whose source was deleted to the same movie in the current
      // catalog via this id. Separate from title persist because the id must
      // be written even if the title is empty.
      await repo.setDetailTmdbId(item.id, tmdb.tmdbId);
      final original = tmdb.originalTitle?.trim();
      final localized = tmdb.title?.trim();
      if ((original == null || original.isEmpty) &&
          (localized == null || localized.isEmpty)) {
        return;
      }
      await _persistAlternateTitles(
        repo,
        item,
        originalTitle: original,
        localizedTitle: localized,
      );
    });

/// Keep the existing detail row; update only the alternate title fields.
/// If there is no cached_details row, do not write at all - otherwise it
/// would create an empty row and a later movieDetailProvider `putDetail`
/// call could wipe the title fields. Runs after the row's existence is
/// guaranteed (the caller must await `movieDetailProvider.future`).
Future<void> _persistAlternateTitles(
  SourceRepository repo,
  MediaItem item, {
  String? originalTitle,
  String? localizedTitle,
}) async {
  final existing = await repo.cachedDetail(item.id);
  if (existing == null) {
    // The base detail has not been written yet; skip silently instead of
    // racing. It gets written when this provider is triggered again on the
    // next detail open.
    return;
  }
  if (existing.originalTitle == originalTitle &&
      existing.localizedTitle == localizedTitle) {
    return;
  }
  await repo.putDetail(
    item,
    MediaDetail(
      cast: existing.cast,
      directors: existing.directors,
      genres: existing.genres,
      runtimeSeconds: existing.runtimeSeconds,
      releaseDate: existing.releaseDate,
      country: existing.country,
      plot: existing.plot,
      coverUrl: existing.coverUrl,
      backdropUrl: existing.backdropUrl,
      rating: existing.rating,
      certification: existing.certification,
      originalTitle: originalTitle,
      localizedTitle: localizedTitle,
    ),
  );
}
