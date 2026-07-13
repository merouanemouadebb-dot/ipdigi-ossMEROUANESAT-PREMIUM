/// One row from an XMLTV `<programme>` element after parsing. We keep
/// the bare essentials needed by the UI - title, description, time
/// window, the channel id used to match against `MediaItem.streamId`,
/// and any `<category>` tags so we can build "now showing sport / news"
/// smart rows.
class EpgProgram {
  final String channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime stop;
  final List<String> categories;

  const EpgProgram({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
    this.categories = const [],
  });

  Duration get duration => stop.difference(start);

  bool isLiveAt(DateTime t) => !t.isBefore(start) && t.isBefore(stop);

  /// 0.0 → just started, 1.0 → just ended. Clamped so the value can be
  /// fed straight into a `LinearProgressIndicator` even if [t] sits
  /// slightly outside the window because of clock skew.
  double progressAt(DateTime t) {
    final total = stop.difference(start).inMilliseconds;
    if (total <= 0) return 0;
    final elapsed = t.difference(start).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
