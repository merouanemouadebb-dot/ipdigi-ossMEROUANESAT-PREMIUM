import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/user_preferences.dart';
import 'sources_provider.dart';

/// The global "selected source" in effect on the browse pages (Home,
/// Movies, Series, Live TV). The value is the source's id; `null` = "All
/// Sources" (everything shown merged). The selection is persistent
/// ([PrefKeys.selectedSourceId]) and the last choice returns when the app
/// is reopened.
///
/// If the stored id no longer exists (source deleted) it silently falls
/// back to "All Sources"; otherwise we would stay bound to the deleted
/// source and show an empty list. Because it watches [sourcesProvider], it
/// re-validates after a source is added/removed.
class SelectedSourceNotifier extends AsyncNotifier<String?> {
  /// The user's last in-session choice. [build] runs again whenever the
  /// source list changes ([sourcesProvider] re-emits on every add/remove/
  /// refresh); if we re-read prefs at that moment we would undo the user's
  /// choice (a race) and flash to "All" when a source is added. These fields
  /// preserve the choice across rebuilds (the notifier instance stays the
  /// same across rebuilds). If the provider is fully disposed they reset and
  /// [build] reads the persistent value back from prefs.
  String? _picked;
  bool _hasPicked = false;

  @override
  Future<String?> build() async {
    final sources = await ref.watch(sourcesProvider.future);
    final String? candidate;
    if (_hasPicked) {
      candidate = _picked;
    } else {
      final prefs = ref.read(userPreferencesProvider);
      candidate = await prefs.getString(PrefKeys.selectedSourceId);
    }
    if (candidate == null || candidate.isEmpty) return null; // All Sources
    final exists = sources.any((s) => s.id == candidate);
    return exists ? candidate : null;
  }

  /// `null` => All Sources. Applied immediately and persisted.
  Future<void> select(String? sourceId) async {
    _picked = sourceId;
    _hasPicked = true;
    state = AsyncData(sourceId);
    final prefs = ref.read(userPreferencesProvider);
    await prefs.setString(PrefKeys.selectedSourceId, sourceId);
  }
}

final selectedSourceProvider =
    AsyncNotifierProvider<SelectedSourceNotifier, String?>(
  SelectedSourceNotifier.new,
);
