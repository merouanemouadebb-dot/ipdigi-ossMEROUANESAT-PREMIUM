import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../core/metadata/tmdb_overrides_provider.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/metadata/tmdb_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/certification_badge.dart';
import '../../../shared/widgets/gallery_strip.dart';
import '../../../shared/widgets/reviews_strip.dart';
import '../../../shared/widgets/row_carousel.dart';
import '../../../shared/widgets/trailer_strip.dart';
import '../../library/presentation/add_to_watchlist_sheet.dart';
import '../../library/presentation/rate_content_sheet.dart';
import '../../library/providers/library_provider.dart';
import '../../library/providers/ratings_provider.dart';
import '../../player/domain/series_queue.dart';
import '../../player/presentation/player_page.dart';
import '../../recommendations/related_provider.dart';
import '../../recommendations/tmdb_picker_sheet.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';
import '../providers/series_detail_provider.dart' as series_prov;
import '../../../shared/widgets/fading_hero.dart';

/// Extracts the year from variants like "2023-04-15", "2023-04", "2023".
/// Returns null for invalid / non-4-digit inputs.
int? _yearFromDate(String? raw) {
  if (raw == null || raw.length < 4) return null;
  final y = int.tryParse(raw.substring(0, 4));
  if (y == null || y < 1800 || y > 2100) return null;
  return y;
}

class _SeriesArgs {
  final String sourceId;
  final String seriesId;
  const _SeriesArgs(this.sourceId, this.seriesId);
  @override
  bool operator ==(Object other) =>
      other is _SeriesArgs &&
      other.sourceId == sourceId &&
      other.seriesId == seriesId;
  @override
  int get hashCode => Object.hash(sourceId, seriesId);
}

final _seriesDetailProvider = FutureProvider.autoDispose
    .family<SeriesDetail?, _SeriesArgs>((ref, args) async {
      final id = MediaItem.makeId(args.sourceId, args.seriesId);
      final item = await ref.watch(mediaItemByIdProvider(id).future);
      final source = await ref.watch(sourceByIdProvider(args.sourceId).future);
      if (item == null || source == null) return null;
      final repo = ref.read(sourceRepositoryProvider);
      final detail = await repo.seriesDetail(source, item);
      if (detail != null &&
          (detail.detail.cast.isNotEmpty ||
              detail.detail.directors.isNotEmpty ||
              detail.detail.genres.isNotEmpty)) {
        await repo.putDetail(item, detail.detail);
        final service = ref.read(relatedServiceProvider);
        if (service.isReady) {
          service.addDetail(item, detail.detail);
        }
        // Refresh the shared cached_details map so the home/continue row
        // reflects the new TMDB coverUrl/cast info immediately.
        ref.invalidate(cachedDetailsMapProvider);
      }
      return detail ??
          SeriesDetail(
            info: item,
            detail: const MediaDetail(),
            episodes: const [],
          );
    });

class SeriesDetailPage extends ConsumerStatefulWidget {
  final String sourceId;
  final String seriesId;
  const SeriesDetailPage({
    super.key,
    required this.sourceId,
    required this.seriesId,
  });

