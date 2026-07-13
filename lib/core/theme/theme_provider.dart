import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_theme.dart';

/// True when dark theme is active. Stored in secure storage so the user's
/// choice survives restarts.
class ThemeNotifier extends AsyncNotifier<bool> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app.theme';

  @override
  Future<bool> build() async {
    final saved = await _storage.read(key: _key);
    final isDark = saved != 'light';
    AppColors.setDark(isDark);
    return isDark;
  }

  Future<void> setDark(bool value) async {
    await _storage.write(key: _key, value: value ? 'dark' : 'light');
    AppColors.setDark(value);
    state = AsyncData(value);
  }
}

final themeProvider =
    AsyncNotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);
