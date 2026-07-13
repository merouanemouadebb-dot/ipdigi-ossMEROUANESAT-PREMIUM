import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_format.dart';
import '../data/thumbnail_service.dart';

class ProgressBarWithPreview extends ConsumerStatefulWidget {
  final Duration position;
  final Duration buffered;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onGoLive;
  final ThumbnailService? thumbnails;
  final bool isLive;

  /// Is the controls overlay visible? When hidden, the hover state (ghost
  /// vertical line + thumbnail bubble) is reset. Otherwise, when controls
  /// are hidden via AnimatedOpacity they stay in the widget tree, so
  /// MouseRegion.onExit never fires and the ghost stayed frozen at its last
  /// position - when the controls reappeared the old hover trace was still
  /// on screen.
  final bool controlsVisible;

  /// True when the user starts scrubbing (dragging), false when it ends.
  /// The player listens to this and stops the auto-hide timer (so controls
  /// are not hidden during the drag, otherwise the drag is cut off midway).
  final ValueChanged<bool>? onScrubbing;

  const ProgressBarWithPreview({
    super.key,
    required this.position,
    required this.buffered,
    required this.duration,
    required this.onSeek,
    required this.isLive,
    this.controlsVisible = true,
    this.onGoLive,
    this.thumbnails,
    this.onScrubbing,
  });

  @override
  ConsumerState<ProgressBarWithPreview> createState() =>
      _ProgressBarWithPreviewState();
}