  @override
  ConsumerState<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends ConsumerState<SeriesDetailPage> {
  int? _selectedSeason;
  final _favKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final args = _SeriesArgs(widget.sourceId, widget.seriesId);
    final detailAsync = ref.watch(_seriesDetailProvider(args));
    final favs = ref.watch(favoritesProvider).value ?? {};
    final ratings = ref.watch(userRatingsProvider).value ?? const {};
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final relatedAsync = ref.watch(
      relatedItemsProvider(
        RelatedQuery(sourceId: widget.sourceId, streamId: widget.seriesId),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (sd) {
          if (sd == null) return Center(child: Text(ref.tr('series.notFound')));
          final info = sd.info;
          final tmdb = ref
              .watch(tmdbDetailProvider(TmdbLookupArgs.fromItem(info)))
              .value;
          final hasOverride = ref
                  .watch(tmdbOverridesProvider)
                  .value
                  ?.containsKey(info.id) ??
              false;
          final detail =
              mergeWithTmdb(sd.detail, tmdb, preferTmdb: hasOverride);
          // Wake the side-effect provider so the TMDB alternate titles get
          // persisted to cached_details.
          ref.watch(
            series_prov.persistTmdbSeriesTitlesProvider(
              series_prov.SeriesDetailArgs(
                sourceId: widget.sourceId,
                seriesId: widget.seriesId,
              ),
            ),
          );
          final seasons = sd.bySeason;
          final seasonKeys = seasons.keys.toList()..sort();
          final selected =
              _selectedSeason ?? (seasonKeys.isNotEmpty ? seasonKeys.first : 0);
          final episodes = seasons[selected] ?? const [];
          // Per-episode TMDB metadata for the active season. Keyed by
          // episode_number so source episodes can be looked up cheaply.
          final tmdbEpisodes = tmdb != null && selected != 0
              ? (ref
                        .watch(
                          tmdbSeasonProvider(
                            TmdbSeasonArgs(
                              tmdbId: tmdb.tmdbId,
                              seasonNumber: selected,
                            ),
                          ),
                        )
                        .value ??
                    const <int, TmdbEpisode>{})
              : const <int, TmdbEpisode>{};
          final flatEpisodes = <SeriesEpisode>[
            for (final s in seasonKeys) ...seasons[s]!,
          ];
          final id = info.id;
          final isFav = favs.contains(id);
          final userRating = ratings[id];
          final backdrop =
              [
                detail.backdropUrl,
                detail.coverUrl,
                info.backdropUrl,
                info.logoUrl,
              ].firstWhere(
                (u) => u != null && u.trim().isNotEmpty,
                orElse: () => null,
              );

          SeriesQueue queueAt(int index) => SeriesQueue(
            seriesId: info.streamId,
            seriesSourceId: info.sourceId,
            seriesName: info.name,
            seriesPosterUrl: detail.coverUrl ?? info.logoUrl,
            episodes: flatEpisodes,
            currentIndex: index,
          );

          // Resume logic: find the most recently watched episode of this
          // series in history. If it is nearly done, queue the next one.
          SeriesEpisode? lastWatched;
          HistoryEntry? lastEntry;
          DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);
          for (final ep in flatEpisodes) {
            final epContentId = '${info.sourceId}|ep-${ep.id}';
            final entry = history.firstWhereOrNull(
              (h) => h.contentId == epContentId && h.sourceId == info.sourceId,
            );
            if (entry != null && entry.lastWatchedAt.isAfter(latest)) {
              latest = entry.lastWatchedAt;
              lastWatched = ep;
              lastEntry = entry;
            }
          }
          int playIndex = 0;
          Duration playStartAt = Duration.zero;
          String playLabel = ref.tr('series.playFirst');
          if (lastWatched != null &&
              lastEntry != null &&
              flatEpisodes.isNotEmpty) {
            final epIdx = flatEpisodes.indexWhere(
              (e) => e.id == lastWatched!.id,
            );
            if (lastEntry.progress >= 0.95 && epIdx + 1 < flatEpisodes.length) {
              playIndex = epIdx + 1;
              final nextEp = flatEpisodes[playIndex];
              playLabel =
                  '${ref.tr('series.next')} • S${nextEp.season}E${nextEp.episode}';
            } else {
              playIndex = epIdx;
              playStartAt = lastEntry.position;
              playLabel =
                  '${ref.tr('common.resume')} • S${lastWatched.season}E${lastWatched.episode}';
            }
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.background,
                expandedHeight: 520,
                collapsedHeight: kToolbarHeight,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    tooltip: ref.tr('tmdbPicker.wrongMatch'),
                    onPressed: () => TmdbPickerSheet.show(
                      context,
                      sourceId: info.sourceId,
                      contentId: info.id,
                      initialQuery: info.name,
                      isMovie: false,
                    ),
                    icon: const Icon(Icons.find_replace_rounded),
                  ),
                ],
                flexibleSpace: FadingFlexibleSpace(
                  expandedHeight: 520,
                  collapsedHeight: kToolbarHeight,
                  child: _SeriesHero(
                    info: info,
                    detail: detail,
                    tmdb: tmdb,
                    backdropUrl: backdrop,
                    isFav: isFav,
                    userRating: userRating,
                    playLabel: playLabel,
                    onPlayFirst: flatEpisodes.isEmpty
                        ? null
                        : () {
                            final queue = queueAt(playIndex);
                            final ep = queue.current;
                            final epContentId = queue.contentIdFor(ep);
                            context.pushOnce(
                              '/player',
                              extra: PlayerArgs(
                                item: MediaItem(
                                  id: epContentId,
                                  sourceId: info.sourceId,
                                  streamId: ep.id,
                                  name:
                                      '${info.name} • S${ep.season}E${ep.episode}',
                                  streamUrl: ep.streamUrl,
                                  kind: MediaKind.movie,
                                ),
                                isLive: false,
                                startAt: playStartAt,
                                seriesQueue: queue,
                              ),
                            );
                          },
                    // If the series was watched before, "start over" plays
                    // it from S1E1 - so the user can reach it in one tap
                    // when they want to reset the series.
                    onPlayFromStart:
                        (lastWatched == null || flatEpisodes.isEmpty)
                        ? null
                        : () {
                            final queue = queueAt(0);
                            final ep = queue.current;
                            final epContentId = queue.contentIdFor(ep);
                            context.pushOnce(
                              '/player',
                              extra: PlayerArgs(
                                item: MediaItem(
                                  id: epContentId,
                                  sourceId: info.sourceId,
                                  streamId: ep.id,
                                  name:
                                      '${info.name} • S${ep.season}E${ep.episode}',
                                  streamUrl: ep.streamUrl,
                                  kind: MediaKind.movie,
                                ),
                                isLive: false,
                                startAt: Duration.zero,
                                seriesQueue: queue,
                              ),
                            );
                          },
                    onToggleFav: () {
                      ref
                          .read(favoritesProvider.notifier)
                          .toggle(info.sourceId, info.id);
                    },
                    onRate: () => RateContentSheet.show(
                      context,
                      sourceId: info.sourceId,
                      contentId: info.id,
                      contentName: (tmdb?.title?.trim().isNotEmpty ?? false)
                          ? tmdb!.title!
                          : info.name,
                      existing: userRating,
                      tmdbId: tmdb?.tmdbId,
                    ),
                    onAddToList: () => AddToWatchlistSheet.show(
                      context,
                      sourceId: info.sourceId,
                      contentId: info.id,
                      contentName: (tmdb?.title?.trim().isNotEmpty ?? false)
                          ? tmdb!.title!
                          : info.name,
                    ),
                    favKey: _favKey,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SeriesMetadata(
                  item: info,
                  detail: detail,
                  trailers: tmdb?.trailers ?? const [],
                  gallery: detail.gallery,
                ),
              ),
              if (seasonKeys.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      ref.tr('series.noEpisodesMsg'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 18, 32, 8),
                    child: Row(
                      children: [
                        Text(
                          ref.tr('series.episodes'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<int>(
                          value: selected,
                          dropdownColor: AppColors.surface,
                          underline: const SizedBox.shrink(),
                          items: seasonKeys
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('${ref.tr('series.season')} $s'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedSeason = v),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList.separated(
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, i) {
                    final ep = episodes[i];
                    return _EpisodeTile(
                      info: info,
                      episode: ep,
                      tmdbEpisode: tmdbEpisodes[ep.episode],
                      onTap: () async {
                        final idx = flatEpisodes.indexWhere(
                          (e) => e.id == ep.id,
                        );
                        final queue = queueAt(idx < 0 ? 0 : idx);
                        final epContentId = queue.contentIdFor(ep);
                        final entry = await ref
                            .read(historyProvider.notifier)
                            .getEntry(info.sourceId, epContentId);
                        if (!context.mounted) return;
                        context.pushOnce(
                          '/player',
                          extra: PlayerArgs(
                            item: MediaItem(
                              id: epContentId,
                              sourceId: info.sourceId,
                              streamId: ep.id,
                              name:
                                  '${info.name} • S${ep.season}E${ep.episode} ${ep.title}',
                              streamUrl: ep.streamUrl,
                              kind: MediaKind.movie,
                            ),
                            isLive: false,
                            startAt: entry?.position ?? Duration.zero,
                            seriesQueue: queue,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              // Trailers and images are now shown inside the _SeriesMetadata
              // block (under Genres / Production info).
              if (tmdb != null && tmdb.reviews.isNotEmpty)
                SliverToBoxAdapter(
                  child: ReviewsStrip(reviews: tmdb.reviews),
                ),
              SliverToBoxAdapter(
                child: relatedAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: RowCarousel(
                            title: ref.tr('series.similar'),
                            items: items,
                            onTapItem: (i) {
                              if (i.kind == MediaKind.series) {
                                context.pushOnce(
                                  '/series/${i.sourceId}/${i.streamId}',
                                );
                              } else if (i.kind == MediaKind.movie) {
                                context.pushOnce(
                                  '/movie/${i.sourceId}/${i.streamId}',
                                );
                              }
                            },
                          ),
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          );
        },
      ),
    );
  }
}

class _SeriesHero extends ConsumerWidget {
  final MediaItem info;
  final MediaDetail detail;
  final TmdbDetail? tmdb;
  final String? backdropUrl;
  final bool isFav;
  final UserRating? userRating;
  final VoidCallback? onPlayFirst;
  final VoidCallback? onPlayFromStart;
  final VoidCallback onToggleFav;
  final VoidCallback onRate;
  final VoidCallback onAddToList;
  final String playLabel;
  final Key favKey;
  const _SeriesHero({
    required this.info,
    required this.detail,
    required this.tmdb,
    required this.backdropUrl,
    required this.isFav,
    required this.userRating,
    required this.onPlayFirst,
    required this.onPlayFromStart,
    required this.onToggleFav,
    required this.onRate,
    required this.onAddToList,
    required this.playLabel,
    required this.favKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = detail.rating ?? info.rating;
    final localized = (tmdb?.title?.trim().isNotEmpty ?? false)
        ? tmdb!.title!
        : info.name;
    final original = tmdb?.originalTitle?.trim();
    final showOriginal =
        original != null &&
        original.isNotEmpty &&
        original.toLowerCase() != localized.toLowerCase();
    final year = info.year ?? _yearFromDate(detail.releaseDate);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdropUrl != null)
          CachedNetworkImage(
            fadeInDuration: const Duration(milliseconds: 220),
            fadeOutDuration: const Duration(milliseconds: 80),
            imageUrl: backdropUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.surface),
            errorWidget: (_, __, ___) => Container(color: AppColors.surface),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.background,
                Colors.transparent,
                AppColors.background,
              ],
              stops: [0, 0.5, 1],
            ),
          ),
        ),
        Positioned(
          left: 32,
          right: 32,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: localized,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                              height: 1.0,
                            ),
                          ),
                          if (year != null)
                            TextSpan(
                              text: '  ($year)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 26,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (showOriginal) ...[
                      const SizedBox(height: 6),
                      Text(
                        original,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (rating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  if (userRating != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            userRating!.score.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // The year is now shown as a faint (year) label next to
                  // the title; we don't repeat it.
                  if (detail.country != null)
                    Text(
                      detail.country!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  if (detail.certification != null &&
                      detail.certification!.isNotEmpty)
                    CertificationBadge(label: detail.certification!),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onPlayFirst,
                    icon: const Icon(Icons.play_arrow_rounded, size: 26),
                    label: Text(playLabel),
                  ),
                  if (onPlayFromStart != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onPlayFromStart,
                      icon: const Icon(Icons.replay_rounded, size: 22),
                      label: Text(ref.tr('common.startOver')),
                    ),
                  FilledButton(
                    key: favKey,
                    style: FilledButton.styleFrom(
                      backgroundColor: isFav
                          ? Colors.redAccent
                          : AppColors.surfaceElevated,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      minimumSize: const Size(52, 52),
                      shape: const CircleBorder(),
                    ),
                    onPressed: onToggleFav,
                    child: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 24,
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: userRating != null
                          ? AppColors.accentDeep
                          : AppColors.surfaceElevated,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: onRate,
                    icon: Icon(
                      userRating != null
                          ? Icons.rate_review_rounded
                          : Icons.star_outline_rounded,
                      size: 22,
                    ),
                    label: Text(
                      userRating != null
                          ? '${ref.tr('detail.yourRating')}: ${userRating!.score.toStringAsFixed(1)}'
                          : ref.tr('detail.rate'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: onAddToList,
                    icon: const Icon(
                      Icons.playlist_add_rounded,
                      size: 22,
                    ),
                    label: Text(
                      ref.tr('detail.addToList'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeriesMetadata extends ConsumerWidget {
  final MediaItem item;
  final MediaDetail detail;

  /// Trailers (TMDB videos) - shown inside the same metadata block,
  /// under Genres.
  final List<TmdbVideo> trailers;

  /// Images - below the trailers, still in the same block.
  final List<String> gallery;
  const _SeriesMetadata({
    required this.item,
    required this.detail,
    this.trailers = const [],
    this.gallery = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plot = detail.plot ?? item.plot;
    // Narrow screen (phone): single column, cast under Genres. Wide: 2-column.
    final isWide = MediaQuery.of(context).size.width >= 720;

    final infoChildren = <Widget>[
      if (plot != null && plot.isNotEmpty)
        Text(
          plot,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            height: 1.55,
          ),
        ),
      if (detail.genres.isNotEmpty) ...[
        const SizedBox(height: 18),
        _TagSection(
          label: ref.tr('detail.genres'),
          values: detail.genres,
          tagType: 'genre',
          excludeId: item.id,
        ),
      ],
    ];

    final metaChildren = <Widget>[
      if (detail.cast.isNotEmpty)
        _TagSection(
          label: ref.tr('detail.cast'),
          values: detail.cast,
          tagType: 'cast',
          excludeId: item.id,
        ),
      if (detail.directors.isNotEmpty) ...[
        const SizedBox(height: 14),
        _TagSection(
          label: ref.tr('detail.director'),
          values: detail.directors,
          tagType: 'dir',
          excludeId: item.id,
        ),
      ],
      if (item.categoryName != null) ...[
        const SizedBox(height: 14),
        _TagSection(
          label: ref.tr('detail.category'),
          values: [item.categoryName!],
          tagType: 'cat',
          excludeId: item.id,
        ),
      ],
      if (detail.releaseDate != null) ...[
        const SizedBox(height: 14),
        Builder(
          builder: (_) {
            final raw = detail.releaseDate!;
            final y = _yearFromDate(raw) ?? raw;
            return Text(
              '${ref.tr('detail.releaseYear')}: $y',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            );
          },
        ),
      ],
      if (detail.country != null) ...[
        const SizedBox(height: 14),
        Text(
          '${ref.tr('detail.country')}: ${detail.country!}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    ];

    final mediaChildren = <Widget>[
      if (trailers.isNotEmpty) ...[
        const SizedBox(height: 22),
        TrailerStrip(
          title: ref.tr('detail.trailers'),
          trailers: trailers,
          inline: true,
        ),
      ],
      if (gallery.isNotEmpty) ...[
        const SizedBox(height: 18),
        GalleryStrip(
          title: ref.tr('detail.gallery'),
          images: gallery,
          downloadTitle: item.name,
          inline: true,
        ),
      ],
    ];

    final horizontalPad = isWide ? 32.0 : 20.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 18, horizontalPad, 12),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [...infoChildren, ...mediaChildren],
                  ),
                ),
                const SizedBox(width: 36),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: metaChildren,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...infoChildren,
                if (metaChildren.isNotEmpty) const SizedBox(height: 18),
                ...metaChildren,
                ...mediaChildren,
              ],
            ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String label;
  final List<String> values;
  final String tagType;
  final String excludeId;
  const _TagSection({
    required this.label,
    required this.values,
    required this.tagType,
    required this.excludeId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (v) => _ClickableTag(
                  label: v,
                  tagType: tagType,
                  excludeId: excludeId,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ClickableTag extends ConsumerStatefulWidget {
  final String label;
  final String tagType;
  final String excludeId;
  const _ClickableTag({
    required this.label,
    required this.tagType,
    required this.excludeId,
  });

  @override
  ConsumerState<_ClickableTag> createState() => _ClickableTagState();
}

class _ClickableTagState extends ConsumerState<_ClickableTag> {
  bool _hover = false;
  bool _focus = false;
  bool get _active => _hover || _focus;

  void _activate(String displayLabel) {
    if (widget.tagType == 'cast') {
      context.pushOnce('/person/${Uri.encodeComponent(displayLabel)}');
    } else {
      context.pushOnce(
        '/tag/${widget.tagType}/${Uri.encodeComponent(widget.label)}?exclude=${widget.excludeId}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cast chips get converted to a Latin alias; other tag types are left
    // untouched because they're already localized in the user's locale.
    final displayLabel = widget.tagType == 'cast'
        ? (ref.watch(latinizedNameProvider(widget.label)).value ?? widget.label)
        : widget.label;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _focus = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            _activate(displayLabel);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => _activate(displayLabel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _active ? AppColors.accent : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: (_focus && PlatformInfo.isTv)
                  ? Border.all(color: AppColors.accent, width: 3)
                  : null,
            ),
            child: Text(
              displayLabel,
              style: TextStyle(
                color: _active ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends ConsumerStatefulWidget {
  final MediaItem info;
  final SeriesEpisode episode;
  final TmdbEpisode? tmdbEpisode;
  final VoidCallback onTap;
  const _EpisodeTile({
    required this.info,
    required this.episode,
    required this.onTap,
    this.tmdbEpisode,
  });

  @override
  ConsumerState<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends ConsumerState<_EpisodeTile> {
  bool _hover = false;
  bool _focus = false;
  bool get _active => _hover || _focus;

  // Source first, TMDB fallback - matches the page-level merge policy.
  bool _hasText(String? s) => s != null && s.trim().isNotEmpty;
  String get _title {
    if (_hasText(widget.episode.title)) return widget.episode.title;
    return widget.tmdbEpisode?.name ?? widget.episode.title;
  }

  String? get _plot {
    if (_hasText(widget.episode.plot)) return widget.episode.plot;
    return widget.tmdbEpisode?.overview;
  }

  String? get _thumb =>
      widget.episode.thumbnailUrl ??
      widget.tmdbEpisode?.stillUrl ??
      widget.info.backdropUrl ??
      widget.info.logoUrl;

  /// Air date the network broadcast this episode. Xtream usually ships
  /// it via `info.release_date`; when the source is M3U (or the panel
  /// left the field empty) we fall back to TMDB's `air_date`.
  String? get _airDate {
    final src = widget.episode.airDate;
    if (src != null && src.trim().isNotEmpty) return src.trim();
    return widget.tmdbEpisode?.airDate;
  }

  /// When the IPTV panel added the episode to the catalogue. Only
  /// available on Xtream (M3U has no equivalent). Returns the local
  /// date as `YYYY-MM-DD`.
  String? get _addedAtFormatted {
    final added = widget.episode.addedAt;
    if (added == null) return null;
    final l = added.toLocal();
    final mm = l.month.toString().padLeft(2, '0');
    final dd = l.day.toString().padLeft(2, '0');
    return '${l.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final plot = _plot;
    // Narrow screen (phone): vertical card - full-width image on top, then
    // the episode title, then the description. Wide: horizontal row (number
    // + small thumb + text).
    final isWide = MediaQuery.of(context).size.width >= 720;

    final dates = (_airDate != null || _addedAtFormatted != null)
        ? Text(
            [
              if (_airDate != null)
                ref.tr('series.airDate', {'date': _airDate!}),
              if (_addedAtFormatted != null)
                ref.tr('series.added', {'date': _addedAtFormatted!}),
            ].join(' · '),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          )
        : null;

    final Widget content = isWide
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${ep.episode}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                _EpisodeThumb(thumbUrl: _thumb, hover: _active),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (dates != null) ...[
                        const SizedBox(height: 4),
                        dates,
                      ],
                      if (_hasText(plot)) ...[
                        const SizedBox(height: 6),
                        Text(
                          plot!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.play_circle_outline_rounded,
                  size: 30,
                  color: _active ? AppColors.accent : AppColors.textTertiary,
                ),
              ],
            ),
          )
        : Padding(
            // Phone: vertical card. Full-width image on top.
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EpisodeThumb(thumbUrl: _thumb, hover: _active, expand: true),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ep.episode}. ',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 28,
                      color: _active ? AppColors.accent : AppColors.textTertiary,
                    ),
                  ],
                ),
                if (dates != null) ...[
                  const SizedBox(height: 4),
                  dates,
                ],
                if (_hasText(plot)) ...[
                  const SizedBox(height: 8),
                  Text(
                    plot!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _focus = v),
        // TV remote: play with OK/SELECT while the episode row is focused.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: BoxDecoration(
            border: (_focus && PlatformInfo.isTv)
                ? Border.all(color: AppColors.accent, width: 3)
                : null,
          ),
          child: Material(
            color: _active ? AppColors.surface : Colors.transparent,
            child: InkWell(onTap: widget.onTap, child: content),
          ),
        ),
      ),
    );
  }
}

class _EpisodeThumb extends StatelessWidget {
  final String? thumbUrl;
  final bool hover;
  // expand=true: full width, 16:9 (vertical card on phone). false: fixed
  // 160x90 (wide-screen row layout).
  final bool expand;
  const _EpisodeThumb({
    required this.thumbUrl,
    this.hover = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final playColor = hover
        ? AppColors.accent
        : Colors.white.withValues(alpha: 0.75);
    final inner = Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(expand ? 10 : 6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbUrl != null)
            CachedNetworkImage(
              fadeInDuration: const Duration(milliseconds: 220),
              fadeOutDuration: const Duration(milliseconds: 80),
              imageUrl: thumbUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: AppColors.surfaceElevated),
              errorWidget: (_, __, ___) =>
                  Container(color: AppColors.surfaceElevated),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            color: Colors.black.withValues(alpha: hover ? 0.35 : 0.5),
          ),
          Center(
            child: AnimatedScale(
              scale: hover ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: Icon(Icons.play_arrow_rounded, size: 40, color: playColor),
            ),
          ),
        ],
      ),
    );
    if (expand) {
      return SizedBox(
        width: double.infinity,
        child: AspectRatio(aspectRatio: 16 / 9, child: inner),
      );
    }
    return SizedBox(width: 160, height: 90, child: inner);
  }
}
