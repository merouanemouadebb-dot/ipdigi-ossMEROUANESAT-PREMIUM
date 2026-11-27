import 'premium_intro.dart';

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
  ConsumerState<IplifeApp> createState() =>
      _IplifeAppState();
}

class _IplifeAppState extends ConsumerState<IplifeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isTablet =
            MediaQuery.of(context).size.shortestSide >= 600;

        OrientationLock.browsing(
          isTablet: isTablet || PlatformInfo.isTv,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await ShutdownCoordinator.instance.runAll();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final isDark = ref.watch(themeProvider).value ?? true;

    ref.watch(sourceAutoRefreshProvider);
    ref.watch(epgProvider);
    ref.watch(epgAutoRefreshProvider);

    AppColors.setDark(isDark);

    return MaterialApp.router(
      title: AppConfig.I.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(isDark),
      routerConfig: router,
      builder: (context, child) {
        return PremiumIntro(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
