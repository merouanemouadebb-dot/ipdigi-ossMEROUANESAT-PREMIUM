
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_info_provider.dart';
import '../../core/config/platform_info.dart';
import '../../core/demo/demo_mode.dart';
import '../../core/l10n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../features/sources/providers/sources_provider.dart';
import 'app_brand.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const double _desktopTopInset = 32;

  static const _items = <_NavItem>[
    _NavItem(labelKey: 'nav.home', icon: Icons.home_rounded, route: '/home'),
    _NavItem(labelKey: 'nav.live', icon: Icons.live_tv_rounded, route: '/live'),
    _NavItem(
      labelKey: 'nav.movies',
      icon: Icons.movie_rounded,
      route: '/movies',
    ),
    _NavItem(labelKey: 'nav.series', icon: Icons.tv_rounded, route: '/series'),
    _NavItem(
      labelKey: 'nav.search',
      icon: Icons.search_rounded,
      route: '/search',
    ),
    _NavItem(
      labelKey: 'nav.favorites',
      icon: Icons.favorite_rounded,
      route: '/library',
    ),
    _NavItem(
      labelKey: 'nav.myRatings',
      icon: Icons.star_rounded,
      route: '/ratings',
    ),
    _NavItem(
      labelKey: 'nav.watchlists',
      icon: Icons.playlist_play_rounded,
      route: '/watchlists',
    ),
    _NavItem(
      labelKey: 'nav.continueWatching',
      icon: Icons.play_circle_outline_rounded,
      route: '/continue',
    ),
    _NavItem(
      labelKey: 'nav.history',
      icon: Icons.history_rounded,
      route: '/history',
    ),
    _NavItem(
      labelKey: 'nav.settings',
      icon: Icons.settings_rounded,
      route: '/settings',
    ),
    _NavItem(
      labelKey: 'nav.profile',
      icon: Icons.account_circle_rounded,
      route: '/profile',
    ),
  ];

  static const _bottomRoutes = {'/settings', '/profile'};
  static const _dividersAfter = {'/series'};

  static const _mobilePrimaryRoutes = <String>[
    '/home',
    '/live',
    '/movies',
    '/series',
    '/search',
  ];

  static const _detailRouteToPrimary = <String, String>{
    '/movie': '/movies',
    '/person': '/movies',
    '/tag': '/movies',
  };

  int _currentIndex(String location) {
    final canonical = _primaryRouteFor(location) ?? location;

    for (int i = 0; i < _items.length; i++) {
      final route = _items[i].route;
      if (canonical == route ||
          canonical.startsWith('$route/')) {
        return i;
      }
    }

    return 0;
  }

  String? _primaryRouteFor(String location) {
    for (final r in _mobilePrimaryRoutes) {
      if (location == r || location.startsWith('$r/')) {
        return r;
      }
    }

    for (final entry in _detailRouteToPrimary.entries) {
      if (location.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _currentIndex(location);

    final sourcesAsync = ref.watch(sourcesProvider);
    final hasSources = sourcesAsync.value?.isNotEmpty ?? false;

    final isWide =
        PlatformInfo.isTv ||
        MediaQuery.sizeOf(context).width >= 720;

    final entries = _items
        .map(
          (i) => _ResolvedNavItem(
            label: ref.tr(i.labelKey),
            icon: i.icon,
            route: i.route,
          ),
        )
        .toList();

    final mobilePrimary = <_ResolvedNavItem>[
      for (final r in _mobilePrimaryRoutes)
        entries.firstWhere((e) => e.route == r),
    ];

    final mobileOverflow = entries
        .where((e) => !_mobilePrimaryRoutes.contains(e.route))
        .toList();

    final primaryMatch = _primaryRouteFor(location);

    int mobileIndex = primaryMatch == null
        ? mobilePrimary.length
        : mobilePrimary.indexWhere(
            (e) => e.route == primaryMatch,
          );

    if (mobileIndex < 0) {
      mobileIndex = mobilePrimary.length;
    }

    Widget content = child;

    if (!kIsWeb && Platform.isWindows) {
      final mq = MediaQuery.of(context);

      content = MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(
            top: mq.padding.top + _desktopTopInset,
          ),
          viewPadding: mq.viewPadding.copyWith(
            top: mq.viewPadding.top + _desktopTopInset,
          ),
        ),
        child: child,
      );
    }

    return _BackHandler(
      child: Scaffold(
        body: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Row(
            children: [
              if (isWide && hasSources)
                _SideRail(
                  items: entries,
                  currentIndex: index,
                  onTap: (i) => context.go(entries[i].route),
                ),
              Expanded(child: content),
            ],
          ),
        ),
        bottomNavigationBar: (isWide || !hasSources)
            ? null
            : BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: mobileIndex,
                onTap: (i) {
                  if (i < mobilePrimary.length) {
                    context.go(mobilePrimary[i].route);
                  } else {
                    _showMobileMore(
                      context,
                      mobileOverflow,
                      ref,
                    );
                  }
                },
                items: [
                  for (final item in mobilePrimary)
                    BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.more_horiz_rounded),
                    label: ref.tr('nav.more'),
                  ),
                ],
              ),
      ),
    );
  }

  void _showMobileMore(
    BuildContext context,
    List<_ResolvedNavItem> items,
    WidgetRef ref,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final entry in items)
                ListTile(
                  leading: Icon(
                    entry.icon,
                    color: AppColors.textPrimary,
                  ),
                  title: Text(entry.label),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(entry.route);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BackHandler extends ConsumerStatefulWidget {
  final Widget child;
  const _BackHandler({required this.child});

  @override
  ConsumerState<_BackHandler> createState() =>
      _BackHandlerState();
}

class _BackHandlerState
    extends ConsumerState<_BackHandler> {
  DateTime? _lastBackAt;

  void _handleBack() {
    final router = GoRouter.of(context);

    if (router.canPop()) {
      router.pop();
      return;
    }

    final loc = GoRouterState.of(context).matchedLocation;

    if (loc != '/home') {
      context.go('/home');
      return;
    }

    final now = DateTime.now();

    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) <
            const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackAt = now;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(ref.tr('common.pressBackToExit')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: widget.child,
    );
  }
}

