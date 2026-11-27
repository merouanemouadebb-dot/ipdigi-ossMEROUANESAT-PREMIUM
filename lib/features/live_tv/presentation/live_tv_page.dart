import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/category_browse_layout.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/source_selector_bar.dart';
import '../../epg/domain/epg_program.dart';
import '../../epg/presentation/epg_timeline_view.dart';
import '../../epg/providers/epg_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../player/presentation/player_page.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/selected_source_provider.dart';
import '../../sources/providers/sources_provider.dart';
import 'discover_tab.dart';
import 'live_hero_carousel.dart';

enum _LiveTab { discover, channels, schedule }

class LiveTvPage extends ConsumerStatefulWidget {
  const LiveTvPage({super.key});

  @override
  ConsumerState<LiveTvPage> createState() => _LiveTvPageState();
}

class _LiveTvPageState extends ConsumerState<LiveTvPage> {
  // On TV the opening tab is Channels: Discover looks empty until EPG data
  // arrives, and a remote-control TV user should see the channel list at
  // once. On phone/desktop Discover (rich EPG discovery) stays.
  _LiveTab _tab = PlatformInfo.isTv ? _LiveTab.channels : _LiveTab.discover;

  @override
  Widget build(BuildContext context) {
    // Live TV page gate removed - a free user can see and play the channel
    // list, but there's a paywall after 2 min (via WatchLimiter). This is a
    // fairer trial: the user sees the content first, then subscribes.
    // Global source selection: null = All Sources. The selector is at the
    // top of the page (above the tab bar) and affects all tabs.
    final selectedSource = ref.watch(selectedSourceProvider).value;
    final itemsAsync = ref.watch(
      libraryItemsProvider(
        LibraryItemsArgs(kind: MediaKind.live, sourceId: selectedSource),
      ),
    );

    return Scaffold(
      // Custom header (no AppBar) -> we hand out the top safe area
      // ourselves so the SegmentedButton doesn't slip under the notch/Dynamic
      // Island. bottom false: the bottomNavigationBar handles its own inset.
      body: SafeArea(
        top: true,
        bottom: false,
        child: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateView(
              icon: Icons.live_tv_rounded,
              title: ref.tr('live.noChannels'),
              message: ref.tr('live.noChannelsMsg'),
              action: ElevatedButton(
                onPressed: () => context.go('/sources/add'),
                child: Text(ref.tr('sources.add')),
              ),
            );
          }

          return Column(
            children: [
              const SourceSelectorBar(),
              _TabBar(tab: _tab, onChanged: (t) => setState(() => _tab = t)),
              const Divider(height: 1, thickness: 1, color: AppColors.divider),
              Expanded(
                child: switch (_tab) {
                  _LiveTab.discover => DiscoverTab(liveChannels: items),
                  _LiveTab.channels => _ChannelsTab(items: items),
                  _LiveTab.schedule => EpgTimelineView(liveChannels: items),
                },
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}

class _TabBar extends ConsumerWidget {
  final _LiveTab tab;
  final ValueChanged<_LiveTab> onChanged;
  const _TabBar({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide the "Live TV" title on phone (it wastes the top area); the
    // SegmentedButton takes the whole row. On wide screens: title + tabs.
    final isWide = MediaQuery.of(context).size.width >= 720;
    if (!isWide && !PlatformInfo.isTv) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            for (final entry in <(_LiveTab, String)>[
              (_LiveTab.discover, 'live.tabDiscover'),
              (_LiveTab.channels, 'live.tabChannels'),
              (_LiveTab.schedule, 'live.tabSchedule'),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    onPressed: () => onChanged(entry.$1),
                    style: TextButton.styleFrom(
                      backgroundColor: tab == entry.$1
                          ? AppColors.accent : AppColors.surface,
                      foregroundColor: tab == entry.$1
                          ? Colors.black : AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 44),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(ref.tr(entry.$2),
                        style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      padding: isWide
          ? const EdgeInsets.fromLTRB(24, 14, 24, 12)
          : const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          if (isWide)
            Expanded(
              child: Text(
                ref.tr('nav.live'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          if (!isWide) const Spacer(),
          // TV: the SegmentedButton traps D-pad focus inside itself (you
          // couldn't move DOWN to the grid). Custom focusable tabs for the
          // remote: SELECT selects, DOWN moves into the content (grid).
          if (PlatformInfo.isTv)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TvTab(
                  label: ref.tr('live.tabDiscover'),
                  icon: Icons.explore_rounded,
                  selected: tab == _LiveTab.discover,
                  onTap: () => onChanged(_LiveTab.discover),
                ),
                const SizedBox(width: 8),
                _TvTab(
                  label: ref.tr('live.tabChannels'),
                  icon: Icons.grid_view_rounded,
                  selected: tab == _LiveTab.channels,
                  onTap: () => onChanged(_LiveTab.channels),
                ),
                const SizedBox(width: 8),
                _TvTab(
                  label: ref.tr('live.tabSchedule'),
                  icon: Icons.event_note_rounded,
                  selected: tab == _LiveTab.schedule,
                  onTap: () => onChanged(_LiveTab.schedule),
                ),
              ],
            )
          else
            SegmentedButton<_LiveTab>(
              segments: [
                ButtonSegment(
                  value: _LiveTab.discover,
                  label: Text(ref.tr('live.tabDiscover')),
                  icon: const Icon(Icons.explore_rounded, size: 16),
                ),
                ButtonSegment(
                  value: _LiveTab.channels,
                  label: Text(ref.tr('live.tabChannels')),
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                ),
                ButtonSegment(
                  value: _LiveTab.schedule,
                  label: Text(ref.tr('live.tabSchedule')),
                  icon: const Icon(Icons.event_note_rounded, size: 16),
                ),
              ],
              selected: {tab},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onChanged(s.first),
              style: ButtonStyle(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                foregroundColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return AppColors.isDark ? Colors.black : Colors.white;
                  }
                  return AppColors.textSecondary;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) return AppColors.accent;
                  return AppColors.surface;
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// Focusable tab button for TV (remote). Selected with SELECT/OK; a
/// distinct frame + accent on focus. Allows moving DOWN into the content
/// without the Material SegmentedButton's D-pad focus trap.
class _TvTab extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TvTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TvTab> createState() => _TvTabState();
}

class _TvTabState extends State<_TvTab> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final fg = active
        ? (AppColors.isDark ? Colors.black : Colors.white)
        : (_focus ? AppColors.accent : AppColors.textSecondary);
    final bg = active
        ? AppColors.accent
        : (_focus
            ? AppColors.accent.withValues(alpha: 0.16)
            : AppColors.surface);
    return Focus(
      onFocusChange: (v) => setState(() => _focus = v),
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: (_focus && !active)
                ? Border.all(color: AppColors.accent, width: 2)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current channel grid: favorites + recently watched smart
/// categories, with the country/category sidebar. The "Now Sports/News/
/// Movies" flows gave way to the Schedule timeline on the second tab.
class _ChannelsTab extends ConsumerWidget {
  final List<MediaItem> items;
  const _ChannelsTab({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider).value ?? const <String>{};
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final historyIds = history.map((h) => h.contentId).toSet();
    final historyOrder = {
      for (var i = 0; i < history.length; i++) history[i].contentId: i,
    };
    // An adult-free snapshot for recently watched. We DON'T look at the
    // showAdult setting - even if the user explicitly enables XXX, they
    // don't want porn in recently watched (explicit request).
    final safeItems = items.where((i) => !isAdult(i)).toList();

    final smart = <SmartCategoryDef>[
      SmartCategoryDef(
        id: 'favs',
        label: ref.tr('nav.favorites'),
        icon: Icons.favorite_rounded,
        selector: (all) => all.where((i) => favorites.contains(i.id)).toList(),
      ),
      SmartCategoryDef(
        id: 'recent',
        label: ref.tr('live.lastWatched'),
        icon: Icons.history_rounded,
        selector: (_) {
          final filtered = safeItems
              .where((i) => historyIds.contains(i.id))
              .toList();
          filtered.sort(
            (a, b) => (historyOrder[a.id] ?? 1 << 30).compareTo(
              historyOrder[b.id] ?? 1 << 30,
            ),
          );
          return filtered;
        },
      ),
    ];

    final mobile = !PlatformInfo.isTv &&
        MediaQuery.sizeOf(context).width < 720;
    return Column(
      children: [
        if (!mobile) LiveHeroCarousel(liveChannels: items),
        if (!mobile) const SizedBox(height: 8),
        Expanded(
          child: CategoryBrowseLayout(
            title: ref.tr('nav.live'),
            items: items,
            itemMaxExtent: 220,
            itemAspectRatio: mobile ? 1.0 : 16 / 11,
            headerSlotBuilder: mobile
                ? (context, selection) => LiveHeroCarousel(liveChannels: items)
                : null,
            smartCategories: smart,
            itemBuilder: (context, item) => _ChannelTile(
              item: item,
              onTap: () => context.pushOnce(
                '/player',
                extra: PlayerArgs(
                  item: item,
                  isLive: true,
                  startAt: Duration.zero,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChannelTile extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _ChannelTile({required this.item, required this.onTap});

  @override
  ConsumerState<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends ConsumerState<_ChannelTile> {
  bool _hover = false;
  bool _focus = false;
  bool get _active => _hover || _focus;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Re-resolve "now playing" once per minute. Aligned to the next
    // wall-clock minute so every tile flips at the same instant
    // instead of drifting independently.
    final n = DateTime.now();
    final untilMinute = Duration(seconds: 60 - n.second);
    Future.delayed(untilMinute, () {
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

  EpgProgram? _resolveNowPlaying() {
    final snap = ref.watch(epgProvider).value;
    if (snap == null) return null;
    final cid = widget.item.epgChannelId ?? widget.item.streamId;
    final hit = snap.nowPlaying(widget.item.sourceId, cid, _now);
    if (hit != null) return hit;
    if (widget.item.epgChannelId != null) {
      return snap.nowPlaying(widget.item.sourceId, widget.item.streamId, _now);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final favs = ref.watch(favoritesProvider).value ?? const <String>{};
    final isFav = favs.contains(widget.item.id);
    final nowPlaying = _resolveNowPlaying();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _focus = v),
        // TV remote: open the focused channel card with OK/SELECT. The card
        // must be focusable so the grid can be navigated with the D-pad.
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
        child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _active ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              // Accent frame on focus on TV (clear selection with the
              // remote); neutral shadow on hover.
              border: (_focus && PlatformInfo.isTv)
                  ? Border.all(color: AppColors.accent, width: 3)
                  : null,
              boxShadow: _active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: widget.item.logoUrl == null
                                ? _PlayPlaceholder(highlight: _hover)
                                : CachedNetworkImage(
                                    fadeInDuration: const Duration(
                                      milliseconds: 220,
                                    ),
                                    fadeOutDuration: const Duration(
                                      milliseconds: 80,
                                    ),
                                    imageUrl: widget.item.logoUrl!,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) =>
                                        Container(color: AppColors.background),
                                    errorWidget: (_, __, ___) =>
                                        _PlayPlaceholder(highlight: _hover),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.item.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (nowPlaying != null) ...[
                          const SizedBox(height: 4),
                          _NowPlayingLine(program: nowPlaying, now: _now),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _FavStarButton(
                    isFav: isFav,
                    onTap: () => ref
                        .read(favoritesProvider.notifier)
                        .toggle(widget.item.sourceId, widget.item.id),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Two-line block under the channel name: the current programme's
/// title plus a thin progress bar tracking how far through the
/// programme we are. Falls back to a stop-time label when the
/// programme has just under a minute left, so the tile doesn't read
/// "100 %" while the next item hasn't yet been resolved.
class _NowPlayingLine extends StatelessWidget {
  final EpgProgram program;
  final DateTime now;
  const _NowPlayingLine({required this.program, required this.now});

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = program.progressAt(now);
    // The EPG text comes from an untrusted panel source - embedded newlines
    // / multiple spaces can break tile height. Normalize to a single line.
    final cleanTitle = program.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                cleanTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _hm(program.stop),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _FavStarButton extends StatelessWidget {
  final bool isFav;
  final VoidCallback onTap;
  const _FavStarButton({required this.isFav, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.45),
          ),
          alignment: Alignment.center,
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: isFav
                ? Colors.redAccent
                : Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _PlayPlaceholder extends StatelessWidget {
  final bool highlight;
  const _PlayPlaceholder({this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlight
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.surfaceElevated,
          border: Border.all(
            color: highlight
                ? AppColors.accent
                : AppColors.textTertiary.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          size: 32,
          color: highlight ? AppColors.accent : AppColors.textTertiary,
        ),
      ),
    );
  }
}
