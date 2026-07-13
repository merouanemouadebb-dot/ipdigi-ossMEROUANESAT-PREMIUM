import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sources/domain/media_item.dart';
import '../sources/providers/sources_provider.dart';
import 'detail_backfill_provider.dart';
import 'related_service.dart';

final relatedServiceProvider = Provider<RelatedService>(
  (ref) => RelatedService(),
);

/// Builds the index from cached items + any cached MediaDetail rows in the
/// local database. As detail pages are visited (or the backfill controller
/// fills more), this provider is invalidated and the index is rebuilt.
final relatedIndexProvider = FutureProvider<RelatedService>((ref) async {
  final service = ref.watch(relatedServiceProvider);
  final all = await ref.watch(
    libraryItemsProvider(const LibraryItemsArgs()).future,
  );
  final details = await ref.watch(cachedDetailsMapProvider.future);
  service.build(all, details);
  return service;
});

class RelatedQuery {
  final String sourceId;
  final String streamId;
  const RelatedQuery({required this.sourceId, required this.streamId});

  @override
  bool operator ==(Object other) =>
      other is RelatedQuery &&
      other.sourceId == sourceId &&
      other.streamId == streamId;
  @override
  int get hashCode => Object.hash(sourceId, streamId);
}

final relatedItemsProvider =
    FutureProvider.family<List<MediaItem>, RelatedQuery>((ref, query) async {
      final service = await ref.watch(relatedIndexProvider.future);
      final id = MediaItem.makeId(query.sourceId, query.streamId);
      final source = await ref.watch(mediaItemByIdProvider(id).future);
      if (source == null) return const [];
      final universe = await ref.watch(
        libraryItemsProvider(const LibraryItemsArgs()).future,
      );
      final items = service.related(source, universe);
      // Cards for related content whose panel posters are missing look
      // empty. PosterCard does not do a TMDB lookup in the list (for
      // performance); instead, read the TMDB coverUrls that landed in
      // cached_details in one bulk pass here and apply them with
      // item.copyWith. Read from the shared cachedDetailsMapProvider, so
      // no extra DB scan.
      final details = await ref.watch(cachedDetailsMapProvider.future);
      return items.map((item) {
        if (item.logoUrl != null && item.logoUrl!.isNotEmpty) return item;
        final d = details[item.id];
        if (d == null) return item;
        final cover = d.coverUrl;
        final backdrop = d.backdropUrl;
        if ((cover == null || cover.isEmpty) &&
            (backdrop == null || backdrop.isEmpty)) {
          return item;
        }
        return item.copyWith(
          logoUrl: (cover != null && cover.isNotEmpty)
              ? cover
              : item.logoUrl,
          backdropUrl: (backdrop != null && backdrop.isNotEmpty)
              ? backdrop
              : item.backdropUrl,
        );
      }).toList();
    });

class TagBrowseQuery {
  final String tag;
  final String tagType; // genre | cast | dir | cat
  final String? excludeId;
  const TagBrowseQuery({
    required this.tag,
    required this.tagType,
    this.excludeId,
  });

  @override
  bool operator ==(Object other) =>
      other is TagBrowseQuery &&
      other.tag == tag &&
      other.tagType == tagType &&
      other.excludeId == excludeId;

  @override
  int get hashCode => Object.hash(tag, tagType, excludeId);
}

final tagBrowseProvider =
    FutureProvider.family<List<MediaItem>, TagBrowseQuery>((ref, query) async {
      final service = await ref.watch(relatedIndexProvider.future);
      final universe = await ref.watch(
        libraryItemsProvider(const LibraryItemsArgs()).future,
      );
      // Re-query whenever the backfill counter ticks - the service has been
      // updated incrementally, so new matches appear without a full rebuild.
      ref.watch(detailBackfillProvider);
      return service.byTag(
        query.tag,
        query.tagType,
        universe,
        excludeId: query.excludeId,
      );
    });
