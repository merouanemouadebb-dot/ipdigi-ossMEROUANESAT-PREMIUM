import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/app_prefs_store.dart';

/// User's preferred audio/subtitle track identity. We try multiple keys
/// when matching against an mpv stream's track list: explicit language
/// codes (e.g. "tr", "en"), titles ("Turkish Dub"), and the special
/// "no"/"auto" pseudo-tracks so the user can lock subtitles off.
class TrackPrefs {
  final String? audioLang;
  final String? audioTitle;

  /// Zero-based position of the chosen audio track within the stream's
  /// audio list. Used as a last-resort fallback when neither language
  /// nor title match a freshly-opened stream - e.g. when mpv reports
  /// both fields as null, which is common on Xtream sources.
  final int? audioIndex;
  final String? subtitleLang;
  final String? subtitleTitle;
  final String? subtitleId; // for "no" / "auto" pseudo-tracks
  final int? subtitleIndex;
  const TrackPrefs({
    this.audioLang,
    this.audioTitle,
    this.audioIndex,
    this.subtitleLang,
    this.subtitleTitle,
    this.subtitleId,
    this.subtitleIndex,
  });

  TrackPrefs copyWith({
    String? audioLang,
    String? audioTitle,
    int? audioIndex,
    String? subtitleLang,
    String? subtitleTitle,
    String? subtitleId,
    int? subtitleIndex,
    bool clearAudio = false,
    bool clearSubtitle = false,
  }) {
    return TrackPrefs(
      audioLang: clearAudio ? null : (audioLang ?? this.audioLang),
      audioTitle: clearAudio ? null : (audioTitle ?? this.audioTitle),
      audioIndex: clearAudio ? null : (audioIndex ?? this.audioIndex),
      subtitleLang: clearSubtitle ? null : (subtitleLang ?? this.subtitleLang),
      subtitleTitle: clearSubtitle
          ? null
          : (subtitleTitle ?? this.subtitleTitle),
      subtitleId: clearSubtitle ? null : (subtitleId ?? this.subtitleId),
      subtitleIndex: clearSubtitle
          ? null
          : (subtitleIndex ?? this.subtitleIndex),
    );
  }

  Map<String, dynamic> toJson() => {
    if (audioLang != null) 'audioLang': audioLang,
    if (audioTitle != null) 'audioTitle': audioTitle,
    if (audioIndex != null) 'audioIndex': audioIndex,
    if (subtitleLang != null) 'subtitleLang': subtitleLang,
    if (subtitleTitle != null) 'subtitleTitle': subtitleTitle,
    if (subtitleId != null) 'subtitleId': subtitleId,
    if (subtitleIndex != null) 'subtitleIndex': subtitleIndex,
  };

  static TrackPrefs fromJson(Map<String, dynamic> json) {
    return TrackPrefs(
      audioLang: json['audioLang'] as String?,
      audioTitle: json['audioTitle'] as String?,
      audioIndex: (json['audioIndex'] as num?)?.toInt(),
      subtitleLang: json['subtitleLang'] as String?,
      subtitleTitle: json['subtitleTitle'] as String?,
      subtitleId: json['subtitleId'] as String?,
      subtitleIndex: (json['subtitleIndex'] as num?)?.toInt(),
    );
  }
}

class TrackPrefsNotifier extends AsyncNotifier<TrackPrefs> {
  static const _section = 'tracks';

  @override
  Future<TrackPrefs> build() async {
    final data = await ref.read(appPrefsStoreProvider).readSection(_section);
    if (data == null) return const TrackPrefs();
    return TrackPrefs.fromJson(data);
  }

  Future<void> _persist(TrackPrefs prefs) async {
    state = AsyncData(prefs);
    await ref
        .read(appPrefsStoreProvider)
        .writeSection(_section, prefs.toJson());
  }

  Future<void> setAudio({String? lang, String? title, int? index}) async {
    final current = state.value ?? const TrackPrefs();
    await _persist(
      current.copyWith(audioLang: lang, audioTitle: title, audioIndex: index),
    );
  }

  Future<void> setSubtitle({
    String? lang,
    String? title,
    String? id,
    int? index,
  }) async {
    final current = state.value ?? const TrackPrefs();
    await _persist(
      current.copyWith(
        subtitleLang: lang,
        subtitleTitle: title,
        subtitleId: id,
        subtitleIndex: index,
      ),
    );
  }
}

final trackPrefsProvider =
    AsyncNotifierProvider<TrackPrefsNotifier, TrackPrefs>(
      TrackPrefsNotifier.new,
    );
