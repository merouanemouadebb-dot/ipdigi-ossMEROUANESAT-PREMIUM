import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/database.dart';
import '../domain/media_item.dart';
import '../domain/source.dart';
import 'm3u_parser.dart';
import 'xtream_api.dart';

class SourceLoadResult {
  final List<MediaItem> items;
  final List<MediaCategory> categories;
  const SourceLoadResult({required this.items, required this.categories});
}

class SourceRepository {
  final AppDatabase _db;
  final Dio _dio;
  final XtreamApi _xtream;

  SourceRepository({required AppDatabase db, required Dio dio})
    : _db = db,
      _dio = dio,
      _xtream = XtreamApi(dio);

  Future<List<IptvSource>> listSources() async {
    final rows = await _db.select(_db.sources).get();
    return rows
        .map(
          (r) => IptvSource.fromRow(
            id: r.id,
            name: r.name,
            type: r.type,
            configJson: r.configJson,
            createdAt: r.createdAt,
          ),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> upsertSource(IptvSource src) async {
    await _db
        .into(_db.sources)
        .insertOnConflictUpdate(
          SourcesCompanion(
            id: Value(src.id),
            name: Value(src.name),
            type: Value(src.kind.name),
            configJson: Value(src.configJsonString()),
            createdAt: Value(src.createdAt),
          ),
        );
  }

  Future<void> deleteSource(String id) async {
    // Delete only the CATALOG cache and the source row. User signals
    // (favorites, watch history, ratings, watchlist, overrides) are KEPT:
    // since the source id is now deterministic, if the user re-adds the same
    // panel the content ids (sourceId|streamId) come back exactly the same
    // and all these records re-link automatically. A user who wants a
    // permanent delete can remove them one by one from the relevant screens
    // (e.g. My Ratings). Transaction: if one delete throws, do not leave it half-done.
    await _db.transaction(() async {
      await (_db.delete(
        _db.cachedChannels,
      )..where((t) => t.sourceId.equals(id))).go();
      await (_db.delete(
        _db.cachedDetails,
      )..where((t) => t.sourceId.equals(id))).go();
      await (_db.delete(_db.sources)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<SourceLoadResult> loadSource(IptvSource src) async {
    switch (src) {
      case XtreamSource():
        return _loadXtream(src);
      case M3uSource():
        return _loadM3u(src);
      case DirectUrlSource():
        return _loadDirect(src);
    }
  }

  Future<SourceLoadResult> _loadXtream(XtreamSource src) async {
    // ignore: avoid_print
    print('[${AppConfig.I.appName}] _loadXtream start name=${src.name}');
    final liveCats = await _safeCats(() => _xtream.liveCategories(src));
    final vodCats = await _safeCats(() => _xtream.vodCategories(src));
    final seriesCats = await _safeCats(() => _xtream.seriesCategories(src));
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] _loadXtream cats live=${liveCats.length} vod=${vodCats.length} series=${seriesCats.length}',
    );
    final liveLookup = {for (final c in liveCats) c.id: c.name};
    final vodLookup = {for (final c in vodCats) c.id: c.name};
    final seriesLookup = {for (final c in seriesCats) c.id: c.name};

    final liveRaw = await _xtream.liveStreams(src);
    final vodRaw = await _xtream.vodStreams(src);
    final seriesRaw = await _xtream.seriesList(src);

    List<MediaItem> enrich(List<MediaItem> items, Map<String, String> lookup) =>
        items.map((i) {
          final name = i.categoryId != null ? lookup[i.categoryId!] : null;
          if (name == null || name.isEmpty) return i;
          return i.copyWith(categoryName: name);
        }).toList();

    final all = [
      ...enrich(liveRaw, liveLookup),
      ...enrich(vodRaw, vodLookup),
      ...enrich(seriesRaw, seriesLookup),
    ];
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] _loadXtream streams live=${liveRaw.length} vod=${vodRaw.length} series=${seriesRaw.length} total=${all.length}',
    );
    await _cacheItems(src.id, all);
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] _loadXtream cached ${all.length} items for ${src.id}',
    );
    return SourceLoadResult(
      items: all,
      categories: [...liveCats, ...vodCats, ...seriesCats],
    );
  }

