import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../epg/providers/epg_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../sources/domain/media_item.dart';
import '../data/thumbnail_service.dart';
import '../domain/series_queue.dart';
import 'progress_bar_with_preview.dart';

class ControlsOverlay extends ConsumerWidget {
  final Player player;
  final ThumbnailService? thumbnails;
  final bool visible;
  final bool isLive;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;
  final SeriesQueue? seriesQueue;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onShowEpisodes;
  final VoidCallback? onToggleInfo;
  final VoidCallback? onToggleSettings;
  final VoidCallback? onScreenshot;
  final VoidCallback? onDownload;
  final bool downloadInProgress;
  final double? downloadFraction;
  final VoidCallback? onGoLive;
  final MediaItem? favItem;
  final bool infoOpen;
  final bool settingsOpen;

  /// Routes the play/pause toggle through PlayerSession's user-intent
  /// wrappers so the auto-resume listener can tell user pauses apart
  /// from mpv's silent stalls. Receives the desired next state (`true`
  /// = play, `false` = pause). Falling back to direct player calls when
  /// null keeps tests / previews working.
  final void Function(bool play)? onSetPlaying;

  /// User-initiated seek wrapper. Routed to PlayerSession.seekByUser so
  /// the `_userPaused` flag is reset at the moment of the seek. Otherwise,
  /// when the user paused once and then seeked, auto-unpause was skipped
  /// while mpv was in a self-pause state. When null, falls back to a plain
  /// player.seek.
  final void Function(Duration target)? onUserSeek;

  /// When a seek scrub starts/ends. Stops the player's auto-hide timer.
  final ValueChanged<bool>? onScrubbing;

  const ControlsOverlay({
    super.key,
    required this.player,
    required this.visible,
    required this.title,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.isFullscreen,
    required this.isLive,
    this.thumbnails,
    this.seriesQueue,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.onShowEpisodes,
    this.onToggleInfo,
    this.onToggleSettings,
    this.onScreenshot,
    this.onDownload,
    this.downloadInProgress = false,
    this.downloadFraction,
    this.onGoLive,
    this.favItem,
    this.infoOpen = false,
    this.settingsOpen = false,
    this.onSetPlaying,
    this.onUserSeek,
    this.onScrubbing,
  });

  void _userSeek(Duration target) {
    final cb = onUserSeek;
    if (cb != null) {
      cb(target);
    } else {
      player.seek(target);
    }
  }

