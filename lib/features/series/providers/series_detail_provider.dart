import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/metadata/tmdb_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';

/// Public seriesDetail provider - for surfaces that want access from
/// outside `series_detail_page`, like the home page's "Newly added
/// episodes" row. autoDispose family - frees memory when the episode
/// list's page is not visible.
class SeriesDetailArgs {
  final String sourceId;
  final String seriesId;
  const SeriesDetailArgs({required this.sourceId, required this.seriesId});

  @override
  bool operator ==(Object other) =>
      other is SeriesDetailArgs &&
      other.sourceId == sourceId &&
      other.seriesId == seriesId;

  @override
  int get hashCode => Object.hash(sourceId, seriesId);
}

final seriesDetailProvider = FutureProvider.autoDispose
    .family<SeriesDetail?, SeriesDetailArgs>((ref, args) async {
      final id = MediaItem.makeId(args.sourceId, args.seriesId);
      final item = await ref.watch(mediaItemByIdProvider(id).future);
      final source = await ref.watch(sourceByIdProvider(args.sourceId).future);
      if (item == null || source == null) return null;
      final repo = ref.read(sourceRepositoryProvider);
      final detail = await repo.seriesDetail(source, item);
      return detail ??
          SeriesDetail(
            info: item,
            detail: const MediaDetail(),
            episodes: const [],
          );
    });

/// Persists the original + localized title resolved from TMDB for a
/// series - symmetric with the movie side. Awaits seriesDetailProvider's
/// write future first so a later-arriving detail doesn't wipe the title
/// fields. Don't write at all if there is no cached_details row - to
/// avoid creating an empty row and opening a race.
final persistTmdbSeriesTitlesProvider = FutureProvider.autoDispose
    .family<void, SeriesDetailArgs>((ref, args) async {
      final id = MediaItem.makeId(args.sourceId, args.seriesId);
      final item = await ref.watch(mediaItemByIdProvider(id).future);
      if (item == null) return;
      // Await the seriesDetailProvider future first - if it fails, pass
      // silently. By this point repo.putDetail will have run (cast,
      // director etc. filled).
      try {
        await ref.read(seriesDetailProvider(args).future);
      } catch (_) {
        /* ignore */
      }
      final tmdb = await ref.watch(
        tmdbDetailProvider(TmdbLookupArgs.fromItem(item)).future,
      );
      if (tmdb == null) return;
      final original = tmdb.originalTitle?.trim();
      final localized = tmdb.title?.trim();
      if ((original == null || original.isEmpty) &&
          (localized == null || localized.isEmpty)) {
        return;
      }
      final repo = ref.read(sourceRepositoryProvider);
      final existing = await repo.cachedDetail(item.id);
      if (existing == null) return;
      if (existing.originalTitle == original &&
          existing.localizedTitle == localized) {
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
          originalTitle: original,
          localizedTitle: localized,
        ),
      );
    });
