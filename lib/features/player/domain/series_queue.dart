import '../../sources/domain/media_item.dart';

class SeriesQueue {
  final String seriesId;
  final String seriesSourceId;
  final String seriesName;
  final String? seriesPosterUrl;
  final List<SeriesEpisode> episodes;
  final int currentIndex;

  const SeriesQueue({
    required this.seriesId,
    required this.seriesSourceId,
    required this.seriesName,
    required this.episodes,
    required this.currentIndex,
    this.seriesPosterUrl,
  });

  SeriesEpisode get current => episodes[currentIndex];
  SeriesEpisode? get next =>
      currentIndex + 1 < episodes.length ? episodes[currentIndex + 1] : null;
  SeriesEpisode? get previous =>
      currentIndex > 0 ? episodes[currentIndex - 1] : null;
  bool get hasNext => next != null;
  bool get hasPrevious => previous != null;

  SeriesQueue advance() => at(currentIndex + 1);
  SeriesQueue back() => at(currentIndex - 1);

  SeriesQueue at(int index) => SeriesQueue(
    seriesId: seriesId,
    seriesSourceId: seriesSourceId,
    seriesName: seriesName,
    seriesPosterUrl: seriesPosterUrl,
    episodes: episodes,
    currentIndex: index,
  );

  String contentIdFor(SeriesEpisode ep) => '$seriesSourceId|ep-${ep.id}';
}
