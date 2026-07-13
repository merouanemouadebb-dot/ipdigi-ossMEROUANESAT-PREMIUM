import 'dart:io';

import 'package:media_kit/media_kit.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';

class ScreenshotResult {
  final File file;
  const ScreenshotResult(this.file);
}

class ScreenshotService {
  final Player player;
  ScreenshotService(this.player);

  Future<Directory> ensureDirectory() async {
    // Try the real ~/Documents first (works once the sandbox is disabled);
    // fall back to the container's Documents folder so the call never fails.
    Directory? base;
    final home = Platform.environment['HOME'];
    if (home != null) {
      final candidate = Directory(p.join(home, 'Documents'));
      if (await candidate.exists()) base = candidate;
    }
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(base.path, AppConfig.I.storageSlug, 'screenshots'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _sanitize(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<ScreenshotResult?> capture({String? title}) async {
    try {
      final bytes = await player.screenshot(format: 'image/jpeg');
      if (bytes == null || bytes.isEmpty) return null;
      final dir = await ensureDirectory();
      final ts = DateTime.now();
      final stamp =
          '${ts.year.toString().padLeft(4, '0')}-'
          '${ts.month.toString().padLeft(2, '0')}-'
          '${ts.day.toString().padLeft(2, '0')}_'
          '${ts.hour.toString().padLeft(2, '0')}-'
          '${ts.minute.toString().padLeft(2, '0')}-'
          '${ts.second.toString().padLeft(2, '0')}';
      final prefix = title == null || title.isEmpty
          ? AppConfig.I.storageSlug
          : _sanitize(title);
      final fileName = '${prefix}_$stamp.jpg';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      return ScreenshotResult(file);
    } catch (_) {
      return null;
    }
  }
}
