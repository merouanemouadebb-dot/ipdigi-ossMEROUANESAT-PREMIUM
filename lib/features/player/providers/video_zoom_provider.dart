import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/black_bar_detector.dart';

/// Display-time zoom mode applied as a `Transform.scale` around the
/// Video widget. Going through Flutter's compositor instead of mpv
/// properties because the latter (`video-crop`, `vf=crop`, panscan)
/// are silently no-ops on some media_kit backends; a widget-level
/// transform always lands.
///
/// Modes are session-scoped: kept on a Riverpod notifier without
/// persistence because the right choice is per-file (a 4:3 cartoon
/// and a 21:9 movie need opposite crops, remembering one is a
/// recipe for the wrong one being applied later).
enum VideoZoomMode {
  /// No transform. Default. Whatever aspect ratio the source
  /// ships with is what the player widget gets, letterboxed by
  /// `BoxFit.contain` against the available area.
  auto(
    labelKey: 'player.zoomAutoLabel',
    hintKey: 'player.zoomAutoHint',
    scale: 1.0,
  ),

  /// Letterbox stripper for the bulk of theatrical content
  /// delivered in a 16:9 container. Most films are 2.40:1
  /// "anamorphic widescreen", not exactly 21:9; the right scale
  /// is 1080/800 = 1.35 so the burnt-in top + bottom bars exit
  /// the viewport with a small safety margin. ClipRect chops
  /// whatever spills.
  cinema21x9(
    labelKey: 'player.zoomCinemaLabel',
    hintKey: 'player.zoomCinemaHint',
    scale: 1.35,
  ),

  /// 4:3 content packed into a 16:9 container with side pillars.
  /// 16/12 = 1.333 fills the frame horizontally; loses some top
  /// and bottom of the 4:3 content as a trade-off.
  classic4x3(
    labelKey: 'player.zoom43Label',
    hintKey: 'player.zoom43Hint',
    scale: 1.3333333333,
  ),

  /// Auto-detect mode: a detector samples a few frames and detects the
  /// black bars, then computes a dynamic scale from the result. The 1.2
  /// defined here is only a *fallback*: if detection fails (e.g. the first
  /// frames aren't ready yet) it is applied temporarily, and the real
  /// value is overridden via [dynamicFillScaleProvider].
  fill(
    labelKey: 'player.zoomFillLabel',
    hintKey: 'player.zoomFillHint',
    scale: 1.2,
  );

  /// i18n keys - the visible text is resolved with `ref.tr(labelKey)`
  /// (the enum is const, so we can't translate directly here).
  final String labelKey;
  final String hintKey;

  /// Linear multiplier passed straight to `Transform.scale` around
  /// the Video widget. Driving the crop at the Flutter compositor
  /// level avoids every per-backend mpv property quirk and
  /// guarantees the picker actually shows what the user picked.
  final double scale;

  const VideoZoomMode({
    required this.labelKey,
    required this.hintKey,
    required this.scale,
  });

  VideoZoomMode get next {
    final list = VideoZoomMode.values;
    final i = list.indexOf(this);
    return list[(i + 1) % list.length];
  }
}

class VideoZoomNotifier extends Notifier<VideoZoomMode> {
  @override
  VideoZoomMode build() => VideoZoomMode.auto;

  void set(VideoZoomMode mode) => state = mode;

  VideoZoomMode cycle() {
    final next = state.next;
    state = next;
    return next;
  }
}

final videoZoomProvider = NotifierProvider<VideoZoomNotifier, VideoZoomMode>(
  VideoZoomNotifier.new,
);

/// The raw edge result captured by the detector when "Fill Screen" mode is
/// selected. We store the result, not the scale, because the right scale
/// depends on the window size - once the bar ratio within the codec frame
/// is known, the scale is computed each build from the current viewport.
///
/// When `null`, detection hasn't run yet; in that case
/// [VideoZoomMode.fill.scale] (1.2) is used as a temporary fallback.
class DynamicFillResultNotifier extends Notifier<BlackBarResult?> {
  @override
  BlackBarResult? build() => null;

  void set(BlackBarResult? value) => state = value;
  void clear() => state = null;
}

final dynamicFillResultProvider =
    NotifierProvider<DynamicFillResultNotifier, BlackBarResult?>(
      DynamicFillResultNotifier.new,
    );
