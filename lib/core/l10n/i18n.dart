import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../prefs/user_preferences.dart';

/// Two-tier translator. Looks up keys in flattened dot-notated maps loaded
/// from `assets/locales/<code>.json`, optionally overridden by user-editable
/// JSON files under `~/Documents/<appSlug>/locales/<code>.json`. Missing keys
/// fall back to the English bundle and finally to the key itself, so the UI
/// never breaks if a translation is unfinished.
class Translations {
  final String code;
  final Map<String, String> _map;
  final Translations? _fallback;
  const Translations._(this.code, this._map, this._fallback);

  String t(String key, [Map<String, String>? args]) {
    var s = _map[key] ?? _fallback?._map[key] ?? key;
    if (args != null) {
      args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    }
    return s;
  }

  static const _defaultLocale = 'en';

  static Future<Translations> load(String code) async {
    final base = await _loadFlat(code);
    Translations? fallback;
    if (code != _defaultLocale) {
      try {
        final fb = await _loadFlat(_defaultLocale);
        fallback = Translations._(_defaultLocale, fb, null);
      } catch (_) {}
    }
    return Translations._(code, base, fallback);
  }

  static Future<Map<String, String>> _loadFlat(String code) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(await rootBundle.loadString('assets/locales/$code.json'))
          as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final override = File(p.join(docs.path, AppConfig.I.storageSlug, 'locales', '$code.json'));
      if (await override.exists()) {
        final overrideData = jsonDecode(await override.readAsString())
            as Map<String, dynamic>;
        _deepMerge(data, overrideData);
      }
    } catch (_) {}
    final flat = <String, String>{};
    _flatten(data, '', flat);
    return flat;
  }

  static void _flatten(Map<String, dynamic> m, String prefix, Map<String, String> out) {
    m.forEach((k, v) {
      final key = prefix.isEmpty ? k : '$prefix.$k';
      if (v is Map<String, dynamic>) {
        _flatten(v, key, out);
      } else if (v != null) {
        out[key] = v.toString();
      }
    });
  }

  static void _deepMerge(Map<String, dynamic> base, Map<String, dynamic> add) {
    add.forEach((k, v) {
      if (v is Map<String, dynamic> && base[k] is Map<String, dynamic>) {
        _deepMerge(base[k] as Map<String, dynamic>, v);
      } else {
        base[k] = v;
      }
    });
  }

  /// Bundled locale codes. Users can drop additional JSON files in
  /// `~/Documents/<appSlug>/locales/` and pass their code via [LocaleNotifier.setLocale].
  static List<String> bundled() => const [
        'en', 'tr', 'de', 'es', 'fr', 'pt', 'it', 'nl', 'ar',
      ];

  /// Lists every locale available - bundled assets plus any extra JSON file
  /// the user has placed in their Documents folder.
  static Future<List<String>> availableCodes() async {
    final codes = <String>{...bundled()};
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, AppConfig.I.storageSlug, 'locales'));
      if (await dir.exists()) {
        await for (final entry in dir.list()) {
          if (entry is File && entry.path.endsWith('.json')) {
            final name = p.basenameWithoutExtension(entry.path);
            if (name.isNotEmpty) codes.add(name);
          }
        }
      }
    } catch (_) {}
    return codes.toList()..sort();
  }

  /// Mirrors bundled locales into the user's Documents folder so power users
  /// can edit UI text. Copies are re-synced whenever the bundled translations
  /// change (detected via a content hash); otherwise a one-time first-run copy
  /// would shadow every future translation update shipped in an app release.
  /// Extra locale files the user added (codes not in [bundled]) are untouched.
  static Future<Directory> ensureUserDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final brand = AppConfig.I.appName;
    final dir = Directory(p.join(docs.path, AppConfig.I.storageSlug, 'locales'));
    if (!await dir.exists()) await dir.create(recursive: true);

    // Read the bundled payload and hash it. We only overwrite the user copies
    // when the hash differs from the last sync, so manual edits survive between
    // app versions but a new release's translations always land.
    final payload = StringBuffer();
    final bundleContent = <String, String>{};
    for (final code in bundled()) {
      try {
        final content = await rootBundle.loadString('assets/locales/$code.json');
        bundleContent[code] = content;
        payload.write(content);
      } catch (_) {}
    }
    final stamp = File(p.join(dir.path, '.bundle_hash'));
    final bundleHash = _fnv1a(payload.toString()).toString();
    String? synced;
    try {
      if (await stamp.exists()) synced = (await stamp.readAsString()).trim();
    } catch (_) {}
    final resync = synced != bundleHash;

    for (final entry in bundleContent.entries) {
      final dest = File(p.join(dir.path, '${entry.key}.json'));
      if (resync || !await dest.exists()) {
        try {
          await dest.writeAsString(entry.value);
        } catch (_) {}
      }
    }
    if (resync) {
      try {
        await stamp.writeAsString(bundleHash);
      } catch (_) {}
    }

    final readme = File(p.join(dir.path, 'README.txt'));
    if (!await readme.exists()) {
      await readme.writeAsString(
        '$brand dil dosyaları / $brand locale files\n\n'
        'Bu klasördeki <kod>.json dosyalarını düzenleyerek arayüz metinlerini\n'
        'özelleştirebilirsin. Yeni bir dil eklemek için bir mevcut dosyayı\n'
        'kopyala (örn. tr.json -> de.json) ve değerleri çevir. Uygulamayı\n'
        'yeniden başlattıktan sonra Ayarlar -> Dil menüsünde görünür.\n\n'
        'Edit any <code>.json file here to override UI text. To add a new\n'
        'language, copy an existing file (e.g. tr.json -> de.json), translate\n'
        'the values, and pick it from Settings -> Language after a restart.\n'
        '\n'
        'NOT: Bundled diller (en, tr, de, ...) bir uygulama güncellemesinde\n'
        'yeni çeviriler geldiğinde sıfırlanır. / Bundled languages are reset\n'
        'when an app update ships new translations.\n',
      );
    }
    return dir;
  }

  /// Deterministic 32-bit FNV-1a hash. Stable across runs (unlike
  /// String.hashCode), so the locale re-sync fires only on real changes.
  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}

