import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/nav_throttle.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../library/providers/library_provider.dart';
import '../../player/domain/series_queue.dart';
import '../../player/presentation/player_page.dart';
import '../../series/providers/series_detail_provider.dart';
import '../../sources/domain/media_item.dart';

/// "Newly added series episodes" row. Source: series recently added to
/// the panel (recentSeries). Lazy fetch of SeriesDetail for each series;
/// shows only the SINGLE most recently added episode of that series (no
/// more than one episode from the same series in the list). Latest
/// addedAt first - no randomization.
class NewEpisodesRow extends ConsumerWidget {
  final List<MediaItem> recentSeries;
  const NewEpisodesRow({super.key, required this.recentSeries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (recentSeries.isEmpty) return const SizedBox.shrink();

    // Lazy fetch up to at most 30 series - more than that causes a
    // network blowup.
    final pick = recentSeries.take(30).toList();

    // Collect each series' episode with the LATEST addedAt. More than
    // one episode from a single series never enters the list.
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));
    final episodes = <_EpRef>[];
    for (final s in pick) {
      final detail = ref
          .watch(
            seriesDetailProvider(
              SeriesDetailArgs(sourceId: s.sourceId, seriesId: s.streamId),
            ),
          )
          .value;
      if (detail == null) continue;
      SeriesEpisode? best;
      for (final ep in detail.episodes) {
        if (ep.addedAt == null) continue;
        if (!ep.addedAt!.isAfter(cutoff)) continue;
        // An add date in the future = panel bug; ignore it.
        if (ep.addedAt!.isAfter(now)) continue;
        if (best == null || ep.addedAt!.isAfter(best.addedAt!)) {
          best = ep;
        }
      }
      if (best != null) {
        episodes.add(_EpRef(series: s, ep: best));
      }
    }
    if (episodes.isEmpty) return const SizedBox.shrink();
    episodes.sort((a, b) => b.ep.addedAt!.compareTo(a.ep.addedAt!));
    final visible = episodes.take(20).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              ref.tr('home.newEpisodes'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(
            // 168 thumbnail + 8 spacer + 2 lines of text (~38) + buffer.
            height: 256,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              clipBehavior: Clip.none,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _EpisodeCard(
                series: visible[i].series,
                episode: visible[i].ep,
                onTap: () => _playEpisode(context, visible[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playEpisode(BuildContext context, _EpRef ref) {
    // Build a queue starting from the clicked episode within this
    // series; mpv can continue by season when handling "next episode".
    final s = ref.series;
    // Building a queue for PlayerArgs without fetching the detail list
    // from the provider is not ideal - redirect to series detail.
    context.pushOnce('/series/${s.sourceId}/${s.streamId}');
  }
}

class _EpRef {
  final MediaItem series;
  final SeriesEpisode ep;
  const _EpRef({required this.series, required this.ep});
}

class _EpisodeCard extends StatefulWidget {
  final MediaItem series;
  final SeriesEpisode episode;
  final VoidCallback onTap;
  const _EpisodeCard({
    required this.series,
    required this.episode,
    required this.onTap,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final s = widget.series;
    final thumb = (ep.thumbnailUrl?.isNotEmpty ?? false)
        ? ep.thumbnailUrl
        : s.backdropUrl ?? s.logoUrl;
    final epLabel = 'S${ep.season} · B${ep.episode}';
    final cleanTitle = ep.title.replaceAll(RegExp(r'\s+'), ' ').trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 16:9 thumbnail
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 168,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    // Border color does not change on hover (user request).
                    boxShadow: _hover
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: AppColors.surfaceElevated),
                        if (thumb != null && thumb.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => const SizedBox.shrink(),
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          ),
                        // Bottom gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.black.withValues(alpha: 0.0),
                              ],
                              stops: const [0, 0.6],
                            ),
                          ),
                        ),
                        // Episode badge
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              epLabel,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                        // Play overlay (hover)
                        if (_hover)
                          Center(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.6),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cleanTitle.isEmpty ? epLabel : cleanTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// SeriesQueue import compatibility - used by other call sites.
typedef _UnusedQueue = SeriesQueue;
// PlayerArgs unused here but kept import to avoid lint when expanded.
typedef _UnusedArgs = PlayerArgs;
