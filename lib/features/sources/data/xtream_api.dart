import 'dart:convert';

import 'package:dio/dio.dart';

import '../../profile/domain/xtream_account_info.dart';
import '../domain/media_item.dart';
import '../domain/source.dart';

class XtreamApi {
  final Dio _dio;
  XtreamApi(this._dio);

  Uri _build(XtreamSource src, String action, [Map<String, dynamic>? extra]) {
    final base = src.url.endsWith('/')
        ? src.url.substring(0, src.url.length - 1)
        : src.url;
    final params = <String, dynamic>{
      'username': src.username,
      'password': src.password,
      'action': action,
      ...?extra,
    };
    return Uri.parse(
      '$base/player_api.php',
    ).replace(queryParameters: params.map((k, v) => MapEntry(k, '$v')));
  }

  Uri _liveStreamUrl(
    XtreamSource src,
    String streamId, {
    String container = 'ts',
  }) {
    final base = src.url.endsWith('/')
        ? src.url.substring(0, src.url.length - 1)
        : src.url;
    return Uri.parse(
      '$base/live/${src.username}/${src.password}/$streamId.$container',
    );
  }

  Uri _vodStreamUrl(XtreamSource src, String streamId, String container) {
    final base = src.url.endsWith('/')
        ? src.url.substring(0, src.url.length - 1)
        : src.url;
    return Uri.parse(
      '$base/movie/${src.username}/${src.password}/$streamId.$container',
    );
  }

  Uri _seriesStreamUrl(XtreamSource src, String streamId, String container) {
    final base = src.url.endsWith('/')
        ? src.url.substring(0, src.url.length - 1)
        : src.url;
    return Uri.parse(
      '$base/series/${src.username}/${src.password}/$streamId.$container',
    );
  }

  Future<Map<String, dynamic>> auth(XtreamSource src) async {
    final base = src.url.endsWith('/')
        ? src.url.substring(0, src.url.length - 1)
        : src.url;
    final res = await _dio.get(
      '$base/player_api.php',
      queryParameters: {'username': src.username, 'password': src.password},
    );
    return _safeMap(res.data);
  }

  /// Subscription + server metadata used by the profile page. Wraps
  /// [auth] and parses the loosely-typed `user_info` / `server_info`
  /// blocks into a stable record.
  Future<XtreamAccountInfo> accountInfo(XtreamSource src) async {
    final data = await auth(src);
    final user = _safeMap(data['user_info']);
    final server = _safeMap(data['server_info']);
    DateTime? _date(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s == '0' || s == 'null') return null;
      final unix = int.tryParse(s);
      if (unix != null) {
        return DateTime.fromMillisecondsSinceEpoch(unix * 1000);
      }
      return DateTime.tryParse(s);
    }

