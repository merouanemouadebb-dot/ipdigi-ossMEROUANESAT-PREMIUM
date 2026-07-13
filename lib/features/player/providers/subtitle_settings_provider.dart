import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/app_prefs_store.dart';

class SubtitleSettings {
  final double fontSize;
  final Color color;
  final Color outlineColor;
  final double outlineWidth;
  final Color backgroundColor;
  final FontWeight fontWeight;

  static const double minFontSize = 14;
  static const double maxFontSize = 96;
  // 2nd swatch in the subtitle-style palette and the sweet spot for
  // reading against bright cinema backdrops.
  static const Color defaultColor = Color(0xFFFFEB3B);

  const SubtitleSettings({
    this.fontSize = 50,
    this.color = defaultColor,
    this.outlineColor = Colors.black,
    this.outlineWidth = 0.5,
    this.backgroundColor = Colors.transparent,
    this.fontWeight = FontWeight.w600,
  });

  SubtitleSettings copyWith({
    double? fontSize,
    Color? color,
    Color? outlineColor,
    double? outlineWidth,
    Color? backgroundColor,
    FontWeight? fontWeight,
  }) {
    return SubtitleSettings(
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }

  TextStyle toTextStyle() {
    return TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      shadows: outlineWidth > 0
          ? [
              Shadow(
                blurRadius: outlineWidth * 1.5,
                color: outlineColor,
                offset: const Offset(-1, -1),
              ),
              Shadow(
                blurRadius: outlineWidth * 1.5,
                color: outlineColor,
                offset: const Offset(1, -1),
              ),
              Shadow(
                blurRadius: outlineWidth * 1.5,
                color: outlineColor,
                offset: const Offset(-1, 1),
              ),
              Shadow(
                blurRadius: outlineWidth * 1.5,
                color: outlineColor,
                offset: const Offset(1, 1),
              ),
            ]
          : null,
      backgroundColor: backgroundColor,
      height: 1.3,
      letterSpacing: 0.2,
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'color': color.toARGB32(),
    'outlineColor': outlineColor.toARGB32(),
    'outlineWidth': outlineWidth,
    'backgroundColor': backgroundColor.toARGB32(),
    'fontWeight': fontWeight.value,
  };

  static SubtitleSettings fromJson(Map<String, dynamic> json) {
    return SubtitleSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 50,
      color: Color((json['color'] as int?) ?? defaultColor.toARGB32()),
      outlineColor: Color((json['outlineColor'] as int?) ?? 0xFF000000),
      outlineWidth: (json['outlineWidth'] as num?)?.toDouble() ?? 0.5,
      backgroundColor: Color((json['backgroundColor'] as int?) ?? 0x00000000),
      fontWeight: _weightFromValue((json['fontWeight'] as int?) ?? 600),
    );
  }

  static FontWeight _weightFromValue(int v) {
    for (final w in FontWeight.values) {
      if (w.value == v) return w;
    }
    return FontWeight.w600;
  }
}

/// Persistent subtitle defaults, kept in `settings.json` under the
/// `subtitle` section.
class PersistedSubtitleSettingsNotifier
    extends AsyncNotifier<SubtitleSettings> {
  static const _section = 'subtitle';

  @override
  Future<SubtitleSettings> build() async {
    final store = ref.read(appPrefsStoreProvider);
    final data = await store.readSection(_section);
    if (data == null) return const SubtitleSettings();
    return SubtitleSettings.fromJson(data);
  }

  Future<void> _persist(SubtitleSettings s) async {
    state = AsyncData(s);
    await ref.read(appPrefsStoreProvider).writeSection(_section, s.toJson());
  }

  Future<void> setFontSize(double v) async =>
      _persist((state.value ?? const SubtitleSettings()).copyWith(fontSize: v));
  Future<void> setColor(Color v) async =>
      _persist((state.value ?? const SubtitleSettings()).copyWith(color: v));
  Future<void> setOutlineColor(Color v) async => _persist(
    (state.value ?? const SubtitleSettings()).copyWith(outlineColor: v),
  );
  Future<void> setOutlineWidth(double v) async => _persist(
    (state.value ?? const SubtitleSettings()).copyWith(outlineWidth: v),
  );
  Future<void> setBackgroundColor(Color v) async => _persist(
    (state.value ?? const SubtitleSettings()).copyWith(backgroundColor: v),
  );
  Future<void> setFontWeight(FontWeight v) async => _persist(
    (state.value ?? const SubtitleSettings()).copyWith(fontWeight: v),
  );
}

final persistedSubtitleSettingsProvider =
    AsyncNotifierProvider<PersistedSubtitleSettingsNotifier, SubtitleSettings>(
      PersistedSubtitleSettingsNotifier.new,
    );

/// Runtime overrides for the current player session. Reset to the persisted
/// defaults whenever a new film opens, so tweaks inside one film don't bleed
/// into the next.
class SubtitleSettingsNotifier extends Notifier<SubtitleSettings> {
  @override
  SubtitleSettings build() {
    final persisted = ref.watch(persistedSubtitleSettingsProvider).value;
    return persisted ?? const SubtitleSettings();
  }

  void setFontSize(double v) => state = state.copyWith(fontSize: v);
  void setColor(Color v) => state = state.copyWith(color: v);
  void setOutlineColor(Color v) => state = state.copyWith(outlineColor: v);
  void setOutlineWidth(double v) => state = state.copyWith(outlineWidth: v);
  void setBackgroundColor(Color v) =>
      state = state.copyWith(backgroundColor: v);
  void setFontWeight(FontWeight v) => state = state.copyWith(fontWeight: v);

  /// Force the player to re-sync with persisted defaults - call this when a
  /// new film loads so previous-session tweaks don't carry over.
  void resetToPersisted() {
    final persisted = ref.read(persistedSubtitleSettingsProvider).value;
    if (persisted != null) state = persisted;
  }
}

final subtitleSettingsProvider =
    NotifierProvider<SubtitleSettingsNotifier, SubtitleSettings>(
      SubtitleSettingsNotifier.new,
    );
