import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/app_prefs_store.dart';
import '../../sources/domain/media_item.dart';

// Adult markers seen across Turkish and international IPTV panels.
// `\badult` has no trailing word boundary so "Adults" / "For Adults"
// still match. Brand names (Brazzers, JAV, OnlyFans, Naughty…) cover
// the bulk of dedicated XXX panels that ship a polite category name
// like "Premium Series" instead of an "XXX" flag.
final _adultRegex = RegExp(
  r'(\bxxx\b'
  r'|\badult'
  r'|\berot'
  r'|\bporn'
  r'|\bhentai\b'
  r'|\bnsfw\b'
  r'|\b18\+|\+18\b'
  r'|\b21\+|\+21\b'
  r'|yeti(s|ş)kin'
  r'|\bjav\b'
  r'|brazzers'
  r'|onlyfans'
  r'|\bnaughty\b'
  r'|\+{3,})',
  caseSensitive: false,
);

bool isAdult(MediaItem item) {
  final name = item.name;
  final cat = item.categoryName ?? '';
  final match = _adultRegex.hasMatch(name) || _adultRegex.hasMatch(cat);
  return match;
}

class AdultFilterState {
  final bool showAdult;
  final bool hasPin;
  const AdultFilterState({required this.showAdult, required this.hasPin});

  AdultFilterState copyWith({bool? showAdult, bool? hasPin}) =>
      AdultFilterState(
        showAdult: showAdult ?? this.showAdult,
        hasPin: hasPin ?? this.hasPin,
      );
}

String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

class AdultFilterNotifier extends AsyncNotifier<AdultFilterState> {
  static const _section = 'adultFilter';

  String? _pinHashCache;

  @override
  Future<AdultFilterState> build() async {
    final data = await ref.read(appPrefsStoreProvider).readSection(_section);
    if (data == null) {
      _pinHashCache = null;
      return const AdultFilterState(showAdult: false, hasPin: false);
    }
    _pinHashCache = data['pinHash'] as String?;
    return AdultFilterState(
      showAdult: data['showAdult'] == true,
      hasPin: _pinHashCache != null && _pinHashCache!.isNotEmpty,
    );
  }

  Future<void> _save({
    required bool showAdult,
    required String? pinHash,
  }) async {
    _pinHashCache = pinHash;
    state = AsyncData(
      AdultFilterState(
        showAdult: showAdult,
        hasPin: pinHash != null && pinHash.isNotEmpty,
      ),
    );
    await ref.read(appPrefsStoreProvider).writeSection(_section, {
      'showAdult': showAdult,
      if (pinHash != null) 'pinHash': pinHash,
    });
  }

  Future<bool> verifyPin(String pin) async {
    final h = _pinHashCache;
    if (h == null || h.isEmpty) return false;
    return h == _hashPin(pin);
  }

  Future<void> setPin(String pin) async {
    final current =
        state.value ?? const AdultFilterState(showAdult: false, hasPin: false);
    await _save(showAdult: current.showAdult, pinHash: _hashPin(pin));
  }

  Future<void> clearPin() async {
    // Removing the PIN forces the filter back off - otherwise a user who
    // forgot their PIN could leave the catalogue exposed.
    await _save(showAdult: false, pinHash: null);
  }

  Future<void> setShowAdult(bool value) async {
    await _save(showAdult: value, pinHash: _pinHashCache);
  }
}

final adultFilterProvider =
    AsyncNotifierProvider<AdultFilterNotifier, AdultFilterState>(
      AdultFilterNotifier.new,
    );