class _NavItem {
  final String labelKey;
  final IconData icon;
  final String route;

  const _NavItem({
    required this.labelKey,
    required this.icon,
    required this.route,
  });
}

class _ResolvedNavItem {
  final String label;
  final IconData icon;
  final String route;

  const _ResolvedNavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

class _SideRail extends ConsumerStatefulWidget {
  final List<_ResolvedNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SideRail({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  ConsumerState<_SideRail> createState() =>
      _SideRailState();
}

class _SideRailState extends ConsumerState<_SideRail> {
  late final List<FocusNode> _railFocusNodes =
      List.generate(
        widget.items.length,
        (i) => FocusNode(debugLabel: 'rail-$i'),
      );

  @override
  void initState() {
    super.initState();

    if (PlatformInfo.isTv) {
      _grabInitialFocus();
    }
  }

  void _grabInitialFocus([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_railFocusNodes[widget.currentIndex].context != null) {
        _railFocusNodes[widget.currentIndex].requestFocus();
      } else if (attempt < 15) {
        _grabInitialFocus(attempt + 1);
      }
    });
  }

  @override
  void dispose() {
    for (final node in _railFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final currentIndex = widget.currentIndex;
    final onTap = widget.onTap;

    final topIndexes = <int>[];
    final bottomIndexes = <int>[];

    for (var i = 0; i < items.length; i++) {
      if (AppShell._bottomRoutes.contains(items[i].route)) {
        bottomIndexes.add(i);
      } else {
        topIndexes.add(i);
      }
    }

    return Container(
      width: 190,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          right: BorderSide(
            color: AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                Platform.isMacOS ? 56 : 20,
                20,
                24,
              ),
              child: const AppBrand(size: 22),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    for (final i in topIndexes) ...[
                      _RailEntry(
                        item: items[i],
                        selected: i == currentIndex,
                        focusNode: _railFocusNodes[i],
                        onTap: () => onTap(i),
                      ),
                      if (AppShell._dividersAfter
                          .contains(items[i].route))
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Divider(
                            height: 1,
                            color: AppColors.divider,
                            thickness: 0.5,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20, 0, 20, 8,
              ),
              child: kDebugMode
                  ? _DemoToggleHotspot()
                  : Consumer(
                      builder: (context, ref, _) {
                        final info =
                            ref.watch(appInfoProvider).value;

                        if (info == null) {
                          return const SizedBox.shrink();
                        }

                        return Text(
                          'v${info.version}',
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: 0.35,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        );
                      },
                    ),
            ),
            if (bottomIndexes.isNotEmpty)
              const Divider(
                height: 1,
                color: AppColors.divider,
                indent: 16,
                endIndent: 16,
              ),
            for (final i in bottomIndexes)
              _RailEntry(
                item: items[i],
                selected: i == currentIndex,
                focusNode: _railFocusNodes[i],
                onTap: () => onTap(i),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RailEntry extends StatefulWidget {
  final _ResolvedNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const _RailEntry({
    required this.item,
    required this.selected,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<_RailEntry> createState() =>
      _RailEntryState();
}

class _RailEntryState extends State<_RailEntry> {
  bool _hover = false;
  bool _focus = false;

  bool get _highlighted => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.selected
        ? AppColors.accent
        : AppColors.textPrimary;

    final bgColor = widget.selected
        ? AppColors.accent.withValues(alpha: 0.08)
        : (_highlighted
            ? AppColors.accent.withValues(alpha: 0.18)
            : Colors.transparent);

    final showBar = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (v) =>
            setState(() => _focus = v),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }

          final k = event.logicalKey;

          if (k == LogicalKeyboardKey.select ||
              k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }

          if (k == LogicalKeyboardKey.arrowRight) {
            node.focusInDirection(
              TraversalDirection.right,
            );
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            color: bgColor,
            child: Row(
              children: [
                AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 200),
                  width: showBar ? 3 : 0,
                  height: 22,
                  margin: EdgeInsets.only(
                    right: showBar ? 11 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  widget.item.icon,
                  color: activeColor,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 14,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
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

class _DemoToggleHotspot extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DemoToggleHotspot> createState() =>
      _DemoToggleHotspotState();
}

class _DemoToggleHotspotState
    extends ConsumerState<_DemoToggleHotspot> {
  int _taps = 0;

  DateTime _firstTap =
      DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = DateTime.now();

    if (now.difference(_firstTap).inSeconds > 3) {
      _taps = 0;
      _firstTap = now;
    }

    _taps++;

    if (_taps >= 7) {
      _taps = 0;
      ref.read(demoModeProvider.notifier).toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(appInfoProvider).value;
    final demoActive = ref.watch(isDemoActiveProvider);

    if (info == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Text(
        demoActive
            ? 'v${info.version} · DEMO'
            : 'v${info.version}',
        style: TextStyle(
          color: demoActive
              ? AppColors.accent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.35),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