  Future<List<MediaCategory>> _safeCats(
    Future<List<MediaCategory>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return const [];
    }
  }

  /// m3u "blob" cleaning moved to a single source: [IptvSource.cleanM3uUrl].
  /// A thin delegation for backward-compatible callers (including tests).
  static String cleanM3uUrl(String raw) => IptvSource.cleanM3uUrl(raw);

  Future<SourceLoadResult> _loadM3u(M3uSource src) async {
    String content;
    final source = IptvSource.cleanM3uUrl(src.urlOrPath);
    if (source.startsWith('http')) {
      // Full-catalog M3U exports (Xtream get.php?type=m3u_plus) can be tens of
      // MB. Buffering the whole body as a decoded String via dio.get truncates
      // large responses; stream it to a temp file instead, then read it back.
      final dir = await getTemporaryDirectory();
      final tmp = File(p.join(dir.path, 'm3u_${src.id}.m3u'));
      await _dio.download(
        source,
        tmp.path,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
      content = await tmp.readAsString();
      try {
        await tmp.delete();
      } catch (_) {}
    } else {
      final file = File(source);
      content = await file.readAsString();
    }
    final parsed = M3uParser.parse(content);
    final items = M3uParser.toMediaItems(src.id, parsed);
    final cats = <String, MediaCategory>{};
    for (final i in items) {
      if (i.categoryName != null && i.categoryName!.isNotEmpty) {
        cats.putIfAbsent(
          i.categoryName!,
          () => MediaCategory(
            id: i.categoryName!,
            name: i.categoryName!,
            kind: i.kind,
          ),
        );
      }
    }
    await _cacheItems(src.id, items);
    return SourceLoadResult(items: items, categories: cats.values.toList());
  }

  Future<SourceLoadResult> _loadDirect(DirectUrlSource src) async {
    final item = MediaItem(
      id: MediaItem.makeId(src.id, src.id),
      sourceId: src.id,
      streamId: src.id,
      name: src.name,
      streamUrl: src.url,
      kind: MediaKind.live,
    );
    await _cacheItems(src.id, [item]);
    return SourceLoadResult(items: [item], categories: const []);
  }

  Future<void> _cacheItems(String sourceId, List<MediaItem> items) async {
    // All cache writing + orphan cleanup in a single transaction. Never let
    // the case happen where half fails, leaving cached_channels empty while
    // the side tables are untouched (which would give the user an empty
    // catalog + ghost history combination when they open the app).
    await _db.transaction(() async {
      // 1) Main table: full wipe + reinsert. Channels/movies/series no
      //    longer in the source drop automatically.
      await (_db.delete(
        _db.cachedChannels,
      )..where((t) => t.sourceId.equals(sourceId))).go();
      await _db.batch((batch) {
        for (var idx = 0; idx < items.length; idx++) {
          final i = items[idx];
          batch.insert(
            _db.cachedChannels,
            CachedChannelsCompanion(
              id: Value(i.id),
              sourceId: Value(i.sourceId),
              streamId: Value(i.streamId),
              name: Value(i.name),
              logoUrl: Value(i.logoUrl),
              backdropUrl: Value(i.backdropUrl),
              streamUrl: Value(i.streamUrl),
              categoryId: Value(i.categoryId),
              categoryName: Value(i.categoryName),
              kind: Value(i.kind.name),
              plot: Value(i.plot),
              year: Value(i.year),
              rating: Value(i.rating),
              position: Value(idx),
              cachedAt: Value(DateTime.now()),
              epgChannelId: Value(i.epgChannelId),
              addedAt: Value(i.addedAt),
              seriesId: Value(i.seriesId),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      // 2) Safety: if the source finished successfully but returned no items
      //    (e.g. empty JSON, category access exists but no stream list),
      //    do not wipe the side tables. When a transient upstream error
      //    passes, the user should not find their history/favorites gone.
      if (items.isEmpty) return;

      // 3) Orphan cleanup: only the CACHE table (cached_details).
      //    User signals (favorites, watch_history) are DELIBERATELY not
      //    cleared: when a panel temporarily removes a movie and re-adds it,
      //    favorites/watch history should not disappear. Since content_id is
      //    stable, records re-match on their own when the content returns.
      //    cached_details is derived cache only, so it is safe to delete.
      await _db.customUpdate(
        'DELETE FROM cached_details '
        'WHERE source_id = ? '
        '  AND id NOT IN (SELECT id FROM cached_channels WHERE source_id = ?)',
        variables: [sourceId, sourceId].map(Variable<String>.new).toList(),
        updates: {_db.cachedDetails},
      );
    });
  }

  Future<List<MediaItem>> cachedItems({
    String? sourceId,
    MediaKind? kind,
  }) async {
    final query = _db.select(_db.cachedChannels);
    if (sourceId != null) {
      query.where((t) => t.sourceId.equals(sourceId));
    }
    if (kind != null) {
      query.where((t) => t.kind.equals(kind.name));
    }
    // Flat-M3U series episodes are stored as their own rows linked by
    // seriesId; only series containers (seriesId IS NULL) appear in grids and
    // search. Episodes are reached through the detail page. Xtream/movie/live
    // rows always have seriesId NULL, so they are unaffected.
    query.where((t) => t.seriesId.isNull());
    query.orderBy([(t) => OrderingTerm(expression: t.position)]);
    final rows = await query.get();
    return rows.map(_rowToItem).toList();
  }

  Future<MediaItem?> cachedItem(String id) async {
    final row = await (_db.select(
      _db.cachedChannels,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _rowToItem(row);
  }

  /// Most recent `cachedAt` across all channels belonging to [sourceId], or
  /// null if nothing has been cached yet. The `_cacheItems` writer stamps
  /// every row with `DateTime.now()` on each refresh, so MAX across the
  /// source is a faithful "last successful pull" timestamp.
  Future<DateTime?> lastUpdatedAt(String sourceId) async {
    final maxExpr = _db.cachedChannels.cachedAt.max();
    final row =
        await (_db.selectOnly(_db.cachedChannels)
              ..addColumns([maxExpr])
              ..where(_db.cachedChannels.sourceId.equals(sourceId)))
            .getSingleOrNull();
    return row?.read(maxExpr);
  }

  MediaItem _rowToItem(CachedChannel r) {
    return MediaItem(
      id: r.id,
      sourceId: r.sourceId,
      streamId: r.streamId,
      name: r.name,
      streamUrl: r.streamUrl,
      kind: MediaKind.values.firstWhere(
        (k) => k.name == r.kind,
        orElse: () => MediaKind.live,
      ),
      logoUrl: r.logoUrl,
      backdropUrl: r.backdropUrl,
      categoryId: r.categoryId,
      categoryName: r.categoryName,
      plot: r.plot,
      year: r.year,
      rating: r.rating,
      epgChannelId: r.epgChannelId,
      addedAt: r.addedAt,
      seriesId: r.seriesId,
    );
  }

  Future<SeriesDetail?> seriesDetail(IptvSource src, MediaItem item) async {
    if (src is XtreamSource && item.kind == MediaKind.series) {
      return _xtream.seriesInfo(src, item.streamId, item);
    }
    // Flat M3U: the container's streamId is the seriesId stamped on every
    // episode row. Collect them and parse "SxxExx" from each name.
    if (item.kind == MediaKind.series) {
      final rows = await (_db.select(_db.cachedChannels)
            ..where((t) => t.sourceId.equals(item.sourceId))
            ..where((t) => t.seriesId.equals(item.streamId))
            ..orderBy([(t) => OrderingTerm(expression: t.position)]))
          .get();
      if (rows.isEmpty) return null;
      final episodes = <SeriesEpisode>[];
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final parsed = M3uParser.parseEpisodeNaming(r.name);
        episodes.add(
          SeriesEpisode(
            id: r.id,
            seriesId: item.streamId,
            season: parsed?.season ?? 1,
            episode: parsed?.episode ?? (i + 1),
            title: r.name,
            streamUrl: r.streamUrl,
            thumbnailUrl: r.logoUrl,
          ),
        );
      }
      return SeriesDetail(
        info: item,
        detail: const MediaDetail(),
        episodes: episodes,
      );
    }
    return null;
  }

  Future<MediaDetail?> movieDetail(IptvSource src, MediaItem item) async {
    if (src is XtreamSource && item.kind == MediaKind.movie) {
      try {
        return await _xtream.vodInfo(src, item.streamId);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<MediaDetail?> cachedDetail(String id) async {
    final row = await (_db.select(
      _db.cachedDetails,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _rowToDetail(row);
  }

  /// Deletes the cached_details row for a single content. Called after the
  /// user makes a manual TMDB override - otherwise the detail provider keeps
  /// returning the old (wrong) cached metadata and the override takes effect
  /// only in the UI. No-op if the row does not exist.
  Future<void> deleteDetail(String id) async {
    await (_db.delete(_db.cachedDetails)..where((t) => t.id.equals(id))).go();
  }

  Future<void> putDetail(MediaItem item, MediaDetail d) async {
    await _db
        .into(_db.cachedDetails)
        .insertOnConflictUpdate(
          CachedDetailsCompanion(
            id: Value(item.id),
            sourceId: Value(item.sourceId),
            streamId: Value(item.streamId),
            kind: Value(item.kind.name),
            castCsv: Value(d.cast.isEmpty ? null : d.cast.join(', ')),
            directorsCsv: Value(
              d.directors.isEmpty ? null : d.directors.join(', '),
            ),
            genresCsv: Value(d.genres.isEmpty ? null : d.genres.join(', ')),
            plot: Value(d.plot),
            country: Value(d.country),
            runtimeSeconds: Value(d.runtimeSeconds),
            releaseDate: Value(d.releaseDate),
            coverUrl: Value(d.coverUrl),
            backdropUrl: Value(d.backdropUrl),
            rating: Value(d.rating),
            cachedAt: Value(DateTime.now()),
            originalTitle: Value(d.originalTitle),
            localizedTitle: Value(d.localizedTitle),
            keywordsCsv:
                Value(d.keywords.isEmpty ? null : d.keywords.join(', ')),
            imdbId: Value(d.imdbId),
          ),
        );
  }

  /// Writes the panel-independent TMDB id onto the cached_details row. Since
  /// putDetail carries a MediaDetail (which has no tmdbId field), we go
  /// through a separate, lightweight update. No-op if the row does not exist
  /// (the detail has not been written yet).
  Future<void> setDetailTmdbId(String contentId, int tmdbId) async {
    await (_db.update(_db.cachedDetails)
          ..where((t) => t.id.equals(contentId)))
        .write(CachedDetailsCompanion(tmdbId: Value(tmdbId)));
  }

  Future<Map<String, MediaDetail>> allDetailsById() async {
    final rows = await _db.select(_db.cachedDetails).get();
    return {for (final r in rows) r.id: _rowToDetail(r)};
  }

  /// For panel-independent matching: a content_id → tmdbId map of every
  /// content whose tmdbId is known. The read side links a rating whose source
  /// was deleted (user_ratings.tmdbId) to the content with the same tmdbId in
  /// the current catalog.
  Future<Map<String, int>> allTmdbIdsByContentId() async {
    final rows = await (_db.select(_db.cachedDetails)
          ..where((t) => t.tmdbId.isNotNull()))
        .get();
    return {
      for (final r in rows)
        if (r.tmdbId != null) r.id: r.tmdbId!,
    };
  }

  MediaDetail _rowToDetail(CachedDetail r) {
    return MediaDetail(
      cast: r.castCsv == null ? const [] : MediaDetail.splitCsv(r.castCsv),
      directors: r.directorsCsv == null
          ? const []
          : MediaDetail.splitCsv(r.directorsCsv),
      genres: r.genresCsv == null
          ? const []
          : MediaDetail.splitCsv(r.genresCsv),
      runtimeSeconds: r.runtimeSeconds,
      releaseDate: r.releaseDate,
      country: r.country,
      plot: r.plot,
      coverUrl: r.coverUrl,
      backdropUrl: r.backdropUrl,
      rating: r.rating,
      originalTitle: r.originalTitle,
      localizedTitle: r.localizedTitle,
      keywords: r.keywordsCsv == null
          ? const []
          : MediaDetail.splitCsv(r.keywordsCsv),
      imdbId: r.imdbId,
    );
  }

  /// Original + localized titles resolved from TMDB for the search index.
  /// Returns only the populated ones - the panel name already comes through
  /// `cached_channels`; this helper is just an "alternate name" dictionary.
  /// Key: composite item id (sourceId|streamId).
  Future<Map<String, ({String? originalTitle, String? localizedTitle})>>
  allAlternateTitlesById() async {
    final rows =
        await (_db.select(_db.cachedDetails)..where(
              (t) => t.originalTitle.isNotNull() | t.localizedTitle.isNotNull(),
            ))
            .get();
    final out = <String, ({String? originalTitle, String? localizedTitle})>{};
    for (final r in rows) {
      out[r.id] = (
        originalTitle: r.originalTitle,
        localizedTitle: r.localizedTitle,
      );
    }
    return out;
  }
}
