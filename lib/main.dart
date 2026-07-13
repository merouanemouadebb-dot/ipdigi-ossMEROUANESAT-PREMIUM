import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/platform_info.dart';
import 'core/l10n/i18n.dart';
import 'core/prefs/legacy_migration.dart';
import 'core/trailer/trailer_server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bump Flutter's image cache modestly above the default 100 MB / 1000
  // ceiling so a few screens worth of posters survive scroll, without
  // ballooning memory: 3000 entries / 300 MB covers a comfortable
  // scroll window for a 10k+ catalog and lets LRU evict the rest.
  PaintingBinding.instance.imageCache.maximumSize = 3000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 300 * 1024 * 1024;
  // Resolve the brand identity before anything else so the window title,
  // log prefix, and storage paths all see the same name.
  await AppConfig.load();
  final brand = AppConfig.I.appName;

  // Catch every unhandled framework + zone error and dump it to stdout so
  // the user (and `tail /tmp/<slug>.log`) can see what really failed
  // instead of a silent black screen.
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    // ignore: avoid_print
    print('[$brand] FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('[$brand] PlatformDispatcher error: $error\n$stack');
    return true;
  };

  // The default Flutter ErrorWidget draws an empty gray/black box in
  // release mode - if a widget throws an exception during build the user
  // sees a "black screen" and cannot tell why. With a custom builder we
  // show a visible red box + error message + stack trace.
  ErrorWidget.builder = (details) {
    final msg = details.exceptionAsString();
    final stack = details.stack?.toString() ?? '';
    return Material(
      color: const Color(0xFF2A0A0A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'Widget hatası',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 12),
                if (stack.isNotEmpty)
                  SelectableText(
                    stack,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  MediaKit.ensureInitialized();

  // Boot the localhost server that wraps YouTube's iframe - without it
  // the trailer WebView is loading off `data:`, which YouTube refuses
  // with error 152.
  try {
    await TrailerServer.instance.start();
  } catch (e, st) {
    // ignore: avoid_print
    print('[$brand] trailer server start failed: $e\n$st');
  }

  // One-shot rebrand migration: rename legacy `iplife/` storage folders
  // into the new `ipdigi/` slug before any provider opens them. Without
  // this the TMDB key, saved locale, watch history, and edited locales
  // appear lost on the first post-rename launch.
  try {
    await LegacyStorageMigration.run();
  } catch (e, st) {
    // ignore: avoid_print
    print('[$brand] legacy migration failed: $e\n$st');
  }

  // ensureUserDir touches the filesystem and is allowed to fail (e.g. the
  // very first launch under a freshly created sandbox). Failing here used
  // to abort main() and produce a black window.
  try {
    await Translations.ensureUserDir();
  } catch (e, st) {
    // ignore: avoid_print
    print('[$brand] ensureUserDir failed: $e\n$st');
  }

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    try {
      await windowManager.ensureInitialized();
      final opts = WindowOptions(
        size: const Size(1920, 1080),
        minimumSize: const Size(1024, 720),
        center: true,
        backgroundColor: const Color(0xFF0B0B0F),
        title: brand,
        titleBarStyle: TitleBarStyle.hidden,
      );
      await windowManager.waitUntilReadyToShow(opts, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('[$brand] window_manager init failed: $e\n$st');
    }
  }
  // Orientation lock (phone): navigation is portrait, landscape only in
  // the player. The iOS Info.plist allows landscape (needed for the
  // player), so we restrict to portrait at runtime. This is the most
  // reliable place - before the UI, detecting a phone from the screen's
  // physical size. The player's initState allows all, and reverts to
  // portrait on exit. Android TV (leanback) detection - from the native
  // uiMode. On TV the orientation must stay locked to landscape; the
  // portrait lock is not applied on TV.
  await PlatformInfo.init();
  if ((Platform.isIOS || Platform.isAndroid) && !PlatformInfo.isTv) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    if (logical.shortestSide < 600) {
      await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );
    }
  }
  runApp(
    const ProviderScope(
      child: IplifeApp(),
    ),
  );
}
