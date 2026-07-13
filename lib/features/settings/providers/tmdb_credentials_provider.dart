import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/user_preferences.dart';

/// The current TMDB v3 API key, loaded from the shared settings.json bag.
/// Empty when the user hasn't configured one yet - every consumer treats
/// that as "TMDB disabled" and falls back to source-supplied metadata.
class TmdbApiKeyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = ref.read(userPreferencesProvider);
    return (await prefs.getString(PrefKeys.tmdbApiKey)) ?? '';
  }

  Future<void> setKey(String apiKey) async {
    await ref
        .read(userPreferencesProvider)
        .setString(PrefKeys.tmdbApiKey, apiKey);
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    await ref.read(userPreferencesProvider).remove(PrefKeys.tmdbApiKey);
    ref.invalidateSelf();
  }
}

final tmdbApiKeyProvider = AsyncNotifierProvider<TmdbApiKeyNotifier, String>(
  TmdbApiKeyNotifier.new,
);
