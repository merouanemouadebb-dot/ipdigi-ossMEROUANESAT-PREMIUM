import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/platform_info.dart';
import 'core/utils/orientation_lock.dart';
import 'core/router/app_router.dart';
import 'core/shutdown/shutdown_coordinator.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/epg/providers/epg_provider.dart';
import 'features/sources/providers/sources_provider.dart';

class IplifeApp extends ConsumerStatefulWidget {
  const IplifeApp({super.key});

  @override
  ConsumerState<IplifeApp> createState() => _IplifeAppState();
}

class _IplifeAppState extends ConsumerState<IplifeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Orientation: portrait lock on phones, free on iPad (browsing).
    // Released when entering the player, restored here on exit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // On TV (PlatformInfo.isTv) orientation is left free; landscape is
        // fixed on the native side, so the portrait lock is not applied.
        final isTablet =
            MediaQuery.of(context).size.shortestSide >= 600;
        OrientationLock.browsing(isTablet: isTablet || PlatformInfo.isTv);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Intercepts macOS `NSApplication.terminate:` (and the Cmd+Q / window-X
  /// paths that route through it) so any active mpv instance can finish
  /// disposing before AppKit tears down the FlutterEngine. Without this,
  /// mpv's core thread keeps running into freed wakeup callbacks and the
  /// process exits with EXC_BAD_ACCESS.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await ShutdownCoordinator.instance.runAll();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final isDark = ref.watch(themeProvider).value ?? true;
    // Activate the background auto-refresh: one pull at startup once sources
    // load, then once per hour for the lifetime of the app.
    ref.watch(sourceAutoRefreshProvider);
    // EPG companion - pulls XMLTV for every Xtream source and any M3U
    // source with an epgUrl set, then refreshes every 6 hours so the
    // "now playing" line on channel tiles stays current.
    ref.watch(epgProvider);
    ref.watch(epgAutoRefreshProvider);
    // Keep AppColors in sync before MaterialApp rebuilds - getters depend on
    // the static flag, so colours flip across the entire widget tree.
    AppColors.setDark(isDark);
    return MaterialApp.router(
      title: AppConfig.I.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(isDark),
      routerConfig: router,
    );
  }
}
