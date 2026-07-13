import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../sources/domain/media_item.dart';
import '../domain/series_queue.dart';

class NextEpisodePill extends ConsumerWidget {
  final SeriesQueue queue;
  final VoidCallback onTap;
  const NextEpisodePill({super.key, required this.queue, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = queue.next;
    if (next == null) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child:
            Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.black,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ref.tr('player.upNextLabel'),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 230),
                            child: Text(
                              'S${next.season}E${next.episode} • ${next.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                .animate()
                .fade(duration: 220.ms)
                .slideY(
                  begin: 0.4,
                  end: 0,
                  curve: Curves.easeOutCubic,
                  duration: 240.ms,
                ),
      ),
    );
  }
}

/// End-of-episode / end-of-VOD overlay. If there is a next episode, a
/// compact bottom-right card that does not close the video; otherwise a
/// full-screen preview for discovery. In both cases [onClose] only closes
/// the overlay, it does not exit the player - so the user can see the
/// closing info / credits.
class UpNextOverlay extends ConsumerStatefulWidget {
  final SeriesQueue? seriesQueue;
  final List<MediaItem> relatedItems;

  /// Countdown trigger. While `false` the card sits like a notification,
  /// the countdown does not fill and no automatic transition happens - no
  /// transition until the user presses the "Play now" button. The player
  /// sets this to `true` after mpv reports `completed` (i.e. when the
  /// episode has actually ended).
  final bool autoplayActive;

  /// The content that just ended. In the background of the full-screen
  /// overlay this item's backdrop image is shown blurred - an atmospheric
  /// transition instead of a plain black screen.
  final MediaItem? endedItem;
  final VoidCallback onPlayNextEpisode;
  final void Function(MediaItem) onPlayItem;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  const UpNextOverlay({
    super.key,
    required this.relatedItems,
    required this.onPlayNextEpisode,
    required this.onPlayItem,
    required this.onReplay,
    required this.onClose,
    this.autoplayActive = false,
    this.seriesQueue,
    this.endedItem,
  });

  bool get hasNextEpisode => seriesQueue?.next != null;

  @override
  ConsumerState<UpNextOverlay> createState() => _UpNextOverlayState();
}

class _UpNextOverlayState extends ConsumerState<UpNextOverlay> {
  static const _autoplaySeconds = 8;
  Timer? _ticker;
  int _remaining = _autoplaySeconds;

  @override
  void initState() {
    super.initState();
    if (widget.hasNextEpisode && widget.autoplayActive) {
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(covariant UpNextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Player completion fired → autoplay was activated: start the
    // countdown now. Conversely, if the outside world turned autoplay off
    // (the user seeked back, etc.), stop the timer and reset the countdown.
    final shouldRun = widget.hasNextEpisode && widget.autoplayActive;
    final wasRunning = oldWidget.hasNextEpisode && oldWidget.autoplayActive;
    if (shouldRun && !wasRunning) {
      _remaining = _autoplaySeconds;
      _startTicker();
    } else if (!shouldRun && wasRunning) {
      _ticker?.cancel();
      _ticker = null;
      _remaining = _autoplaySeconds;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 1).clamp(0, _autoplaySeconds));
      if (_remaining == 0) {
        _ticker?.cancel();
        widget.onPlayNextEpisode();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _handlePlayNow() {
    _ticker?.cancel();
    widget.onPlayNextEpisode();
  }

  void _handleClose() {
    _ticker?.cancel();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    // The episode has not ended yet and there is a next episode → the
    // compact bottom-right notification card. The video keeps playing,
    // the credits can be watched.
    if (widget.hasNextEpisode && !widget.autoplayActive) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: 24,
            bottom: 24,
            child: _CompactNextCard(
              queue: widget.seriesQueue!,
              onPlayNow: _handlePlayNow,
              onClose: _handleClose,
            ),
          ),
        ],
      );
    }
    // Two full-screen cases: either the episode ended + there is a next
    // episode (autoplayActive=true), or there is no next episode at all
    // (the movie ended or it was the last episode). Both use the same
    // full-screen composition: a primary card at the top (next episode or
    // finished), with the "other recommendations" grid below.
    //
    // In the background the ended content's backdrop is drawn blurred; an
    // atmospheric transition instead of plain black. A title-based backdrop
    // is fetched via TMDB lookup, falling back to the item's own fields.
    final endedTmdb = widget.endedItem == null
        ? null
        : ref
              .watch(
                tmdbDetailProvider(TmdbLookupArgs.fromItem(widget.endedItem!)),
              )
              .value;
    final bgUrl =
        endedTmdb?.backdropUrl ??
        widget.endedItem?.backdropUrl ??
        endedTmdb?.posterUrl ??
        widget.endedItem?.logoUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bgUrl != null && bgUrl.isNotEmpty)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: CachedNetworkImage(
                imageUrl: bgUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.black),
                errorWidget: (_, __, ___) => Container(color: Colors.black),
              ),
            ),
          )
        else
          Container(color: Colors.black),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.72),
                Colors.black.withValues(alpha: 0.88),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 28,
            ),
            tooltip: ref.tr('common.close'),
            onPressed: _handleClose,
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.hasNextEpisode)
                  _BigNextEpisodeCard(
                    queue: widget.seriesQueue!,
                    remainingSeconds: _remaining,
                    onPlayNow: _handlePlayNow,
                  )
                else
                  _FinishedHeader(
                    onReplay: widget.onReplay,
                    onClose: _handleClose,
                  ),
                const SizedBox(height: 44),
                if (widget.relatedItems.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        ref.tr('player.upNextHeading'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _RelatedGrid(
                    items: widget.relatedItems,
                    onTap: widget.onPlayItem,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactNextCard extends ConsumerWidget {
  final SeriesQueue queue;
  final VoidCallback onPlayNow;
  final VoidCallback onClose;

  const _CompactNextCard({
    required this.queue,
    required this.onPlayNow,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = queue.next!;
    final thumbUrl = next.thumbnailUrl ?? queue.seriesPosterUrl;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child:
            Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              width: 380,
                              height: 180,
                              child: thumbUrl != null
                                  ? CachedNetworkImage(
                                      fadeInDuration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      fadeOutDuration: const Duration(
                                        milliseconds: 80,
                                      ),
                                      imageUrl: thumbUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) =>
                                          Container(color: AppColors.surface),
                                      errorWidget: (_, __, ___) =>
                                          Container(color: AppColors.surface),
                                    )
                                  : Container(color: AppColors.surface),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.7),
                                      Colors.transparent,
                                    ],
                                    stops: const [0, 0.7],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: onClose,
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ref.tr('player.upNextLabel'),
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 10,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                queue.seriesName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'S${next.season}E${next.episode} • ${next.title}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: onPlayNow,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(ref.tr('player.playNextEpisode')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fade(duration: 220.ms)
                .slideY(
                  begin: 0.25,
                  end: 0,
                  curve: Curves.easeOutCubic,
                  duration: 260.ms,
                ),
      ),
    );
  }
}

