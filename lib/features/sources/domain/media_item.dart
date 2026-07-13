enum MediaKind { live, movie, series }

class MediaItem {
  final String id; // composite: sourceId|streamId
  final String sourceId;
  final String streamId;
  final String name;
  final String? logoUrl;
  final String? backdropUrl;
  final String streamUrl;
  final String? categoryId;
  final String? categoryName;
  final MediaKind kind;
  final String? plot;
  final int? year;
  final double? rating;

  /// XMLTV channel id used to look up EPG programmes. For Xtream this
  /// is the panel's `epg_channel_id` field (distinct from `stream_id`,
  /// which we keep as [streamId] for playback). For M3U entries it is
  /// the `tvg-id` attribute when present. Nullable because not every
  /// playlist ships it.
  final String? epgChannelId;

  /// The added time - comes from Xtream panels' `added` field (unix
  /// timestamp). The "Newly Added" sorting uses this value; stays empty for
  /// M3U / Direct sources.
  final DateTime? addedAt;

  /// Flat M3U playlists list every series episode as its own entry. We parse
  /// the "SxxExx" naming and collapse them: one container row per series
  /// (seriesId == null, shown in the Series grid) plus one row per episode
  /// (seriesId == the container's streamId, hidden from the grid and looked
  /// up by the detail page). Always null for live, movies, and Xtream series
  /// (whose episodes come from the API instead).
  final String? seriesId;

  const MediaItem({
    required this.id,
    required this.sourceId,
    required this.streamId,
    required this.name,
    required this.streamUrl,
    required this.kind,
    this.logoUrl,
    this.backdropUrl,
    this.categoryId,
    this.categoryName,
    this.plot,
    this.year,
    this.rating,
    this.epgChannelId,
    this.addedAt,
    this.seriesId,
  });

  MediaItem copyWith({
    String? logoUrl,
    String? backdropUrl,
    String? categoryId,
    String? categoryName,
    String? plot,
    int? year,
    double? rating,
    String? epgChannelId,
    DateTime? addedAt,
    String? seriesId,
  }) {
    return MediaItem(
      id: id,
      sourceId: sourceId,
      streamId: streamId,
      name: name,
      streamUrl: streamUrl,
      kind: kind,
      logoUrl: logoUrl ?? this.logoUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      plot: plot ?? this.plot,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      addedAt: addedAt ?? this.addedAt,
      seriesId: seriesId ?? this.seriesId,
    );
  }

  static String makeId(String sourceId, String streamId) =>
      '$sourceId|$streamId';

  /// IPTV panels often prefix channel names with their country/language
  /// code, e.g. `TR: Show TV` or `USA: CNN HD`. We already group items
  /// by country in the sidebar, so the prefix is just visual noise on the
  /// tile itself - strip it for display while keeping the raw name in the
  /// database (so searches still match the original).
  ///
  /// We only peel off a short, fully-uppercase prefix followed by `:` and
  /// whitespace. This protects names that legitimately contain colons -
  /// "04:30 Haberler", "Bein Sports HD: Live", etc.
  String get displayName {
    final m = _displayPrefixRegex.firstMatch(name);
    if (m != null) {
      final rest = m.group(2)!.trim();
      if (rest.isNotEmpty) return rest;
    }
    return name;
  }

  // Whitespace after the colon is optional - most M3U sources emit the
  // prefix glued to the channel name (`TR:ShowTV`), some pad it
  // (`USA: CNN HD`). Both should match.
  static final RegExp _displayPrefixRegex = RegExp(
    r'^([A-Z]{2,5})\s*:\s*(.+)$',
  );
}

class MediaCategory {
  final String id;
  final String name;
  final MediaKind kind;
  const MediaCategory({
    required this.id,
    required this.name,
    required this.kind,
  });
}

class MediaDetail {
  final List<String> cast;
  final List<String> directors;
  final List<String> genres;
  final int? runtimeSeconds;
  final String? releaseDate;
  final String? country;
  final List<String> gallery;
  final String? youtubeTrailer;
  final String? imdbId;
  final double? rating;
  final String? plot;
  final String? coverUrl;
  final String? backdropUrl;

  /// Region-localized age rating ("13+", "PG-13", "TP", …). Populated by
  /// the TMDB enrichment step when an API key is configured; sources
  /// (Xtream / M3U) currently provide no equivalent so this is null when
  /// TMDB is disabled or didn't return a match.
  final String? certification;

  /// The original (usually English) title returned by TMDB. Persisted so
  /// that even if the panel only ships the translated name (e.g. the
  /// Turkish title), search can still catch a "Dark Knight" query.
  final String? originalTitle;

  /// The title localized by TMDB. Some panels send the original title
  /// (e.g. "The Dark Knight") - in that case the localized title is kept
  /// separately for the user's localized (e.g. Turkish) search.
  final String? localizedTitle;

  /// TMDB keywords (like "alien-invasion", "heist-gone-wrong"). A sharper
  /// signal than the genre set; the main feature set used by the
  /// personalized recommender.
  final List<String> keywords;

  const MediaDetail({
    this.cast = const [],
    this.directors = const [],
    this.genres = const [],
    this.runtimeSeconds,
    this.releaseDate,
    this.country,
    this.gallery = const [],
    this.youtubeTrailer,
    this.imdbId,
    this.rating,
    this.plot,
    this.coverUrl,
    this.backdropUrl,
    this.certification,
    this.originalTitle,
    this.localizedTitle,
    this.keywords = const [],
  });

  static List<String> splitCsv(String? raw) {
    if (raw == null) return const [];
    return raw
        .split(RegExp(r'[,/;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

class SeriesEpisode {
  final String id;
  final String seriesId;
  final int season;
  final int episode;
  final String title;
  final String streamUrl;
  final String? plot;
  final int? durationSeconds;
  final String? thumbnailUrl;

  /// When the IPTV panel added this episode to the catalogue. Comes
  /// from Xtream's `added` field (unix timestamp, seconds). Useful to
  /// build a "newly added" view or flag fresh episodes since the last
  /// refresh.
  final DateTime? addedAt;

  /// Original broadcast / release date (e.g. `2024-03-15`). Comes from
  /// Xtream `info.release_date` (some panels use `air_date`). Stored as
  /// the raw string so locale-specific formatting can happen at the
  /// UI layer - value can be empty/partial on older episodes.
  final String? airDate;

  const SeriesEpisode({
    required this.id,
    required this.seriesId,
    required this.season,
    required this.episode,
    required this.title,
    required this.streamUrl,
    this.plot,
    this.durationSeconds,
    this.thumbnailUrl,
    this.addedAt,
    this.airDate,
  });
}

class SeriesDetail {
  final MediaItem info;
  final MediaDetail detail;
  final List<SeriesEpisode> episodes;
  const SeriesDetail({
    required this.info,
    required this.detail,
    required this.episodes,
  });

  Map<int, List<SeriesEpisode>> get bySeason {
    final map = <int, List<SeriesEpisode>>{};
    for (final ep in episodes) {
      map.putIfAbsent(ep.season, () => []).add(ep);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.episode.compareTo(b.episode));
    }
    return map;
  }
}
