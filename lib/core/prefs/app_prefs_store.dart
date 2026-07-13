import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Single JSON file (`settings.json`) for every user preference we keep on
/// disk. Each provider gets a top-level key inside the map and reads/writes
/// the sub-object underneath. Writes are serialized so two providers
/// updating different sections at the same instant don't clobber each
/// other's last-write-wins JSON.
class AppPrefsStore {
  static const _fileName = 'settings.json';

  Map<String, dynamic>? _cache;
  Future<void>? _pendingWrite;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final f = await _file();
      if (!await f.exists()) {
        _cache = <String, dynamic>{};
        return _cache!;
      }
      final raw = await f.readAsString();
      if (raw.isEmpty) {
        _cache = <String, dynamic>{};
        return _cache!;
      }
      final decoded = jsonDecode(raw);
      _cache = (decoded is Map<String, dynamic>) ? decoded : <String, dynamic>{};
      return _cache!;
    } catch (_) {
      _cache = <String, dynamic>{};
      return _cache!;
    }
  }

  Future<Map<String, dynamic>?> readSection(String key) async {
    final all = await _load();
    final v = all[key];
    return v is Map<String, dynamic> ? Map<String, dynamic>.from(v) : null;
  }

  Future<void> writeSection(String key, Map<String, dynamic> data) async {
    final all = await _load();
    all[key] = data;
    _cache = all;
    await (_pendingWrite = _flush());
  }

  Future<void> deleteKey(String key, String field) async {
    final all = await _load();
    final section = all[key];
    if (section is Map<String, dynamic>) {
      section.remove(field);
      if (section.isEmpty) {
        all.remove(key);
      }
      _cache = all;
      await (_pendingWrite = _flush());
    }
  }

  Future<void> _flush() async {
    final prev = _pendingWrite;
    if (prev != null) {
      try { await prev; } catch (_) {}
    }
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(_cache ?? const {}));
    } catch (_) {/* disk write failed - keep in-memory state */}
  }
}

final appPrefsStoreProvider = Provider<AppPrefsStore>((ref) => AppPrefsStore());