    List<String> _stringList(dynamic v) {
      if (v is List) {
        return v
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return const [];
    }

    bool _bool(dynamic v) {
      if (v == null) return false;
      final s = v.toString().trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    return XtreamAccountInfo(
      sourceId: src.id,
      sourceName: src.name,
      username: (user['username'] ?? src.username)?.toString(),
      status: (user['status'])?.toString(),
      isTrial: _bool(user['is_trial']),
      expiresAt: _date(user['exp_date']),
      maxConnections: int.tryParse((user['max_connections'] ?? '').toString()),
      activeConnections: int.tryParse((user['active_cons'] ?? '').toString()),
      allowedFormats: _stringList(user['allowed_output_formats']),
      serverUrl: (server['url'])?.toString(),
      timezone: (server['timezone'])?.toString(),
    );
  }

  Future<List<dynamic>> _list(
    XtreamSource src,
    String action, [
    Map<String, dynamic>? extra,
  ]) async {
    final uri = _build(src, action, extra);
    final res = await _dio.getUri<dynamic>(uri);
    final data = _decodeIfString(res.data);
    if (data is List) return data;
    return const [];
  }

  Future<List<MediaCategory>> liveCategories(XtreamSource src) async {
    final data = await _list(src, 'get_live_categories');
    return data.map((raw) {
      final e = _safeMap(raw);
      return MediaCategory(
        id: (e['category_id'] ?? '').toString(),
        name: (e['category_name'] ?? '').toString(),
        kind: MediaKind.live,
      );
    }).toList();
  }

  Future<List<MediaCategory>> vodCategories(XtreamSource src) async {
    final data = await _list(src, 'get_vod_categories');
    return data.map((raw) {
      final e = _safeMap(raw);
      return MediaCategory(
        id: (e['category_id'] ?? '').toString(),
        name: (e['category_name'] ?? '').toString(),
        kind: MediaKind.movie,
      );
    }).toList();
  }

  Future<List<MediaCategory>> seriesCategories(XtreamSource src) async {
    final data = await _list(src, 'get_series_categories');
    return data.map((raw) {
      final e = _safeMap(raw);
      return MediaCategory(
        id: (e['category_id'] ?? '').toString(),
        name: (e['category_name'] ?? '').toString(),
        kind: MediaKind.series,
      );
    }).toList();
  }

  Future<List<MediaItem>> liveStreams(
    XtreamSource src, {
    String? categoryId,
  }) async {
    final data = await _list(src, 'get_live_streams', {
      if (categoryId != null) 'category_id': categoryId,
    });
    return data.map((raw) {
      final e = _safeMap(raw);
      final streamId = (e['stream_id'] ?? '').toString();
      return MediaItem(
        id: MediaItem.makeId(src.id, streamId),
        sourceId: src.id,
        streamId: streamId,
        name: (e['name'] ?? '').toString(),
        streamUrl: _liveStreamUrl(src, streamId).toString(),
        kind: MediaKind.live,
        logoUrl: _emptyToNull(e['stream_icon'] as String?),
        categoryId: _firstCategoryId(e),
        categoryName: null,
        // Xtream's xmltv.php references programmes by `epg_channel_id`,
        // not `stream_id`. Capture it so the EPG lookup matches.
        epgChannelId: _emptyToNull(e['epg_channel_id']?.toString()),
      );
    }).toList();
  }

  Future<List<MediaItem>> vodStreams(
    XtreamSource src, {
    String? categoryId,
  }) async {
    final data = await _list(src, 'get_vod_streams', {
      if (categoryId != null) 'category_id': categoryId,
    });
    return data.map((raw) {
      final e = _safeMap(raw);
      final streamId = (e['stream_id'] ?? '').toString();
      final container = (e['container_extension'] ?? 'mp4').toString();
      final year = int.tryParse((e['year'] ?? '').toString());
      final rating = double.tryParse((e['rating'] ?? '').toString());
      return MediaItem(
        id: MediaItem.makeId(src.id, streamId),
        sourceId: src.id,
        streamId: streamId,
        name: (e['name'] ?? '').toString(),
        streamUrl: _vodStreamUrl(src, streamId, container).toString(),
        kind: MediaKind.movie,
        logoUrl: _emptyToNull(e['stream_icon'] as String?),
        categoryId: _firstCategoryId(e),
        plot: e['plot'] as String?,
        year: year,
        rating: rating,
        addedAt: _parseAdded(e['added']),
      );
    }).toList();
  }

  Future<List<MediaItem>> seriesList(
    XtreamSource src, {
    String? categoryId,
  }) async {
    final data = await _list(src, 'get_series', {
      if (categoryId != null) 'category_id': categoryId,
    });
    return data.map((raw) {
      final e = _safeMap(raw);
      final seriesId = (e['series_id'] ?? '').toString();
      final year = int.tryParse(
        (e['releaseDate'] ?? e['year'] ?? '').toString().split('-').first,
      );
      final rating = double.tryParse((e['rating'] ?? '').toString());
      String? backdrop;
      final bp = e['backdrop_path'];
      if (bp is List && bp.isNotEmpty) backdrop = bp.first?.toString();
      // For series we use the Xtream `last_modified` field as the
      // "added date" - panels have no series-level `added` field, so this
      // is the closest fallback. If missing, we leave it null.
      return MediaItem(
        id: MediaItem.makeId(src.id, seriesId),
        sourceId: src.id,
        streamId: seriesId,
        name: (e['name'] ?? '').toString(),
        streamUrl: '',
        kind: MediaKind.series,
        logoUrl: _emptyToNull(e['cover'] as String?),
        backdropUrl: backdrop,
        // For `get_series` the Xtream panel sometimes returns only the
        // plural `category_ids: [5]` instead of a scalar `category_id`
        // (e.g. modern XC panels moved to the array form since a series can
        // carry multiple categories). When the scalar is empty, the first
        // element is the fallback; otherwise every series gets
        // categoryId=null → categoryName=null → the sidebar lumps all under "Other".
        categoryId: _firstCategoryId(e),
        plot: e['plot'] as String?,
        year: year,
        rating: rating,
        addedAt: _parseAdded(e['last_modified'] ?? e['added']),
      );
    }).toList();
  }

  /// Prefers the scalar `category_id`, otherwise the first element of the
  /// plural `category_ids` array. Returns null if both are empty/null.
  static String? _firstCategoryId(Map<String, dynamic> e) {
    final scalar = e['category_id'];
    if (scalar != null) {
      final s = scalar.toString();
      if (s.isNotEmpty) return s;
    }
    final ids = e['category_ids'];
    if (ids is List && ids.isNotEmpty) {
      final first = ids.first;
      if (first != null) {
        final s = first.toString();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  /// Xtream's `added` / `last_modified` fields send a unix timestamp (in
  /// seconds), but the type varies from panel to panel: some string, some
  /// int, and old panels give milliseconds. Converts them all safely to a
  /// UTC DateTime; returns null for invalid / empty / absurd far-future /
  /// NaN / Infinity values - so a broken panel can't bring down the whole
  /// refresh with a single field.
  static DateTime? _parseAdded(dynamic raw) {
    if (raw == null) return null;
    final asNum = num.tryParse(raw.toString());
    // `!asNum.isFinite` also catches NaN / Infinity / -Infinity;
    // otherwise `.toInt()` throws UnsupportedError and the _list/map chain
    // aborts the entire source ingest.
    if (asNum == null || !asNum.isFinite || asNum <= 0) return null;
    // DateTime's safe upper bound (~year 275760); treat values above this
    // as a panel error.
    if (asNum > 8640000000000000) return null;
    final asInt = asNum.toInt();
    // > 10^12 → milliseconds, otherwise seconds.
    final ms = asInt > 1000000000000 ? asInt : asInt * 1000;
    // A "future" date more than 30 days out signals a broken panel - drop.
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (ms > nowMs + _maxFutureMs) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  static const int _maxFutureMs = 30 * 24 * 60 * 60 * 1000;

  Future<MediaDetail> vodInfo(XtreamSource src, String streamId) async {
    final uri = _build(src, 'get_vod_info', {'vod_id': streamId});
    final res = await _dio.getUri<dynamic>(uri);
    final data = _safeMap(res.data);
    final info = _safeMap(data['info']);
    final movie = _safeMap(data['movie_data']);
    final gallery = <String>[];
    final bp = info['backdrop_path'];
    if (bp is List) {
      for (final v in bp) {
        final s = v?.toString();
        if (s != null && s.isNotEmpty) gallery.add(s);
      }
    }
    return MediaDetail(
      cast: MediaDetail.splitCsv(info['cast'] as String?),
      directors: MediaDetail.splitCsv(info['director'] as String?),
      genres: MediaDetail.splitCsv(info['genre'] as String?),
      runtimeSeconds: int.tryParse((info['duration_secs'] ?? '').toString()),
      releaseDate: _emptyToNull(
        (info['releasedate'] ?? movie['release_date'])?.toString(),
      ),
      country: _emptyToNull(info['country'] as String?),
      gallery: gallery,
      youtubeTrailer: _emptyToNull(info['youtube_trailer'] as String?),
      imdbId: _emptyToNull(info['tmdb_id']?.toString()),
      rating: double.tryParse((info['rating'] ?? '').toString()),
      plot: _emptyToNull(info['plot'] as String?),
      coverUrl: _emptyToNull(info['movie_image'] as String?),
      backdropUrl: gallery.isNotEmpty ? gallery.first : null,
    );
  }

  Future<SeriesDetail> seriesInfo(
    XtreamSource src,
    String seriesId,
    MediaItem info,
  ) async {
    final uri = _build(src, 'get_series_info', {'series_id': seriesId});
    final res = await _dio.getUri<dynamic>(uri);
    final data = _safeMap(res.data);
    final meta = _safeMap(data['info']);
    final gallery = <String>[];
    final bp = meta['backdrop_path'];
    if (bp is List) {
      for (final v in bp) {
        final s = v?.toString();
        if (s != null && s.isNotEmpty) gallery.add(s);
      }
    }
    final detail = MediaDetail(
      cast: MediaDetail.splitCsv(meta['cast'] as String?),
      directors: MediaDetail.splitCsv(meta['director'] as String?),
      genres: MediaDetail.splitCsv(meta['genre'] as String?),
      runtimeSeconds: null,
      releaseDate: _emptyToNull(meta['releaseDate']?.toString()),
      country: _emptyToNull(meta['country'] as String?),
      gallery: gallery,
      youtubeTrailer: _emptyToNull(meta['youtube_trailer'] as String?),
      rating: double.tryParse((meta['rating'] ?? '').toString()),
      plot: _emptyToNull(meta['plot'] as String?),
      coverUrl: _emptyToNull(meta['cover'] as String?),
      backdropUrl: gallery.isNotEmpty ? gallery.first : null,
    );

    final seasons = _safeMap(data['episodes']);
    final eps = <SeriesEpisode>[];
    for (final entry in seasons.entries) {
      final seasonNum = int.tryParse(entry.key) ?? 0;
      final list = _safeList(entry.value);
      for (final raw in list) {
        final e = _safeMap(raw);
        final id = (e['id'] ?? '').toString();
        final container = (e['container_extension'] ?? 'mp4').toString();
        final epInfo = _safeMap(e['info']);
        // For the episode `added` field use the shared helper from the
        // VOD/series list - UTC, future-clamp, num.tryParse.
        final addedAt = _parseAdded(e['added'] ?? epInfo['added']);
        final airDate = _emptyToNull(
          (epInfo['release_date'] ??
                  epInfo['air_date'] ??
                  epInfo['releasedate'])
              ?.toString(),
        );
        eps.add(
          SeriesEpisode(
            id: id,
            seriesId: seriesId,
            season: seasonNum,
            episode: int.tryParse((e['episode_num'] ?? '0').toString()) ?? 0,
            title: (e['title'] ?? 'Episode').toString(),
            streamUrl: _seriesStreamUrl(src, id, container).toString(),
            plot: epInfo['plot'] as String?,
            durationSeconds: int.tryParse(
              (epInfo['duration_secs'] ?? '0').toString(),
            ),
            thumbnailUrl: epInfo['movie_image'] as String?,
            addedAt: addedAt,
            airDate: airDate,
          ),
        );
      }
    }
    return SeriesDetail(info: info, detail: detail, episodes: eps);
  }

  Future<Map<String, dynamic>> shortEpg(
    XtreamSource src,
    String streamId, {
    int limit = 4,
  }) async {
    final uri = _build(src, 'get_short_epg', {
      'stream_id': streamId,
      'limit': limit,
    });
    final res = await _dio.getUri<dynamic>(uri);
    return _safeMap(res.data);
  }

  static String? _emptyToNull(String? s) => (s == null || s.isEmpty) ? null : s;

  /// Some Xtream/XUI panels send the JSON body with a `text/html` /
  /// `text/plain` content-type instead of `application/json`. Even with
  /// `responseType: ResponseType.json` set, dio only auto-decodes the
  /// body when the content-type is a JSON mime-type (see dio
  /// SyncTransformer.transformResponse: the `isJsonContent` gate).
  /// Otherwise `res.data` arrives as a raw String; `_list` silently fell
  /// back to an empty list and never loaded the categories - streams came
  /// through because they use the right content-type, so content loaded
  /// but categories didn't. If the body is a String we hand-decode it into the same pipeline.
  static dynamic _decodeIfString(dynamic v) {
    if (v is! String) return v;
    final s = v.trim();
    if (s.isEmpty) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  /// Some Xtream panels return empty fields as `[]` (List) instead of
  /// `{}` (Map) - the raw `as Map<String, dynamic>?` cast then explodes
  /// with "type 'List<dynamic>' is not a subtype of type 'Map<String,
  /// dynamic>?' in type cast". This helper returns an empty map for any
  /// non-map value so callers can keep using `.[key]` access safely.
  /// String bodies ([_decodeIfString]) are decoded first; detail / profile
  /// / EPG still parse even if the panel returns a non-JSON content-type.
  static Map<String, dynamic> _safeMap(dynamic v) {
    final decoded = _decodeIfString(v);
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  static List<dynamic> _safeList(dynamic v) {
    if (v is List) return v;
    return const <dynamic>[];
  }
}
