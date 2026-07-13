import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../player/presentation/player_page.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../domain/epg_program.dart';
import '../providers/epg_provider.dart';

const double _kPxPerMinute = 4.0;
const double _kRowHeight = 64.0;
const double _kChannelColumnWidth = 200.0;
const double _kHeaderHeight = 40.0;
// -1 hour back + 48 hours forward. The 1-hour back margin keeps the
// now indicator line from starting flush against the left edge.
const Duration _kWindow = Duration(hours: 49);
const Duration _kBackOffset = Duration(hours: 1);

/// Program Guide: 2-way scroll EPG grid.
///
/// Layout: 2×2 shell + bottom-right hover banner overlay:
/// ```
/// ┌─────────────┬───────────────────────────┐
/// │  Now btn    │  Time ruler (h-scroll)    │
/// ├─────────────┼───────────────────────────┤
/// │  Channels   │  Program grid             │
/// │  (v-scroll) │  + now indicator overlay  │
/// │             │                  ┌──────┐ │
/// │             │                  │banner│ │
/// │             │                  └──────┘ │
/// └─────────────┴───────────────────────────┘
/// ```
/// Sticky edges are mirrored via `NeverScrollableScrollPhysics` plus a
/// listener bound to the body controller. A single `ScrollController`
/// cannot attach to two `Scrollable`s at once, so separate controllers
/// are used. The banner replaces the former Tooltip: a persistent card
/// in the bottom-right corner on hover, with no anchor flicker.
class EpgTimelineView extends ConsumerStatefulWidget {
  final List<MediaItem> liveChannels;
  const EpgTimelineView({super.key, required this.liveChannels});

  @override
  ConsumerState<EpgTimelineView> createState() => _EpgTimelineViewState();
}

class _EpgTimelineViewState extends ConsumerState<EpgTimelineView> {
  final _hBody = ScrollController();
  final _vBody = ScrollController();
  final _hHeader = ScrollController();
  final _vColumn = ScrollController();

  Timer? _ticker;
  DateTime _now = DateTime.now();
  late DateTime _windowStart;
  bool _didInitialScroll = false;

  // Memoized _visibleChannels.
  List<MediaItem>? _visibleCache;
  EpgSnapshot? _visibleEpgRef;
  List<MediaItem>? _visibleSourceRef;

