import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// One-shot rename for users coming from the pre-rebrand build. The app
/// used to store everything (SQLite, settings.json, user-edited locales,
/// screenshots) under `iplife/` slugged folders; the rebrand pushed those
/// to `ipdigi/`, which silently looks empty on first launch. Rename the
/// legacy folders into place before any provider tries to read from them.
class LegacyStorageMigration {
  static const _legacySlug = 'iplife';

  static Future<void> run() async {
    final slug = AppConfig.I.storageSlug;
    if (slug == _legacySlug) return;
    await _maybeRename(await getApplicationSupportDirectory(), slug);
    try {
      await _maybeRename(await getApplicationDocumentsDirectory(), slug);
    } catch (_) {
      // Documents folder is best-effort - sandbox setups can deny it on
      // first launch. Skip silently rather than block startup.
    }
  }

  static Future<void> _maybeRename(Directory base, String slug) async {
    final legacy = Directory(p.join(base.path, _legacySlug));
    final current = Directory(p.join(base.path, slug));
    if (!await legacy.exists()) return;
    if (await current.exists()) return; // already migrated / fresh install
    try {
      await legacy.rename(current.path);
      // ignore: avoid_print
      print(
          '[${AppConfig.I.appName}] migrated legacy storage ${legacy.path} -> ${current.path}');
    } catch (e) {
      // Cross-volume rename or permission glitch - fall back to a copy.
      try {
        await _copyDir(legacy, current);
        // ignore: avoid_print
        print(
            '[${AppConfig.I.appName}] copied legacy storage ${legacy.path} -> ${current.path}');
      } catch (e2) {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] legacy migration FAILED: $e2');
      }
    }
  }

  static Future<void> _copyDir(Directory src, Directory dst) async {
    if (!await dst.exists()) await dst.create(recursive: true);
    await for (final entry in src.list(recursive: false)) {
      final newPath = p.join(dst.path, p.basename(entry.path));
      if (entry is File) {
        await entry.copy(newPath);
      } else if (entry is Directory) {
        await _copyDir(entry, Directory(newPath));
      }
    }
  }
}
