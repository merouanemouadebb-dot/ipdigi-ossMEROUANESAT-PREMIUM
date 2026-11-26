import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Runtime-loaded application identity. Reads `assets/config.json` once at
/// startup so the brand name (and everything derived from it - window title,
/// storage paths, log prefix) can be changed in a single place without
/// touching widget code.
///
/// Usage: call [AppConfig.load] before [runApp], then read [AppConfig.I]
/// anywhere. If the asset is missing or malformed, callers fall back to
/// the hardcoded default ("IPDigi") so the app never fails to start.
class AppConfig {
  /// Brand name shown to the user (window title, wordmark, welcome text).
  final String appName;

  /// Path-safe form of [appName] (lowercase, ASCII, underscores only).
  /// Used for the SQLite filename and the on-disk `~/Documents/<slug>/`
  /// folder that hosts locales and screenshots.
  final String storageSlug;

  AppConfig._(this.appName, this.storageSlug);

  factory AppConfig._fromName(String name) {
    final clean = name.trim().isEmpty ? _fallbackName : name.trim();
    return AppConfig._(clean, _slugify('IPdigi'));
  }

  static const _fallbackName = 'MEROUANESAT PREMIUM';
  static AppConfig _instance = AppConfig._fromName(_fallbackName);

  /// Current configuration. Safe to read before [load] completes - returns
  /// the fallback identity until the asset is parsed.
  static AppConfig get I => _instance;

  /// Loads `assets/config.json`. Errors (missing file, invalid JSON, empty
  /// `appName`) silently fall back to the default so startup never aborts.
  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      final data = jsonDecode(raw);
      if (data is Map && data['appName'] is String) {
        _instance = AppConfig._fromName(data['appName'] as String);
        return;
      }
    } catch (_) {}
    _instance = AppConfig._fromName(_fallbackName);
  }

  static String _slugify(String s) {
    final lower = s.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final trimmed = replaced.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? 'ipdigi' : trimmed;
  }
}