  // Hover banner - bottom-right overlay. Isolated from setState via a
  // ValueNotifier, so only the banner subtree rebuilds. Tile-to-tile
  // transitions swallow the 1px padding gap with a 250ms delayed clear
  // through _exitTimer.
  final ValueNotifier<_HoveredInfo?> _hovered = ValueNotifier(null);
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _windowStart = _floorMinute(_now).subtract(_kBackOffset);
    _hBody.addListener(_syncHeader);
    _vBody.addListener(_syncColumn);
    _scheduleMinuteTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _exitTimer?.cancel();
    _hovered.dispose();
    _hBody.dispose();
    _vBody.dispose();
    _hHeader.dispose();
    _vColumn.dispose();
    super.dispose();
  }

  static DateTime _floorMinute(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);

  void _scheduleMinuteTicker() {
    final n = DateTime.now();
    final until = Duration(seconds: 60 - n.second);
    Future.delayed(until, () {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _maybeRotateWindow();
      });
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
          _maybeRotateWindow();
        });
      });
    });
  }

  /// In long-lived sessions (hours, even days) prevents `_now` from
  /// creeping toward the right edge of the window.
  void _maybeRotateWindow() {
    final windowEnd = _windowStart.add(_kWindow);
    if (_now.isAfter(windowEnd.subtract(const Duration(hours: 1)))) {
      _windowStart = _floorMinute(_now).subtract(_kBackOffset);
      _didInitialScroll = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToNow(animate: false);
      });
    }
  }

  void _syncHeader() {
    if (!_hHeader.hasClients) return;
    final off = _hBody.offset;
    if (_hHeader.offset != off) {
      _hHeader.jumpTo(
        off.clamp(
          _hHeader.position.minScrollExtent,
          _hHeader.position.maxScrollExtent,
        ),
      );
    }
  }

  void _syncColumn() {
    if (!_vColumn.hasClients) return;
    final off = _vBody.offset;
    if (_vColumn.offset != off) {
      _vColumn.jumpTo(
        off.clamp(
          _vColumn.position.minScrollExtent,
          _vColumn.position.maxScrollExtent,
        ),
      );
    }
  }

  void _scrollToNow({bool animate = true}) {
    if (!_hBody.hasClients) return;
    final mins = _now.difference(_windowStart).inMinutes;
    final target = ((mins - 30) * _kPxPerMinute).clamp(
      _hBody.position.minScrollExtent,
      _hBody.position.maxScrollExtent,
    );
    if (animate) {
      _hBody.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _hBody.jumpTo(target);
    }
  }

  void _setHovered(EpgProgram program, MediaItem channel) {
    _exitTimer?.cancel();
    final next = _HoveredInfo(program: program, channel: channel);
    if (_hovered.value != next) {
      _hovered.value = next;
    }
  }

  void _scheduleClearHovered() {
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _hovered.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final epg = ref.watch(epgProvider).value;
    final visible = _visibleChannels(epg);

    if (visible.isEmpty) {
      return _EmptyState(hasEpg: epg != null && epg.bySource.isNotEmpty);
    }

    final totalWidth = _kWindow.inMinutes * _kPxPerMinute;
    final nowLeftPx = _now.difference(_windowStart).inMinutes * _kPxPerMinute;

    if (!_didInitialScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToNow(animate: false);
        _didInitialScroll = true;
      });
    }

    return Stack(
      children: [
        // Outer MouseRegion: clear the banner when the mouse leaves the grid.
        MouseRegion(
          onExit: (_) => _scheduleClearHovered(),
          child: Column(
            children: [
              _Header(
                hController: _hHeader,
                windowStart: _windowStart,
                totalWidth: totalWidth,
                onNow: () => _scrollToNow(),
                nowLabel: ref.tr('live.now'),
                months: ref.tr('epg.monthsShort').split(','),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.divider),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ChannelSticky(channels: visible, controller: _vColumn),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.divider,
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _hBody,
                        thumbVisibility: false,
                        child: SingleChildScrollView(
                          controller: _hBody,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: totalWidth,
                            child: Stack(
                              children: [
                                ListView.builder(
                                  controller: _vBody,
                                  itemExtent: _kRowHeight,
                                  itemCount: visible.length,
                                  itemBuilder: (_, i) => _ChannelRow(
                                    channel: visible[i],
                                    epg: epg!,
                                    windowStart: _windowStart,
                                    windowMinutes: _kWindow.inMinutes,
                                    now: _now,
                                    onTap: (_) => _openChannel(visible[i]),
                                    onHover: (p) => _setHovered(p, visible[i]),
                                  ),
                                ),
                                if (nowLeftPx >= 0 && nowLeftPx <= totalWidth)
                                  Positioned(
                                    left: nowLeftPx - 1,
                                    top: 0,
                                    bottom: 0,
                                    width: 2,
                                    child: IgnorePointer(
                                      child: Container(color: Colors.redAccent),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Hover banner - bottom right. ValueListenableBuilder rebuilds only
        // this subtree; the ListView and tiles are unaffected.
        Positioned(
          right: 24,
          bottom: 24,
          child: ValueListenableBuilder<_HoveredInfo?>(
            valueListenable: _hovered,
            builder: (_, info, __) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: info == null
                    ? const SizedBox.shrink()
                    : _HoverBanner(
                        key: ValueKey(
                          '${info.channel.id}|'
                          '${info.program.start.millisecondsSinceEpoch}',
                        ),
                        info: info,
                        now: _now,
                        // Mouse over banner → cancel exit timer,
                        // leaving banner → close after 250ms.
                        onMouseEnter: () => _exitTimer?.cancel(),
                        onMouseExit: _scheduleClearHovered,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<MediaItem> _visibleChannels(EpgSnapshot? epg) {
    if (epg == null) return const [];
    if (identical(_visibleEpgRef, epg) &&
        identical(_visibleSourceRef, widget.liveChannels) &&
        _visibleCache != null) {
      return _visibleCache!;
    }
    final out = <MediaItem>[];
    for (final c in widget.liveChannels) {
      if (isAdult(c)) continue;
      final cid = c.epgChannelId ?? c.streamId;
      final list = epg.bySource[c.sourceId]?[cid];
      if (list != null && list.isNotEmpty) {
        out.add(c);
      }
    }
    _visibleEpgRef = epg;
    _visibleSourceRef = widget.liveChannels;
    _visibleCache = out;
    return out;
  }

  void _openChannel(MediaItem item) {
    GoRouter.of(context).pushOnce(
      '/player',
      extra: PlayerArgs(item: item, isLive: true, startAt: Duration.zero),
    );
  }
}

class _HoveredInfo {
  final EpgProgram program;
  final MediaItem channel;
  const _HoveredInfo({required this.program, required this.channel});

  @override
  bool operator ==(Object other) =>
      other is _HoveredInfo &&
      other.channel.id == channel.id &&
      other.program.start == program.start &&
      other.program.title == program.title;

  @override
  int get hashCode => Object.hash(channel.id, program.start, program.title);
}

class _Header extends StatelessWidget {
  final ScrollController hController;
  final DateTime windowStart;
  final double totalWidth;
  final VoidCallback onNow;
  final String nowLabel;
  final List<String> months;
  const _Header({
    required this.hController,
    required this.windowStart,
    required this.totalWidth,
    required this.onNow,
    required this.nowLabel,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kHeaderHeight,
      child: Row(
        children: [
          Container(
            width: _kChannelColumnWidth,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                right: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
              onPressed: onNow,
              icon: const Icon(Icons.my_location_rounded, size: 16),
              label: Text(nowLabel),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: AppColors.background),
              child: SingleChildScrollView(
                controller: hController,
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  height: _kHeaderHeight,
                  child: CustomPaint(
                    painter: _TimeRulerPainter(
                      windowStart: windowStart,
                      totalMinutes: _kWindow.inMinutes,
                      months: months,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  final DateTime windowStart;
  final int totalMinutes;
  final List<String> months;
  _TimeRulerPainter({
    required this.windowStart,
    required this.totalMinutes,
    required this.months,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hourTick = Paint()
      ..color = AppColors.textTertiary
      ..strokeWidth = 1;
    final halfTick = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    final m0 = windowStart.minute;
    var min = m0 == 0 ? 0 : 60 - m0;
    while (min <= totalMinutes) {
      final x = min * _kPxPerMinute;
      canvas.drawLine(
        Offset(x, size.height - 12),
        Offset(x, size.height),
        hourTick,
      );
      final t = windowStart.add(Duration(minutes: min));
      final showDay = t.hour == 0 || min == (m0 == 0 ? 0 : 60 - m0);
      final hh = t.hour.toString().padLeft(2, '0');
      final label = showDay ? '$hh:00  ${_dayMonth(t)}' : '$hh:00';
      tp.text = TextSpan(
        text: label,
        style: TextStyle(
          color: showDay ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: showDay ? FontWeight.w800 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x + 4, 8));

      final halfX = x + 30 * _kPxPerMinute;
      if (halfX <= size.width) {
        canvas.drawLine(
          Offset(halfX, size.height - 6),
          Offset(halfX, size.height),
          halfTick,
        );
      }
      min += 60;
    }
  }

  String _dayMonth(DateTime t) {
    final name = (t.month - 1) < months.length ? months[t.month - 1] : '';
    return '${t.day} $name';
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter old) =>
      old.windowStart != windowStart ||
      old.totalMinutes != totalMinutes ||
      // months is a new List each build → compare by value not reference,
      // else every rebuild repaints needlessly even if locale is unchanged.
      !listEquals(old.months, months);
}

class _ChannelSticky extends StatelessWidget {
  final List<MediaItem> channels;
  final ScrollController controller;
  const _ChannelSticky({required this.channels, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kChannelColumnWidth,
      decoration: const BoxDecoration(color: AppColors.surface),
      child: ListView.builder(
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        itemExtent: _kRowHeight,
        itemCount: channels.length,
        itemBuilder: (_, i) => _ChannelLabel(item: channels[i]),
      ),
    );
  }
}

class _ChannelLabel extends StatelessWidget {
  final MediaItem item;
  const _ChannelLabel({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: item.logoUrl == null
                  ? _LogoPlaceholder()
                  : CachedNetworkImage(
                      imageUrl: item.logoUrl!,
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          Container(color: AppColors.surfaceElevated),
                      errorWidget: (_, __, ___) => _LogoPlaceholder(),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(
        Icons.tv_rounded,
        size: 20,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final MediaItem channel;
  final EpgSnapshot epg;
  final DateTime windowStart;
  final int windowMinutes;
  final DateTime now;
  final void Function(EpgProgram p) onTap;
  final void Function(EpgProgram p) onHover;

  const _ChannelRow({
    required this.channel,
    required this.epg,
    required this.windowStart,
    required this.windowMinutes,
    required this.now,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final cid = channel.epgChannelId ?? channel.streamId;
    final all = epg.bySource[channel.sourceId]?[cid] ?? const <EpgProgram>[];
    final windowEnd = windowStart.add(Duration(minutes: windowMinutes));

    final visible = <EpgProgram>[];
    for (final p in all) {
      if (!p.stop.isAfter(windowStart)) continue;
      if (!p.start.isBefore(windowEnd)) break;
      visible.add(p);
    }

    return RepaintBoundary(
      child: SizedBox(
        height: _kRowHeight,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 0.5,
              child: Container(color: AppColors.divider),
            ),
            for (final p in visible) _positioned(p),
          ],
        ),
      ),
    );
  }

  Widget _positioned(EpgProgram p) {
    final startMin = p.start.difference(windowStart).inMinutes;
    final endMin = p.stop.difference(windowStart).inMinutes;
    final left = (startMin < 0 ? 0 : startMin) * _kPxPerMinute;
    final rawWidth = (endMin - (startMin < 0 ? 0 : startMin)) * _kPxPerMinute;
    final width = rawWidth.clamp(2.0, double.infinity).toDouble();
    final isLive = p.isLiveAt(now);
    return Positioned(
      left: left.toDouble(),
      top: 2,
      bottom: 2,
      width: width,
      child: _ProgramTile(
        program: p,
        isLive: isLive,
        onTap: () => onTap(p),
        onHover: () => onHover(p),
      ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  final EpgProgram program;
  final bool isLive;
  final VoidCallback onTap;
  final VoidCallback onHover;
  const _ProgramTile({
    required this.program,
    required this.isLive,
    required this.onTap,
    required this.onHover,
  });

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // EPG text comes from an untrusted panel source - embedded newlines /
    // multiple spaces break the tile height. Normalize to a single line.
    final cleanTitle = program.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      // MouseRegion sits outside Material - does not break InkWell hit area.
      // No onExit: the 1px gap on tile-to-tile transitions caused banner
      // flicker; instead the parent Stack's outermost MouseRegion does a
      // 250ms delayed clear.
      child: MouseRegion(
        onEnter: (_) => onHover(),
        child: Material(
          // Clip.antiAlias: even if a long title loses its ellipsis, the
          // Material/InkWell hover splash never crosses the tile boundary.
          // Without it, narrow tiles bled visually into the neighbor tile.
          clipBehavior: Clip.antiAlias,
          color: isLive
              ? AppColors.accent.withValues(alpha: 0.35)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isLive
                      ? AppColors.accent
                      : AppColors.divider.withValues(alpha: 0.6),
                  width: isLive ? 1.6 : 0.6,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: LayoutBuilder(
                builder: (_, c) {
                  // Below 80px the time + 2-line title got cramped and
                  // muddled. With a wider threshold, narrow tiles show
                  // only the time.
                  if (c.maxWidth < 80) {
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          _hm(program.start),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hm(program.start),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          cleanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: isLive
                                ? FontWeight.w800
                                : FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Persistent card in the bottom-right corner showing the hovered
/// program's detail. Replaces the Tooltip - no anchor flicker, no
/// scroll/zoom math.
class _HoverBanner extends ConsumerWidget {
  final _HoveredInfo info;
  final DateTime now;
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;
  const _HoverBanner({
    super.key,
    required this.info,
    required this.now,
    required this.onMouseEnter,
    required this.onMouseExit,
  });

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = info.program;
    final isLive = program.isLiveAt(now);
    final cleanTitle = program.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleanDesc = (program.description ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return MouseRegion(
      onEnter: (_) => onMouseEnter(),
      onExit: (_) => onMouseExit(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLive
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : AppColors.divider,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left stripe - accent when live, subtle otherwise.
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: isLive ? AppColors.accent : AppColors.divider,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                info.channel.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            if (isLive) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  ref.tr('live.badge'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cleanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_hm(program.start)} – ${_hm(program.stop)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        if (cleanDesc.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Text(
                                cleanDesc,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _EmptyState extends ConsumerWidget {
  final bool hasEpg;
  const _EmptyState({required this.hasEpg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_note_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              ref.tr('live.noEpgTitle'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasEpg
                  ? ref.tr('live.noEpgChannelsMsg')
                  : ref.tr('live.noEpgFetchingMsg'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