  void _togglePlayPause() {
    final playing = player.state.playing;
    final setter = onSetPlaying;
    if (setter != null) {
      setter(!playing);
    } else {
      playing ? player.pause() : player.play();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Even though the status bar is hidden in the player, viewPadding.top
    // keeps the physical notch / Dynamic Island inset (padding.top drops to
    // 0). The top bar starts below this value; on desktop viewPadding is 0,
    // so the old 28px (macOS traffic lights) is preserved.
    final viewTop = MediaQuery.viewPaddingOf(context).top;
    final topInset = viewTop > 28 ? viewTop : 28.0;
    // Keep the bottom controls (seek bar) from covering the iOS home
    // indicator and Android nav bar: the bottom overlay is preserved while
    // the status bar is hidden, so viewPadding.bottom > 0. On desktop 0, unchanged.
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 35),
      child: IgnorePointer(
        ignoring: !visible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Top inset clears the notch / Dynamic Island on mobile
              // (status bar hidden in the player) and the macOS traffic
              // lights on desktop (hidden title bar). See [topInset].
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, topInset, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: onBack,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
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
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isLive && favItem != null)
                            _LiveEpgStrip(item: favItem!),
                        ],
                      ),
                    ),
                    if (favItem != null) ...[
                      const SizedBox(width: 10),
                      _OverlayFavStar(item: favItem!),
                    ],
                  ],
                ),
              ),
            ),
            Center(
              child: StreamBuilder<bool>(
                stream: player.stream.buffering,
                initialData: player.state.buffering,
                builder: (_, snap) {
                  if (snap.data ?? false) {
                    return const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 3.5,
                      ),
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CenterIconButton(
                        icon: Icons.replay_10_rounded,
                        tooltip: ref.tr('player.back10Tip'),
                        onPressed: () => _userSeek(
                          Duration(
                            milliseconds:
                                (player.state.position.inMilliseconds - 10000)
                                    .clamp(0, 1 << 30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      _CenterPlayButton(
                        player: player,
                        onToggle: _togglePlayPause,
                      ),
                      const SizedBox(width: 24),
                      _CenterIconButton(
                        icon: Icons.forward_10_rounded,
                        tooltip: ref.tr('player.forward10Tip'),
                        onPressed: () {
                          final next =
                              player.state.position.inMilliseconds + 10000;
                          final dur = player.state.duration.inMilliseconds;
                          _userSeek(
                            Duration(
                              milliseconds: dur == 0
                                  ? next
                                  : next.clamp(0, dur),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(28, 12, 28, 22 + viewBottom),
                child: Column(
                  children: [
                    // Buffer stream is intentionally not watched on live
                    // - on HLS it fires constantly with values that don't
                    // map cleanly to a "seekable back" range, and reading
                    // it was the source of the freeze. Position + duration
                    // are still enough to drive the DVR cursor and clock
                    // labels.
                    if (isLive)
                      StreamBuilder<Duration>(
                        stream: player.stream.position,
                        initialData: player.state.position,
                        builder: (_, posSnap) {
                          return StreamBuilder<Duration>(
                            stream: player.stream.duration,
                            initialData: player.state.duration,
                            builder: (_, durSnap) {
                              return ProgressBarWithPreview(
                                position: posSnap.data ?? Duration.zero,
                                duration: durSnap.data ?? Duration.zero,
                                buffered: Duration.zero,
                                isLive: true,
                                controlsVisible: visible,
                                onSeek: _userSeek,
                                onScrubbing: onScrubbing,
                                onGoLive: onGoLive,
                              );
                            },
                          );
                        },
                      )
                    else
                      StreamBuilder<Duration>(
                        stream: player.stream.position,
                        initialData: player.state.position,
                        builder: (_, posSnap) {
                          return StreamBuilder<Duration>(
                            stream: player.stream.duration,
                            initialData: player.state.duration,
                            builder: (_, durSnap) {
                              return StreamBuilder<Duration>(
                                stream: player.stream.buffer,
                                initialData: player.state.buffer,
                                builder: (_, bufSnap) {
                                  return ProgressBarWithPreview(
                                    position: posSnap.data ?? Duration.zero,
                                    duration: durSnap.data ?? Duration.zero,
                                    buffered: bufSnap.data ?? Duration.zero,
                                    isLive: false,
                                    controlsVisible: visible,
                                    thumbnails: thumbnails,
                                    onSeek: _userSeek,
                                onScrubbing: onScrubbing,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    _BottomBar(
                      player: player,
                      isFullscreen: isFullscreen,
                      onToggleFullscreen: onToggleFullscreen,
                      onToggleInfo: onToggleInfo,
                      onToggleSettings: onToggleSettings,
                      onScreenshot: onScreenshot,
                      onDownload: onDownload,
                      onTogglePlayPause: _togglePlayPause,
                      onUserSeek: _userSeek,
                      downloadInProgress: downloadInProgress,
                      downloadFraction: downloadFraction,
                      seriesQueue: seriesQueue,
                      onPrevEpisode: onPrevEpisode,
                      onNextEpisode: onNextEpisode,
                      onShowEpisodes: onShowEpisodes,
                      infoOpen: infoOpen,
                      settingsOpen: settingsOpen,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "● CANLI/LIVE" badge plus the current wall-clock time on the right.
/// Refreshes once a minute (seconds aren't shown anyway) so we don't
/// repaint the overlay every tick.
/// Same star toggle used on channel tiles, mounted in the player's top
/// bar. Filled amber when this item is in favorites, hollow otherwise.
/// Tap toggles in place, no snackbar.
class _OverlayFavStar extends ConsumerWidget {
  final MediaItem item;
  const _OverlayFavStar({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider).value ?? const <String>{};
    final isFav = favs.contains(item.id);
    return IconButton(
      tooltip: isFav ? ref.tr('common.inFav') : ref.tr('common.addToFav'),
      icon: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFav ? Colors.redAccent : Colors.white,
        size: 39,
      ),
      onPressed: () =>
          ref.read(favoritesProvider.notifier).toggle(item.sourceId, item.id),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  final Player player;
  final VoidCallback onToggle;
  const _CenterPlayButton({required this.player, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (_, snap) {
        final playing = snap.data ?? false;
        return _FrostedCircleButton(
          size: 108,
          iconSize: 64,
          onPressed: onToggle,
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        );
      },
    );
  }
}

class _CenterIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _CenterIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // The replay/forward 10-second buttons follow the same frosted-glass
    // language as the center play/pause - the three round buttons side by
    // side look homogeneous, and the solid white icons create contrast so
    // they don't detach from the scene behind them.
    return _FrostedCircleButton(
      size: 64,
      iconSize: 36,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
    );
  }
}

/// Glassmorphism-style round button: blurs the video frame behind it and
/// gives a "frosted glass" feel with a semi-transparent white fill + a thin
/// border. This wrapper is used instead of a plain/solid-white IconButton.
class _FrostedCircleButton extends StatelessWidget {
  final double size;
  final double iconSize;
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  const _FrostedCircleButton({
    required this.size,
    required this.iconSize,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    // The border + ClipOval combination clashes with anti-aliasing in Skia;
    // a 1px sharp border + backdrop blur behind it produced a "jagged" edge.
    // We removed the border entirely; the outer ring is left to boxShadow
    // for contrast and a soft gradient for inner volume. The shadow is
    // built outside the ClipOval so it makes a soft glow around the circle
    // (it would be cut off if taken inside the clip).
    final inner = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final button = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: inner,
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _BottomBar extends ConsumerWidget {
  final Player player;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onTogglePlayPause;
  final void Function(Duration) onUserSeek;
  final VoidCallback? onToggleInfo;
  final VoidCallback? onToggleSettings;
  final VoidCallback? onScreenshot;
  final VoidCallback? onDownload;
  final bool downloadInProgress;
  final double? downloadFraction;
  final SeriesQueue? seriesQueue;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onShowEpisodes;
  final bool infoOpen;
  final bool settingsOpen;
  const _BottomBar({
    required this.player,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onTogglePlayPause,
    required this.onUserSeek,
    this.onToggleInfo,
    this.onToggleSettings,
    this.onScreenshot,
    this.onDownload,
    this.downloadInProgress = false,
    this.downloadFraction,
    this.seriesQueue,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.onShowEpisodes,
    this.infoOpen = false,
    this.settingsOpen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSeries = seriesQueue != null;
    // On phones (narrow screens) the bottom-bar icons looked too big; scale
    // by screen width. <600 phone, 600-900 small tablet.
    final w = MediaQuery.sizeOf(context).width;
    final scale = w < 600
        ? 0.66
        : w < 900
        ? 0.82
        : 1.0;
    double sz(double base) => base * scale;
    return Row(
      children: [
        StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (_, snap) {
            final playing = snap.data ?? false;
            return IconButton(
              tooltip: playing ? ref.tr('player.pause') : ref.tr('player.play'),
              iconSize: sz(42),
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              onPressed: onTogglePlayPause,
            );
          },
        ),
        if (hasSeries)
          IconButton(
            tooltip: ref.tr('player.prevEp'),
            iconSize: sz(36),
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
            onPressed: seriesQueue!.hasPrevious ? onPrevEpisode : null,
          ),
        // The +-10s buttons in the bottom bar were removed - the center
        // (on-screen) +-10s controls already exist, so the bottom bar stays
        // uncluttered (especially on phones).
        if (hasSeries)
          IconButton(
            tooltip: ref.tr('player.nextEp'),
            iconSize: sz(36),
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            onPressed: seriesQueue!.hasNext ? onNextEpisode : null,
          ),
        if (hasSeries && onShowEpisodes != null)
          IconButton(
            tooltip: ref.tr('player.episodes'),
            iconSize: sz(42),
            icon: const Icon(Icons.playlist_play_rounded, color: Colors.white),
            onPressed: onShowEpisodes,
          ),
        const SizedBox(width: 8),
        _VolumeSlider(player: player),
        const Spacer(),
        if (onDownload != null)
          IconButton(
            tooltip: downloadInProgress
                ? ref.tr('player.cancelDownload')
                : ref.tr('player.download'),
            iconSize: sz(39),
            icon: downloadInProgress
                ? SizedBox(
                    width: 39,
                    height: 39,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 33,
                          height: 33,
                          child: CircularProgressIndicator(
                            value: downloadFraction,
                            strokeWidth: 2.4,
                            color: AppColors.accent,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.stop_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: onDownload,
          ),
        if (onScreenshot != null)
          IconButton(
            tooltip: ref.tr('player.screenshot'),
            iconSize: sz(39),
            icon: const Icon(Icons.photo_camera_rounded, color: Colors.white),
            onPressed: onScreenshot,
          ),
        if (onToggleInfo != null)
          IconButton(
            tooltip: ref.tr('player.info'),
            iconSize: sz(39),
            icon: Icon(
              infoOpen ? Icons.info_rounded : Icons.info_outline_rounded,
              color: infoOpen ? AppColors.accent : Colors.white,
            ),
            onPressed: onToggleInfo,
          ),
        if (onToggleSettings != null)
          IconButton(
            tooltip: ref.tr('player.settings'),
            iconSize: sz(39),
            icon: Icon(
              settingsOpen ? Icons.tune_rounded : Icons.tune_rounded,
              color: settingsOpen ? AppColors.accent : Colors.white,
            ),
            onPressed: onToggleSettings,
          ),
        // Fullscreen / rotate-to-landscape button. On desktop it toggles the
        // window fullscreen; on mobile it rotates the video to landscape (issue
        // #2/1) - orientation is forced programmatically even when portrait is locked.
        IconButton(
          tooltip: isFullscreen
              ? ref.tr('player.exitFullscreen')
              : ref.tr('player.fullscreen'),
          iconSize: sz(42),
          icon: Icon(
            isFullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            color: Colors.white,
          ),
          onPressed: onToggleFullscreen,
        ),
      ],
    );
  }
}

class _VolumeSlider extends ConsumerWidget {
  final Player player;
  const _VolumeSlider({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (_, snap) {
        final vol = (snap.data ?? 100).clamp(0.0, 100.0);
        final muted = vol == 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: muted ? ref.tr('player.unmute') : ref.tr('player.mute'),
              iconSize: 36,
              icon: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
              ),
              onPressed: () => player.setVolume(muted ? 100 : 0),
            ),
            SizedBox(
              width: 110,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: AppColors.trackUnplayed,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: vol,
                  min: 0,
                  max: 100,
                  onChanged: player.setVolume,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One-line companion under the channel title in the top-bar that shows
/// the current programme and its end time (localized). Re-resolves every minute
/// on its own wall-clock-aligned timer so it ticks even if the rest of
/// the overlay is idle.
class _LiveEpgStrip extends ConsumerStatefulWidget {
  final MediaItem item;
  const _LiveEpgStrip({required this.item});

  @override
  ConsumerState<_LiveEpgStrip> createState() => _LiveEpgStripState();
}

class _LiveEpgStripState extends ConsumerState<_LiveEpgStrip> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    Future.delayed(Duration(seconds: 60 - n.second), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(epgProvider).value;
    if (snap == null) return const SizedBox.shrink();
    final cid = widget.item.epgChannelId ?? widget.item.streamId;
    final p = snap.nowPlaying(widget.item.sourceId, cid, _now);
    if (p == null) return const SizedBox.shrink();
    final stop = p.stop.toLocal();
    final hm =
        '${stop.hour.toString().padLeft(2, '0')}:'
        '${stop.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '${p.title} · ${ref.tr('live.untilTime', {'time': hm})}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