class LocaleState {
  final String code;
  final Translations translations;
  final List<String> available;
  const LocaleState({
    required this.code,
    required this.translations,
    required this.available,
  });

  String t(String key, [Map<String, String>? args]) => translations.t(key, args);
}

class LocaleNotifier extends AsyncNotifier<LocaleState> {
  @override
  Future<LocaleState> build() async {
    await Translations.ensureUserDir();
    final prefs = ref.read(userPreferencesProvider);
    final saved = await prefs.getString(PrefKeys.locale);
    final available = await Translations.availableCodes();
    final code = saved ?? _systemDefault(available);
    final t = await Translations.load(code);
    return LocaleState(code: code, translations: t, available: available);
  }

  Future<void> setLocale(String code) async {
    // Update the in-memory state first so the UI flips immediately. Persist
    // afterwards - if the disk write fails for any reason (sandbox quirk,
    // read-only volume) the user still sees the language change for the
    // current session instead of nothing happening at all.
    final available = await Translations.availableCodes();
    final t = await Translations.load(code);
    state = AsyncData(
        LocaleState(code: code, translations: t, available: available));
    await ref.read(userPreferencesProvider).setString(PrefKeys.locale, code);
  }

  Future<void> refreshFromDisk() async {
    final cur = state.value?.code ?? 'en';
    final available = await Translations.availableCodes();
    final t = await Translations.load(cur);
    state = AsyncData(LocaleState(code: cur, translations: t, available: available));
  }

  String _systemDefault(List<String> available) {
    // English is the canonical source; other languages are translated from
    // it. We do not auto-detect the OS locale - the user must opt-in via
    // Settings → Language.
    if (available.contains('en')) return 'en';
    return available.isNotEmpty ? available.first : 'en';
  }
}

final localeProvider =
    AsyncNotifierProvider<LocaleNotifier, LocaleState>(LocaleNotifier.new);

/// Convenience accessor that always returns a Translations object even when
/// the async state is still warming up, so widgets can call `ref.tr(...)`
/// without juggling AsyncValue everywhere.
final translationsProvider = Provider<Translations>((ref) {
  final state = ref.watch(localeProvider).value;
  return state?.translations ?? const Translations._('en', {}, null);
});

extension TrRef on WidgetRef {
  String tr(String key, [Map<String, String>? args]) =>
      watch(translationsProvider).t(key, args);
}