/// The large "next episode" card shown in full-screen mode. It opens
/// when the episode has actually ended (mpv completed); when the countdown
/// reaches zero the transition happens automatically, or the user can
/// press the Play now (Xs) button.
class _BigNextEpisodeCard extends ConsumerWidget {
  final SeriesQueue queue;
  final int remainingSeconds;
  final VoidCallback onPlayNow;

  const _BigNextEpisodeCard({
    required this.queue,
    required this.remainingSeconds,
    required this.onPlayNow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = queue.next!;
    final thumbUrl = next.thumbnailUrl ?? queue.seriesPosterUrl;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 240,
              height: 135,
              child: thumbUrl != null
                  ? CachedNetworkImage(
                      fadeInDuration: const Duration(milliseconds: 220),
                      fadeOutDuration: const Duration(milliseconds: 80),
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.surface),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.surface),
                    )
                  : Container(color: AppColors.surface),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ref.tr('player.upNextLabel'),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  queue.seriesName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'S${next.season}E${next.episode} • ${next.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (next.plot != null && next.plot!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    next.plot!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onPlayNow,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    '${ref.tr('player.playNow')} (${remainingSeconds}s)',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedHeader extends ConsumerWidget {
  final VoidCallback onReplay;
  final VoidCallback onClose;
  const _FinishedHeader({required this.onReplay, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.accent,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ref.tr('player.upNextTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ref.tr('player.upNextMsg'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onReplay,
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(ref.tr('player.replay')),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        ref.tr('common.close'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;
  const _RelatedGrid({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shown = items.take(8).toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1380),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        alignment: WrapAlignment.start,
        children: shown
            .map((item) => _RelatedCard(item: item, onTap: () => onTap(item)))
            .toList(),
      ),
    );
  }
}

class _RelatedCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _RelatedCard({required this.item, required this.onTap});

  @override
  ConsumerState<_RelatedCard> createState() => _RelatedCardState();
}

class _RelatedCardState extends ConsumerState<_RelatedCard> {
  bool _hover = false;

  static const _cardWidth = 320.0;
  static const _imageHeight = 180.0;

  /// Strip the noise from Xtream / scene release file names (release tag,
  /// codec, rip flag, year in parentheses, etc.) and produce a
  /// human-readable title. Used as a fallback when the TMDB lookup fails.
  String _cleanFallbackTitle(String raw) {
    var s = raw.replaceAll(RegExp(r'[._]+'), ' ').trim();
    // Drop year, codec and scene-release tags: "Movie 2020 1080p BluRay x264 DUAL"
    s = s.replaceAll(
      RegExp(
        r'\b(19|20)\d{2}\b|\b(720p|1080p|2160p|4k|m1080p)\b|\bbluray\b|'
        r'\bweb-?dl\b|\bhdrip\b|\bx264\b|\bx265\b|\bhevc\b|\bdual\b|'
        r'\bproper\b|\brepack\b|\bremastered\b|\b10bit\b|\baac\b|\bac3\b|'
        r'\bdts\b|\btr(\.dublaj)?\b|\bdublaj\b',
        caseSensitive: false,
      ),
      '',
    );
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final tmdbAsync = ref.watch(
      tmdbDetailProvider(TmdbLookupArgs.fromItem(widget.item)),
    );
    final tmdb = tmdbAsync.value;
    final imageUrl =
        tmdb?.backdropUrl ??
        widget.item.backdropUrl ??
        tmdb?.posterUrl ??
        widget.item.logoUrl;
    final title = (tmdb?.title?.trim().isNotEmpty ?? false)
        ? tmdb!.title!.trim()
        : _cleanFallbackTitle(widget.item.name);
    final plot = (tmdb?.overview?.trim().isNotEmpty ?? false)
        ? tmdb!.overview!.trim()
        : (widget.item.plot?.trim() ?? '');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? 0.55 : 0.35),
                  blurRadius: _hover ? 22 : 14,
                  offset: Offset(0, _hover ? 10 : 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: _cardWidth,
                      height: _imageHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            CachedNetworkImage(
                              fadeInDuration: const Duration(milliseconds: 220),
                              fadeOutDuration: const Duration(milliseconds: 80),
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.surfaceElevated),
                              errorWidget: (_, __, ___) =>
                                  Container(color: AppColors.surfaceElevated),
                            )
                          else
                            Container(color: AppColors.surfaceElevated),
                          if (_hover)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.35),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: Colors.white,
                                  size: 56,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (plot.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              plot,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