class _ProgressBarWithPreviewState
    extends ConsumerState<ProgressBarWithPreview> {
  double? _hoverFraction;
  bool _dragging = false;

  /// VOD optimistic scrubber: when the user seeks to a point, the thumb and
  /// the filled bar park there INSTANTLY without waiting for mpv's real
  /// `position` stream. Once the real position reaches the target,
  /// [didUpdateWidget] clears this to null and the thumb tracks the real
  /// position again. (`_liveSeekFraction` does the same job on the live
  /// branch.)
  double? _seekFraction;

  @override
  void didUpdateWidget(covariant ProgressBarWithPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the real position got close to the optimistic seek target (≈1 s),
    // release it so the thumb goes back to tracking the real playback
    // position. If a drag is still in progress, leave it alone (the finger
    // is still in control).
    if (_seekFraction != null && !_dragging) {
      final totalMs = widget.duration.inMilliseconds;
      if (totalMs > 0) {
        final targetMs = _seekFraction! * totalMs;
        final posMs = widget.position.inMilliseconds.toDouble();
        if ((posMs - targetMs).abs() < 1000) {
          _seekFraction = null;
        }
      }
    }
    // Clear the hover ghost when controls become invisible. Otherwise the
    // mouse exit event does not fire (under IgnorePointer, pointer state
    // changes are not reported), and the ghost stays frozen at its old
    // position.
    // CRITICAL: if controls are hidden during an active drag (3s auto-hide
    // timer), FORCE-resetting _dragging/_hoverFraction here cut the drag
    // off midway (dragEnd could not seek). Now clear ONLY WHEN NOT DRAGGING.
    // (During a scrub the player already stops auto-hide; this is extra
    // safety.)
    if (oldWidget.controlsVisible && !widget.controlsVisible && !_dragging) {
      if (_hoverFraction != null) {
        setState(() => _hoverFraction = null);
      }
    }
  }

  /// `null` while the user is at the live edge. Set to a 0..1 fraction
  /// after a manual seek, so the cursor parks at that spot instead of
  /// chasing mpv's noisy `position` stream. "Go Live" clears this back
  /// to null.
  double? _liveSeekFraction;

  String _hm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _seekLive(double fraction, int totalMs) {
    // f == 1.0 means the user dropped the cursor at the live edge - treat
    // that the same as Go Live so the pill clears and the cursor pins.
    if (fraction >= 0.995) {
      _goLive();
      return;
    }
    setState(() => _liveSeekFraction = fraction);
    widget.onSeek(Duration(milliseconds: (fraction * totalMs).round()));
  }

  void _goLive() {
    setState(() => _liveSeekFraction = null);
    // Re-open the manifest via the player session - `seek` to the live
    // edge is silently dropped by mpv on most HLS sources, but opening
    // the URL again always lands on the newest segment.
    final cb = widget.onGoLive;
    if (cb != null) {
      cb();
    } else {
      // Fallback when the wiring is missing - best-effort seek.
      final target = widget.duration - const Duration(seconds: 2);
      widget.onSeek(target.isNegative ? Duration.zero : target);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLive) {
      return _liveIndicator();
    }
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) {
      return const SizedBox(height: 36);
    }

    final positionMs = widget.position.inMilliseconds.clamp(0, totalMs);
    final bufferedMs = widget.buffered.inMilliseconds.clamp(0, totalMs);
    final playedFraction = positionMs / totalMs;
    final bufferedFraction = bufferedMs / totalMs;
    // Position of the thumb and the filled bar:
    //  - WHILE DRAGGING it tracks the finger (_hoverFraction),
    //  - after a tap it parks at the optimistic target (_seekFraction),
    //  - otherwise it stays at the real position (playedFraction).
    // On plain HOVER (mouse moving, no tap) the thumb STAYS PUT - hover only
    // moves the ghost vertical line, not the thumb.
    final effectiveFraction = _dragging
        ? (_hoverFraction ?? _seekFraction ?? playedFraction)
        : (_seekFraction ?? playedFraction);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_hoverFraction != null)
                Positioned(
                  // CRITICAL key: when the bubble is INSERTED as the first
                  // child of the Stack (on the first drag update,
                  // _hoverFraction null->value), without a key reconciliation
                  // matches by index, so the GestureDetector below (and its
                  // active drag recognizer) was destroyed and rebuilt -> the
                  // first seek was cancelled midway. Keys make the move safe.
                  key: const ValueKey('seekbar-preview-bubble'),
                  left:
                      (_hoverFraction! * width).clamp(60.0, width - 60.0) - 60,
                  bottom: 38,
                  child: _PreviewBubble(
                    timeText: formatDuration(
                      Duration(
                        milliseconds: (_hoverFraction! * totalMs).round(),
                      ),
                    ),
                    frame: widget.thumbnails?.frameAtSecond(
                      ((_hoverFraction! * totalMs) / 1000).round(),
                    ),
                  ),
                ),
              Positioned(
                // Stable key: so this GestureDetector's element (and its drag
                // recognizer) is preserved as the bubble is added/removed, to
                // avoid a mid-drag teardown.
                key: const ValueKey('seekbar-touch-target'),
                left: 0,
                right: 0,
                bottom: 16,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (e) {
                    final f = (e.localPosition.dx / width).clamp(0.0, 1.0);
                    setState(() {
                      // Hover = pointer NOT pressed = no drag. If in a rare
                      // gesture-arena case onHorizontalDragEnd/Cancel never
                      // arrives and _dragging stays stuck ("as if the mouse is
                      // dragging" behavior: the thumb follows the cursor), it
                      // is cleared here on the next mouse move.
                      if (_dragging) _dragging = false;
                      _hoverFraction = f;
                    });
                    final seconds = ((f * totalMs) / 1000).round();
                    widget.thumbnails?.requestAt(seconds);
                  },
                  onExit: (_) {
                    if (!_dragging) setState(() => _hoverFraction = null);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // onTapDown: the thumb jumps to the tapped spot the moment
                    // the finger touches (VISUAL only - _seekFraction). The real
                    // seek (mpv) is NOT done here; so a touch that turns into a
                    // drag does not trigger an instant seek (the "play the movie
                    // right there" bug), the seek is left to onTapUp/dragEnd. If
                    // a drag starts, _hoverFraction takes over and the thumb
                    // follows the finger.
                    onTapDown: (d) {
                      final f = (d.localPosition.dx / width).clamp(0.0, 1.0);
                      setState(() => _seekFraction = f);
                    },
                    onTapUp: (d) {
                      final f = (d.localPosition.dx / width).clamp(0.0, 1.0);
                      setState(() => _seekFraction = f);
                      widget.onSeek(
                        Duration(milliseconds: (f * totalMs).round()),
                      );
                    },
                    onHorizontalDragStart: (_) {
                      setState(() => _dragging = true);
                      widget.onScrubbing?.call(true);
                    },
                    onHorizontalDragUpdate: (d) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final local = box.globalToLocal(d.globalPosition);
                      final f = (local.dx / width).clamp(0.0, 1.0);
                      setState(() => _hoverFraction = f);
                      final seconds = ((f * totalMs) / 1000).round();
                      widget.thumbnails?.requestAt(seconds);
                    },
                    onHorizontalDragEnd: (_) {
                      if (_hoverFraction != null) {
                        widget.onSeek(
                          Duration(
                            milliseconds: (_hoverFraction! * totalMs).round(),
                          ),
                        );
                      }
                      widget.onScrubbing?.call(false);
                      setState(() {
                        // Park the thumb where the finger let go (it does not
                        // jump back until the real position catches up).
                        _seekFraction = _hoverFraction ?? _seekFraction;
                        _dragging = false;
                        _hoverFraction = null;
                      });
                    },
                    onHorizontalDragCancel: () {
                      // If the drag arena is lost this fires instead of
                      // onHorizontalDragEnd; if the scrubbing flag is not
                      // cleared the auto-hide timer stays off permanently and
                      // the hover ghost cursor freezes.
                      widget.onScrubbing?.call(false);
                      if (_dragging || _hoverFraction != null) {
                        setState(() {
                          _dragging = false;
                          _hoverFraction = null;
                        });
                      }
                    },
                    child: SizedBox(
                      height: 24,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.trackUnplayed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: bufferedFraction,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.buffered,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: effectiveFraction,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          if (_hoverFraction != null)
                            Positioned(
                              left: (_hoverFraction! * width) - 1,
                              child: Container(
                                width: 2,
                                height: 18,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          Positioned(
                            left: (effectiveFraction * width) - 7,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: Text(
                  formatDuration(widget.position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  formatDuration(widget.duration),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// DVR scrubber for live streams. The buffer track is intentionally not
  /// drawn - that stream was the freeze source. Cursor stays pinned at the
  /// live edge until the user manually seeks back, at which point it parks
  /// where they dropped it (driven by `_liveSeekFraction`, not by `position`,
  /// so HLS jitter cannot wobble the thumb).
  Widget _liveIndicator() {
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) {
      return _liveBadgeOnly();
    }

    final atLiveEdge = _liveSeekFraction == null;
    final playedFraction = atLiveEdge ? 1.0 : _liveSeekFraction!;
    // On the live branch the thumb already parks via `_liveSeekFraction`
    // (optimistic). It should follow the finger ONLY WHILE DRAGGING; on
    // plain hover it stays put (hover only moves the ghost line).
    final effectiveFraction = _dragging
        ? (_hoverFraction ?? playedFraction)
        : playedFraction;
    // Buffer is intentionally hidden on live (the stream was flaky); keep
    // the variable so the shared track code still compiles, just at 0.
    const bufferedFraction = 0.0;

    final now = DateTime.now();
    final liveEdge = now;
    final windowStart = now.subtract(widget.duration);
    final cursorTime = atLiveEdge
        ? now
        : now.subtract(
            Duration(milliseconds: ((1 - playedFraction) * totalMs).round()),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_hoverFraction != null)
                Positioned(
                  // CRITICAL key: when the bubble is INSERTED as the first
                  // child of the Stack (on the first drag update,
                  // _hoverFraction null->value), without a key reconciliation
                  // matches by index, so the GestureDetector below (and its
                  // active drag recognizer) was destroyed and rebuilt -> the
                  // first seek was cancelled midway. Keys make the move safe.
                  key: const ValueKey('seekbar-preview-bubble'),
                  left:
                      (_hoverFraction! * width).clamp(60.0, width - 60.0) - 60,
                  bottom: 38,
                  child: _PreviewBubble(
                    timeText: _hm(
                      now.subtract(
                        Duration(
                          milliseconds: (totalMs * (1 - _hoverFraction!))
                              .round(),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                // Stable key: so this GestureDetector's element (and its drag
                // recognizer) is preserved as the bubble is added/removed, to
                // avoid a mid-drag teardown.
                key: const ValueKey('seekbar-touch-target'),
                left: 0,
                right: 0,
                bottom: 16,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (e) {
                    final f = (e.localPosition.dx / width).clamp(0.0, 1.0);
                    setState(() {
                      // Hover = pointer not pressed = no drag; clear a stuck
                      // _dragging (see the VOD branch explanation).
                      if (_dragging) _dragging = false;
                      _hoverFraction = f;
                    });
                  },
                  onExit: (_) {
                    if (!_dragging) setState(() => _hoverFraction = null);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // onTapUp: so it does not do an instant seek at the start
                    // of a drag (see the VOD branch explanation).
                    onTapUp: (d) {
                      final f = (d.localPosition.dx / width).clamp(0.0, 1.0);
                      _seekLive(f, totalMs);
                    },
                    onHorizontalDragStart: (_) {
                      setState(() => _dragging = true);
                      widget.onScrubbing?.call(true);
                    },
                    onHorizontalDragUpdate: (d) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final local = box.globalToLocal(d.globalPosition);
                      final f = (local.dx / width).clamp(0.0, 1.0);
                      setState(() => _hoverFraction = f);
                    },
                    onHorizontalDragEnd: (_) {
                      if (_hoverFraction != null) {
                        _seekLive(_hoverFraction!, totalMs);
                      }
                      widget.onScrubbing?.call(false);
                      setState(() {
                        _dragging = false;
                        _hoverFraction = null;
                      });
                    },
                    onHorizontalDragCancel: () {
                      // If the drag arena is lost this fires instead of
                      // onHorizontalDragEnd; if the scrubbing flag is not
                      // cleared the auto-hide timer stays off permanently and
                      // the hover ghost cursor freezes.
                      widget.onScrubbing?.call(false);
                      if (_dragging || _hoverFraction != null) {
                        setState(() {
                          _dragging = false;
                          _hoverFraction = null;
                        });
                      }
                    },
                    child: SizedBox(
                      height: 24,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.trackUnplayed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: bufferedFraction,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.buffered,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: effectiveFraction,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          if (_hoverFraction != null)
                            Positioned(
                              left: (_hoverFraction! * width) - 1,
                              child: Container(
                                width: 2,
                                height: 18,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          Positioned(
                            left: (effectiveFraction * width) - 7,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: Text(
                  _hm(windowStart),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    _hm(cursorTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _hm(liveEdge),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _LivePill(
                      atLiveEdge: atLiveEdge,
                      label: atLiveEdge
                          ? ref.tr('player.live')
                          : ref.tr('player.goLive'),
                      onTap: atLiveEdge ? null : _goLive,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _liveBadgeOnly() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ref.tr('player.live'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final bool atLiveEdge;
  final String label;
  final VoidCallback? onTap;
  const _LivePill({
    required this.atLiveEdge,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clickable = onTap != null;
    return MouseRegion(
      cursor: clickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: atLiveEdge
                ? Colors.transparent
                : AppColors.accent.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.accent, width: 1.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (atLiveEdge) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: atLiveEdge ? Colors.white : AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  final String timeText;
  final Uint8List? frame;
  const _PreviewBubble({required this.timeText, this.frame});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (frame != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.memory(
                frame!,
                width: 160,
                height: 90,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            timeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
