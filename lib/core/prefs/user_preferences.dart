import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Single JSON-backed bag for the small set of user preferences IPDigi
/// persists outside of the SQLite catalog - locale code, TMDB API key,
/// future additions like theme override. Lives at
/// `<ApplicationSupport>/<appslug>/settings.json` and is the canonical
/// store the rest of the app talks to (replaces the older one-file-per-key
/// approach as well as `flutter_secure_storage`, which silently failed on
/// unsigned macOS builds with `errSecMissingEntitlement`).
class UserPreferences {
  static const _filename = 'settings.json';

  Map<String, dynamic>? _cache;
  Completer<void>? _loading;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(p.join(dir.path, AppConfig.I.storageSlug));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return File(p.join(folder.path, _filename));
  }

  Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    // De-duplicate concurrent loads so multiple early readers share one IO.
    if (_loading != null) {
      await _loading!.future;
      return _cache!;
    }
    _loading = Completer<void>();
    try {
      final f = await _file();
      if (!await f.exists()) {
        _cache = <String, dynamic>{};
      } else {
        try {
          final raw = await f.readAsString();
          final decoded = jsonDecode(raw);
          _cache = decoded is Map<String, dynamic>
              ? decoded
              : <String, dynamic>{};
        } catch (e, st) {
          // Corrupt file (partial write, manual edit) - don't lose all
          // future writes, just start over with an empty bag.
          // ignore: avoid_print
          print('[${AppConfig.I.appName}] prefs.parse FAILED: $e\n$st');
          _cache = <String, dynamic>{};
        }
      }
      _loading!.complete();
    } catch (e, st) {
      _cache = <String, dynamic>{};
      _loading!.completeError(e, st);
    }
    _loading = null;
    return _cache!;
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(_cache ?? <String, dynamic>{}),
          flush: true);
    } catch (e, st) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] prefs.write FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<String?> getString(String key) async {
    final m = await _load();
    final v = m[key];
    return v is String ? v : null;
  }

  Future<void> setString(String key, String? value) async {
    final m = await _load();
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      m.remove(key);
    } else {
      m[key] = trimmed;
    }
    await _persist();
  }

  /// Wipe a single key. Equivalent to `setString(key, null)` but reads
  /// nicer at call sites that explicitly want to clear something.
  Future<void> remove(String key) => setString(key, null);
}

/// Singleton across the app. The cache lives on the [UserPreferences]
/// instance so we don't re-parse `settings.json` on every read.
final userPreferencesProvider =
    Provider<UserPreferences>((ref) => UserPreferences());

/// Well-known keys used inside settings.json. Centralising them keeps the
/// JSON schema discoverable from a single file.
class PrefKeys {
  static const locale = 'locale';
  static const tmdbApiKey = 'tmdb_api_key';
  static const playbackQuality = 'playback_quality';

  /// Id of the source selected on the browse pages (Home, Movies, Series,
  /// Live TV). Null/empty = "All Sources" (everything combined). The last
  /// selection persists; see selected_source_provider.dart.
  static const selectedSourceId = 'selected_source_id';

  const PrefKeys._();
}
