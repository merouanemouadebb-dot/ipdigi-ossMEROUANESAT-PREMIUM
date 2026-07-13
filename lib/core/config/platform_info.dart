import 'dart:io';

import 'package:flutter/services.dart';

/// Runtime platform info. Its sole responsibility right now: is the
/// device an Android TV (leanback)? It reads this once from the
/// MethodChannel in the native MainActivity and keeps it in a
/// synchronously accessible flag.
///
/// Why it's needed: the Flutter side can't tell a TV from a phone by
/// screen size alone (when a TV starts in portrait the logical aspect
/// ratio looks phone-like, <600). The native uiMode = TELEVISION check
/// is the only reliable way.
class PlatformInfo {
  PlatformInfo._();

  static const _channel = MethodChannel('com.example.ipdigi/platform');

  /// Is the device an Android TV? Always false before [init] is called.
  static bool isTv = false;

  /// Called once at app startup (before runApp). Only queries native on
  /// Android; a no-op on other platforms.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      isTv = await _channel.invokeMethod<bool>('isTv') ?? false;
      // ignore: avoid_print
      print('[ipdigi] PlatformInfo.isTv=$isTv');
    } catch (e) {
      isTv = false;
      // ignore: avoid_print
      print('[ipdigi] PlatformInfo.init error: $e');
    }
  }
}
