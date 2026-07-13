import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/user_preferences.dart';

/// Coarse bitrate caps surfaced in the player Quality menu. We deliberately
/// keep the list short and human-meaningful: most users do not know what
/// "8 Mbps" means but they do know "slow connection" vs "best available".
///
/// The cap is applied to mpv via `hls-bitrate=<bps>`. For streams that
/// have no variant playlist (plain TS, MP4, MKV - the bulk of Xtream live
/// channels) mpv silently ignores the property, so the picker is safe to
/// keep visible everywhere even though it only meaningfully bites HLS /
/// DASH multi-bitrate sources.
enum QualityCap {
  /// No cap - mpv's own adaptive logic picks the best variant the
  /// network can sustain. This is the default and what we'd recommend
  /// for the average user.
  auto(
    labelKey: 'player.qualityAutoLabel',
    bitrate: null,
    hintKey: 'player.qualityAutoHint',
  ),

  /// Hard cap at ~1 Mbps - useful on metered mobile / slow connections.
  low(
    labelKey: 'player.qualityLowLabel',
    bitrate: 1000000,
    hintKey: 'player.qualityLowHint',
  ),

  /// ~3 Mbps cap - covers SD / 720p comfortably.
  medium(
    labelKey: 'player.qualityMediumLabel',
    bitrate: 3000000,
    hintKey: 'player.qualityMediumHint',
  ),

  /// ~6 Mbps cap - comfortable 1080p ceiling.
  high(
    labelKey: 'player.qualityHighLabel',
    bitrate: 6000000,
    hintKey: 'player.qualityHighHint',
  ),

  /// Force the highest variant the manifest offers. mpv accepts `max`
  /// as a magic value for this.
  max(
    labelKey: 'player.qualityMaxLabel',
    bitrate: -1,
    hintKey: 'player.qualityMaxHint',
  );

  /// i18n keys - the visible text is resolved via `ref.tr(labelKey)`.
  final String labelKey;
  final String hintKey;

  /// Bytes-per-second cap, or `-1` for "max", or null for "auto" (no
  /// property set). Stored as int so the mpv property formatter is a
  /// plain `toString()` call.
  final int? bitrate;

  const QualityCap({
    required this.labelKey,
    required this.bitrate,
    required this.hintKey,
  });

  /// String form of the `hls-bitrate` value mpv expects. Returns null
  /// when nothing should be sent (auto), which is the signal for
  /// [PlayerSession.applyQualityCap] to clear any previous cap.
  String? get mpvValue {
    if (bitrate == null) return null;
    if (bitrate == -1) return 'max';
    return bitrate.toString();
  }

  static QualityCap fromName(String? name) {
    if (name == null) return QualityCap.auto;
    for (final c in QualityCap.values) {
      if (c.name == name) return c;
    }
    return QualityCap.auto;
  }
}

class QualityNotifier extends AsyncNotifier<QualityCap> {
  @override
  Future<QualityCap> build() async {
    final prefs = ref.read(userPreferencesProvider);
    final raw = await prefs.getString(PrefKeys.playbackQuality);
    return QualityCap.fromName(raw);
  }

  Future<void> set(QualityCap cap) async {
    state = AsyncData(cap);
    final prefs = ref.read(userPreferencesProvider);
    await prefs.setString(PrefKeys.playbackQuality, cap.name);
  }
}

final qualityProvider = AsyncNotifierProvider<QualityNotifier, QualityCap>(
  QualityNotifier.new,
);
