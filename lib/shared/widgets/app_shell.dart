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
import 'app_brand.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  /// On Windows the native title bar is hidden (`TitleBarStyle.hidden`) and
  /// on desktop there is no system top inset (`MediaQuery.padding.top == 0`).
  /// So the `AppBar`/`SliverAppBar` toolbar sticks to the very top edge of
  /// the window; when the window frame/maximize overflow clipped that strip,
  /// the back button and the search/action buttons (e.g. on the movie detail
  /// page) became invisible. On macOS the traffic-light region leaves a
  /// natural gap, so the problem shows up only on Windows. By injecting this
  /// much synthetic top inset into the content area we push the `primary`
  /// AppBar/SliverAppBar toolbars down into the visible region; no gap
  /// appears because the full-bleed flexibleSpace (hero) background keeps
  /// filling the top.
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

  /// Items that pin to the bottom of the side rail instead of flowing
  /// inline with the main navigation. Profile + Settings sit here
  /// Spotify/Netflix-style - shortcuts related to the user's account are
  /// visually separated from the content shortcuts. Order: Settings first,
  /// Profile at the bottom (Apple HIG: profile always last).
  static const _bottomRoutes = {'/settings', '/profile'};

  /// In the top nav list, draw a visual divider RIGHT BELOW this route.
  /// Divider after "Series" → above: main content (Home, Live, Movies,
  /// Series) - below: the personal section (Search, Favorites, My Lists,
  /// History, etc.). The hierarchy becomes clearer.
  static const _dividersAfter = {'/series'};

  /// The mobile bottom-nav is limited to 5 slots (Material 3 recommendation);
  /// the remaining entries are shown in the "More" sheet. Cramming 9 entries
  /// into the bottom bar made the labels unreadable.
  static const _mobilePrimaryRoutes = <String>[
    '/home',
    '/live',
    '/movies',
    '/series',
    '/search',
  ];

  /// Pull detail pages under their owning primary tab - `/movie/:id` shows
  /// under "Movies", `/series/:id` under "Series". Otherwise the bottom-nav
  /// highlights "More" on every detail route, and the user loses track of
  /// where they came from.
  static const _detailRouteToPrimary = <String, String>{
    '/movie': '/movies',
    '/person': '/movies',
    '/tag': '/movies',
  };

  int _currentIndex(String location) {
    // Pull detail routes under their owning primary tab (e.g. `/movie/...`
    // → "Movies"); otherwise the side-rail highlighted the wrong entry
    // (like "Home") on every detail page.
    final canonical = _primaryRouteFor(location) ?? location;
    for (int i = 0; i < _items.length; i++) {
      final route = _items[i].route;
      if (canonical == route || canonical.startsWith('$route/')) return i;
    }
    return 0;
  }

  /// Reduces the location to a primary route for the bottom-nav highlight;
  /// returns null if there is no match (the caller highlights "More").
  String? _primaryRouteFor(String location) {
    for (final r in _mobilePrimaryRoutes) {
      if (location == r || location.startsWith('$r/')) return r;
    }
    for (final entry in _detailRouteToPrimary.entries) {
      if (location.startsWith('${entry.key}/')) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _currentIndex(location);
    // TV always uses the wide layout (SideRail); on a remote-navigated TV
    // interface a side rail fits better than a bottom-nav.
    final isWide = PlatformInfo.isTv || MediaQuery.sizeOf(context).width >= 720;
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
        : mobilePrimary.indexWhere((e) => e.route == primaryMatch);
    if (mobileIndex < 0) mobileIndex = mobilePrimary.length;

    // Inject the Windows-specific top inset into the content area (except
    // the side rail); see [_desktopTopInset]. Only `child` is wrapped - the
    // side rail already uses its own 56px top inset.
    Widget content = child;
    if (!kIsWeb && Platform.isWindows) {
      final mq = MediaQuery.of(context);
      content = MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(top: mq.padding.top + _desktopTopInset),
          viewPadding: mq.viewPadding.copyWith(
            top: mq.viewPadding.top + _desktopTopInset,
          ),
        ),
        child: child,
      );
    }

    return _BackHandler(
      child: Scaffold(
        // TV: the side menu and content are in different FocusScopes
        // (ShellRoute's inner Navigator). Placing them under a single
        // traversal group makes D-pad LEFT/RIGHT movement deterministic.
        body: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Row(
            children: [
              if (isWide)
                _SideRail(
                  items: entries,
                  currentIndex: index,
                  onTap: (i) => context.go(entries[i].route),
                ),
              // SafeArea is not applied GLOBALLY here - pages with an AppBar
              // (Settings, Profile) already handle their own inset; wrapping
              // globally left extra space above the AppBar. Pages with their
              // own custom header (Live TV, Home) use their own SafeArea
              // instead.
              Expanded(child: content),
            ],
          ),
        ),
        bottomNavigationBar: isWide
            ? null
            : BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: mobileIndex,
                onTap: (i) {
                  if (i < mobilePrimary.length) {
                    context.go(mobilePrimary[i].route);
                  } else {
                    _showMobileMore(context, mobileOverflow, ref);
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final entry in items)
                ListTile(
                  leading: Icon(entry.icon, color: AppColors.textPrimary),
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

/// Handles the Android (and especially Android TV) back button app-wide.
/// Previously, pressing back at a tab root (e.g. /movies) closed the Android
/// app outright because there was nothing to pop on the GoRouter ShellRoute
/// stack. Here we intercept the back button: first close an open detail/player
/// page, otherwise return to Home, and at the Home root confirm exit with a double-press.
class _BackHandler extends ConsumerStatefulWidget {
  final Widget child;
  const _BackHandler({required this.child});

  @override
  ConsumerState<_BackHandler> createState() => _BackHandlerState();
}

class _BackHandlerState extends ConsumerState<_BackHandler> {
  // "Press again to exit" window at the Home root.
  DateTime? _lastBackAt;

  void _handleBack() {
    final router = GoRouter.of(context);
    // 1) If an imperatively pushed page (like a detail/player) is open, close
    //    it first. (Tabs switch with context.go and create no stack depth;
    //    canPop returns true only for pushes.)
    if (router.canPop()) {
      router.pop();
      return;
    }
    // 2) We are at a tab root. If not Home, go back to Home (the expected
    //    back-button behavior on TV; previously the app just closed).
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc != '/home') {
      context.go('/home');
      return;
    }
    // 3) We are at the Home root: exit on double-press, show a hint on a single press.
    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
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
  ConsumerState<_SideRail> createState() => _SideRailState();
}

class _SideRailState extends ConsumerState<_SideRail> {
  // Explicit focus on the selected nav entry. Used with an imperative
  // requestFocus so the D-pad has an initial focus at app startup on TV
  // (autofocus was unreliable due to ShellRoute scope isolation).
  final FocusNode _selectedFocus = FocusNode(debugLabel: 'rail-selected');

  @override
  void initState() {
    super.initState();
    if (PlatformInfo.isTv) _grabInitialFocus();
  }

  /// On the first frame the node may not be attached to the tree yet; retry
  /// for a few frames until it is attached (context != null), then focus the
  /// selected entry. This keeps primaryFocus from staying null and wakes the remote.
  void _grabInitialFocus([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedFocus.context != null) {
        _selectedFocus.requestFocus();
      } else if (attempt < 15) {
        _grabInitialFocus(attempt + 1);
      }
    });
  }

  @override
  void dispose() {
    _selectedFocus.dispose();
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
        border: Border(right: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top space above the logo: on macOS the window traffic-light
            // buttons cover the first ~36pt, so extra inset (56) is needed.
            // On TV / Android / other desktops there is no such overlap; 56pt
            // just looked like a big wasted gap there (especially glaring on
            // TV). Use a small inset outside of macOS.
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                Platform.isMacOS ? 56 : 20,
                20,
                24,
              ),
              child: const AppBrand(size: 22),
            ),
            // The top nav list is scrollable: on TV (1080p) 12 entries + the
            // bottom section did not fit vertically (overflow). The bottom
            // block (version, Pro card, Settings/Profile) stays fixed; the top
            // list scrolls and D-pad focus traversal triggers scrolling on its own.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final i in topIndexes) ...[
                      _RailEntry(
                        item: items[i],
                        selected: i == currentIndex,
                        focusNode: i == currentIndex ? _selectedFocus : null,
                        onTap: () => onTap(i),
                      ),
                      if (AppShell._dividersAfter.contains(items[i].route))
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
            // A faint version label right above the divider. In debug builds
            // 7 quick taps toggle demo mode (for the App Store screenshot
            // pipeline). In release builds this hotspot is completely hidden
            // and cannot be activated - only a plain version label is
            // shown.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: kDebugMode
                  ? _DemoToggleHotspot()
                  : Consumer(
                      builder: (context, ref, _) {
                        final info = ref.watch(appInfoProvider).value;
                        if (info == null) return const SizedBox.shrink();
                        return Text(
                          'v${info.version}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
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
  // Explicit focus node passed in from outside for the selected entry (for TV startup focus).
  final FocusNode? focusNode;
  const _RailEntry({
    required this.item,
    required this.selected,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<_RailEntry> createState() => _RailEntryState();
}

class _RailEntryState extends State<_RailEntry> {
  bool _hover = false;
  bool _focus = false;

  bool get _highlighted => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    // Accent text only on the SELECTED (open page) item; a focused-but-not-
    // selected item gets no accent text - otherwise two items (the open page
    // + the remote focus) looked "selected" at the same time.
    final activeColor = widget.selected
        ? AppColors.accent
        : AppColors.textPrimary;
    // A focused entry must stand out on a TV remote: even when not selected
    // it is highlighted on focus/hover with a distinct background (but NOT
    // the left accent bar - the bar stays exclusive to the open page).
    final bgColor = widget.selected
        ? AppColors.accent.withValues(alpha: 0.08)
        : (_highlighted
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.transparent);
    // Left accent bar ONLY on the selected (open page) item. Focus is told
    // apart by the background highlight; so there is a single "open page" mark.
    final showBar = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (v) => setState(() => _focus = v),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final k = event.logicalKey;
          // OK/SELECT/Enter → go to this entry.
          if (k == LogicalKeyboardKey.select ||
              k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          // RIGHT → bridge into the content area. Since ShellRoute's inner
          // Navigator is a separate scope, we trigger the directional move explicitly.
          if (k == LogicalKeyboardKey.arrowRight) {
            node.focusInDirection(TraversalDirection.right);
            return KeyEventResult.handled;
          }
          // UP/DOWN → leave to in-rail traversal.
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: bgColor,
            child: Row(
              children: [
                // Left accent bar - visible when selected or focused.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: showBar ? 3 : 0,
                  height: 22,
                  margin: EdgeInsets.only(right: showBar ? 11 : 0),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(widget.item.icon, color: activeColor, size: 22),
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

/// Hidden hotspot that toggles demo mode with 7 quick taps on the version
/// label. Completely invisible to the production user (only the version
/// text shows); a trigger for the screenshot pipeline.
class _DemoToggleHotspot extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DemoToggleHotspot> createState() => _DemoToggleHotspotState();
}

class _DemoToggleHotspotState extends ConsumerState<_DemoToggleHotspot> {
  int _taps = 0;
  DateTime _firstTap = DateTime.fromMillisecondsSinceEpoch(0);

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
    if (info == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Text(
        demoActive ? 'v${info.version} · DEMO' : 'v${info.version}',
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
