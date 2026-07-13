import 'package:dio/dio.dart';

import '../../features/sources/domain/country_names.dart';

/// Lightweight TMDB v3 client. Only the endpoints we actually consume here:
/// search → details (with `release_dates` / `content_ratings` appended) →
/// localized title / overview / genres / age certification.
///
/// All calls go through [Dio]; the parent provider injects the key so we
/// stay testable. A null/empty key short-circuits every method to `null` so
/// the caller can treat TMDB as best-effort enrichment.
class TmdbService {
  final Dio _dio;
  final String apiKey;
  static const _base = 'https://api.themoviedb.org/3';
  static const _imgBase = 'https://image.tmdb.org/t/p';

  TmdbService({required Dio dio, required this.apiKey}) : _dio = dio;

  bool get enabled => apiKey.isNotEmpty;

  /// Live-checks an arbitrary key against the public `/configuration`
  /// endpoint (cheap, requires only auth). Used to validate user input
  /// before persisting it to the keychain.
  Future<TmdbVerifyResult> verifyKey(String key) async {
    if (key.trim().isEmpty) return TmdbVerifyResult.empty;
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$_base/configuration',
        queryParameters: {'api_key': key.trim()},
        options: Options(
          // Don't let Dio throw on 401 - we want to read the status code
          // and return [invalid] instead of [networkError].
          validateStatus: (s) => s != null && s < 500,
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      if (r.statusCode == 200) return TmdbVerifyResult.ok;
      if (r.statusCode == 401) return TmdbVerifyResult.invalid;
      return TmdbVerifyResult.networkError;
    } on DioException {
      return TmdbVerifyResult.networkError;
    } catch (_) {
      return TmdbVerifyResult.networkError;
    }
  }

  /// Lightweight multi-search: runs the same query for both movie and
  /// tv, extracting title + original_title + year to return a simple
  /// candidate list. Makes no detail call - it is the search page's
  /// "user query" helper; unlike lookupMovie it does not pick the single
  /// best candidate, it returns the first N hits.
  Future<List<TmdbSearchHit>> searchMulti({
    required String query,
    required String language,
    int limit = 8,
  }) async {
    if (!enabled || query.trim().isEmpty) return const [];
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$_base/search/multi',
        queryParameters: {
          'api_key': apiKey,
          'query': query,
          'language': language,
          'include_adult': 'true',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      );
      final raw = (r.data?['results'] as List?) ?? const [];
      final out = <TmdbSearchHit>[];
      for (final e in raw.whereType<Map>()) {
        final type = (e['media_type'] ?? '').toString();
        if (type != 'movie' && type != 'tv') continue;
        final title = type == 'movie'
            ? (e['title'] ?? '').toString()
            : (e['name'] ?? '').toString();
        final original = type == 'movie'
            ? (e['original_title'] ?? '').toString()
            : (e['original_name'] ?? '').toString();
        final date = (type == 'movie'
                ? e['release_date']
                : e['first_air_date'])
            ?.toString() ??
            '';
        int? year;
        if (date.length >= 4) {
          year = int.tryParse(date.substring(0, 4));
        }
        if (title.isEmpty && original.isEmpty) continue;
        out.add(TmdbSearchHit(
          tmdbId: (e['id'] is int) ? e['id'] as int : null,
          title: title,
          originalTitle: original,
          year: year,
          isMovie: type == 'movie',
          posterUrl: _img(e['poster_path']?.toString(), 'w342'),
          rating: _toDouble(e['vote_average']),
        ));
        if (out.length >= limit) break;
      }
      return out;
    } on DioException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Search by movie name (+ optional year hint), pick the first result,
  /// and fetch its localized detail bundle. Returns null on miss / error.
  Future<TmdbDetail?> lookupMovie({
    required String query,
    int? year,
    required String language,
    required String region,
  }) async {
    if (!enabled || query.trim().isEmpty) return null;
    try {
      final search = await _dio.get<Map<String, dynamic>>(
        '$_base/search/movie',
        queryParameters: {
          'api_key': apiKey,
          'query': query,
          if (year != null) 'year': year,
          'language': language,
          'include_adult': 'true',
        },
      );
      final results = (search.data?['results'] as List?) ?? const [];
      if (results.isEmpty) return null;
      final id = _pickBestMatch(
        results,
        query: query,
        titleKeys: const ['title', 'original_title'],
        dateKey: 'release_date',
        yearHint: year,
      );
      if (id == null) return null;
      return fetchMovieById(id, language: language, region: region);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Localized fetch by TMDB id - public so [tmdbDetailProvider] can chase
  /// an English fallback when the user's locale leaves critical fields
  /// (title / overview) empty.
  Future<TmdbDetail?> fetchMovieById(int id,
          {required String language, required String region}) =>
      _fetchMovie(id, language: language, region: region);

  Future<TmdbDetail?> fetchTvById(int id,
          {required String language, required String region}) =>
      _fetchTv(id, language: language, region: region);

  /// Same as [lookupMovie] but for TV shows. Uses `first_air_date_year` since
  /// TMDB's `/search/tv` does not accept `year`.
  Future<TmdbDetail?> lookupTv({
    required String query,
    int? year,
    required String language,
    required String region,
  }) async {
    if (!enabled || query.trim().isEmpty) return null;
    try {
      final search = await _dio.get<Map<String, dynamic>>(
        '$_base/search/tv',
        queryParameters: {
          'api_key': apiKey,
          'query': query,
          if (year != null) 'first_air_date_year': year,
          'language': language,
          'include_adult': 'true',
        },
      );
      final results = (search.data?['results'] as List?) ?? const [];
      // ignore: avoid_print
      print('[TMDB] tv search q="$query" lang=$language results=${results.length}');
      for (final r in results.take(5).whereType<Map>()) {
        // ignore: avoid_print
        print(
            '[TMDB]   - id=${r['id']} name="${r['name']}" original="${r['original_name']}" first_air=${r['first_air_date']} pop=${r['popularity']}');
      }
      if (results.isEmpty) return null;
      final id = _pickBestMatch(
        results,
        query: query,
        titleKeys: const ['name', 'original_name'],
        dateKey: 'first_air_date',
        yearHint: year,
      );
      // ignore: avoid_print
      print('[TMDB] tv picked id=$id for q="$query"');
      if (id == null) return null;
      return fetchTvById(id, language: language, region: region);
    } on DioException catch (e) {
      // ignore: avoid_print
      // Security: `e.message` may carry the full URI depending on Dio
      // version; the URI holds the `api_key` param, so we don't log it.
      // Status code and generic error type are enough diagnostic signal.
      print('[TMDB] tv search FAILED q="$query": status=${e.response?.statusCode} type=${e.type}');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[TMDB] tv search ERROR q="$query": $e');
      return null;
    }
  }

  /// TMDB search ranks results by popularity, which means short or
  /// generic queries ("STEAL", "Superman") frequently surface a more-popular
  /// but unrelated title before the actual match. Prefer an exact (or
  /// prefix) title hit over popularity. When several exact hits share the
  /// title (Superman 1978 vs 2026) we tiebreak by year:
  ///   - if [yearHint] is set, pick the entry closest to that year;
  ///   - otherwise pick the earliest release date (IPTV catalogs lean
  ///     toward classics; brand-new theatrical releases rarely appear).
  int? _pickBestMatch(
    List results, {
    required String query,
    required List<String> titleKeys,
    String? dateKey,
    int? yearHint,
  }) {
    final ql = query.toLowerCase().trim();
    final exacts = <Map>[];
    Map? prefix;
    for (final r in results.whereType<Map>()) {
      var matched = false;
      for (final key in titleKeys) {
        final t = (r[key] ?? '').toString().toLowerCase().trim();
        if (t.isEmpty) continue;
        if (t == ql) {
          exacts.add(r);
          matched = true;
          break;
        }
      }
      if (!matched && prefix == null) {
        for (final key in titleKeys) {
          final t = (r[key] ?? '').toString().toLowerCase().trim();
          if (t.isEmpty) continue;
          if (t.startsWith(ql) || ql.startsWith(t)) {
            prefix = r;
            break;
          }
        }
      }
    }
    Map? picked;
    if (exacts.isNotEmpty) {
      picked = _tiebreakByYear(exacts, dateKey: dateKey, yearHint: yearHint);
    } else if (prefix != null) {
      picked = prefix;
    } else {
      picked = results.firstWhere((e) => e is Map, orElse: () => {}) as Map?;
    }
    return picked == null ? null : picked['id'] as int?;
  }

  Map _tiebreakByYear(
    List<Map> entries, {
    String? dateKey,
    int? yearHint,
  }) {
    if (entries.length == 1 || dateKey == null) return entries.first;
    int? yearOf(Map e) {
      final s = (e[dateKey] ?? '').toString();
      if (s.length < 4) return null;
      return int.tryParse(s.substring(0, 4));
    }

    if (yearHint != null) {
      Map best = entries.first;
      int bestDelta = (yearOf(best) ?? 9999) - yearHint;
      bestDelta = bestDelta.abs();
      for (final e in entries.skip(1)) {
        final y = yearOf(e);
        if (y == null) continue;
        final d = (y - yearHint).abs();
        if (d < bestDelta) {
          best = e;
          bestDelta = d;
        }
      }
      return best;
    }
    // Without a year hint: when TMDB has multiple movies sharing the
    // same title, the user's "memorable" version is usually the more
    // popular one (Will Smith's Concussion vs. the 2013 indie drama).
    // We use vote_count as a proxy - popularity is a transient metric,
    // vote_count is more stable.
    double scoreOf(Map e) {
      final votes = (e['vote_count'] as num?)?.toDouble() ?? 0;
      final pop = (e['popularity'] as num?)?.toDouble() ?? 0;
      // vote_count dominant; popularity is only a tiebreaker.
      return votes + pop * 0.01;
    }

    Map best = entries.first;
    double bestScore = scoreOf(best);
    for (final e in entries.skip(1)) {
      final s = scoreOf(e);
      if (s > bestScore) {
        best = e;
        bestScore = s;
      }
    }
    return best;
  }

  Future<TmdbDetail?> _fetchMovie(int id,
      {required String language, required String region}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$_base/movie/$id',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          // Single roundtrip: keywords (for the recommendation engine),
          // recommendations (TMDB's "suggest similar"), reviews (the
          // reviews tab) and external_ids (IMDB) come with this response.
          'append_to_response':
              'release_dates,credits,images,videos,keywords,recommendations,reviews,external_ids',
          // No `include_image_language` filter: a brand-new title may
          // have its first backdrops tagged with neither the user's
          // locale nor English (or no language at all), and TMDB's
          // default returns every variant.
          'include_video_language': '$language,en',
        },
      );
      final data = r.data;
      if (data == null) return null;
      final genres = (data['genres'] as List?)
              ?.whereType<Map>()
              .map((g) => (g['name'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[];
      final cert = _movieCert(data['release_dates'], region);
      final credits = data['credits'] as Map?;
      final cast = _topCast(credits);
      final directors = _directors(credits);
      final gallery = _gallery(data['images']);
      final trailers = _trailers(data['videos']);
      final country = _movieCountries(data['production_countries'], language);
      final keywords = _keywords(data['keywords'], isMovie: true);
      final recs = _recommendations(
        data['recommendations'],
        defaultIsMovie: true,
      );
      final reviews = _reviews(data['reviews']);
      final imdb = _imdbId(data['external_ids']);
      return TmdbDetail(
        tmdbId: id,
        title: _orNull(data['title']?.toString()),
        originalTitle: _orNull(data['original_title']?.toString()),
        overview: _orNull(data['overview']?.toString()),
        genres: genres,
        certification: cert,
        rating: _toDouble(data['vote_average']),
        backdropUrl: _img(data['backdrop_path']?.toString(), 'w1280'),
        posterUrl: _img(data['poster_path']?.toString(), 'w500'),
        releaseDate: _orNull(data['release_date']?.toString()),
        cast: cast,
        directors: directors,
        gallery: gallery,
        trailers: trailers,
        country: country,
        keywords: keywords,
        recommendations: recs,
        reviews: reviews,
        imdbId: imdb,
        // Hero plays previews/teasers preferentially (streaming-app short
        // promo), but fall back to a full trailer if none exist.
        youtubeTrailerKey: _pickHeroVideo(trailers),
      );
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<TmdbDetail?> _fetchTv(int id,
      {required String language, required String region}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$_base/tv/$id',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          'append_to_response':
              'content_ratings,credits,images,videos,keywords,recommendations,reviews,external_ids',
          'include_video_language': '$language,en',
        },
      );
      final data = r.data;
      if (data == null) return null;
      final imagesMap = data['images'];
      final videosMap = data['videos'];
      final backdropCount = (imagesMap is Map &&
              imagesMap['backdrops'] is List)
          ? (imagesMap['backdrops'] as List).length
          : 0;
      final posterCount = (imagesMap is Map && imagesMap['posters'] is List)
          ? (imagesMap['posters'] as List).length
          : 0;
      final videoCount = (videosMap is Map && videosMap['results'] is List)
          ? (videosMap['results'] as List).length
          : 0;
      // ignore: avoid_print
      print(
          '[TMDB] tv/$id fetched lang=$language name="${data['name']}" '
          'original="${data['original_name']}" '
          'poster_path=${data['poster_path']} backdrop_path=${data['backdrop_path']} '
          'overview_len=${(data['overview'] ?? '').toString().length} '
          'backdrops=$backdropCount posters=$posterCount videos=$videoCount '
          'rating=${data['vote_average']}');
      final genres = (data['genres'] as List?)
              ?.whereType<Map>()
              .map((g) => (g['name'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[];
      final cert = _tvCert(data['content_ratings'], region);
      final credits = data['credits'] as Map?;
      final cast = _topCast(credits);
      final directors = _directors(credits);
      final gallery = _gallery(data['images']);
      final trailers = _trailers(data['videos']);
      final country = _tvCountries(data['origin_country'], language);
      final keywords = _keywords(data['keywords'], isMovie: false);
      final recs = _recommendations(
        data['recommendations'],
        defaultIsMovie: false,
      );
      final reviews = _reviews(data['reviews']);
      final imdb = _imdbId(data['external_ids']);
      return TmdbDetail(
        tmdbId: id,
        title: _orNull(data['name']?.toString()),
        originalTitle: _orNull(data['original_name']?.toString()),
        overview: _orNull(data['overview']?.toString()),
        genres: genres,
        certification: cert,
        rating: _toDouble(data['vote_average']),
        backdropUrl: _img(data['backdrop_path']?.toString(), 'w1280'),
        posterUrl: _img(data['poster_path']?.toString(), 'w500'),
        releaseDate: _orNull(data['first_air_date']?.toString()),
        cast: cast,
        directors: directors,
        gallery: gallery,
        trailers: trailers,
        country: country,
        keywords: keywords,
        recommendations: recs,
        reviews: reviews,
        imdbId: imdb,
        youtubeTrailerKey: _pickHeroVideo(trailers),
      );
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Search TMDB by person name and return the canonical record (bio,
  /// known credits, photos) for the top hit. Empty query / disabled key /
  /// no match → null.
  Future<TmdbPerson?> lookupPerson({
    required String query,
    required String language,
  }) async {
    if (!enabled || query.trim().isEmpty) return null;
    try {
      final search = await _dio.get<Map<String, dynamic>>(
        '$_base/search/person',
        queryParameters: {
          'api_key': apiKey,
          'query': query,
          'language': language,
          'include_adult': 'true',
        },
      );
      final results = (search.data?['results'] as List?) ?? const [];
      if (results.isEmpty) return null;
      final id = (results.first as Map)['id'] as int?;
      if (id == null) return null;
      return fetchPersonById(id, language: language);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<TmdbPerson?> fetchPersonById(int id,
      {required String language}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$_base/person/$id',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          'append_to_response': 'combined_credits,images',
        },
      );
      final data = r.data;
      if (data == null) return null;
      final credits = data['combined_credits'] as Map?;
      final castList = (credits?['cast'] as List?) ?? const [];
      final filmography = <TmdbPersonCredit>[];
      for (final c in castList.whereType<Map>()) {
        final cid = c['id'] as int?;
        final mediaType = (c['media_type'] ?? '').toString();
        if (cid == null) continue;
        if (mediaType != 'movie' && mediaType != 'tv') continue;
        filmography.add(TmdbPersonCredit(
          tmdbId: cid,
          mediaType: mediaType,
          title: _orNull(c['title']?.toString()) ??
              _orNull(c['name']?.toString()) ??
              '',
          character: _orNull(c['character']?.toString()),
          posterUrl: _img(c['poster_path']?.toString(), 'w342'),
          releaseDate: _orNull(c['release_date']?.toString()) ??
              _orNull(c['first_air_date']?.toString()),
          popularity: (c['popularity'] as num?)?.toDouble() ?? 0,
        ));
      }
      // Most-popular first matches what users expect from a filmography.
      filmography.sort((a, b) => b.popularity.compareTo(a.popularity));
      return TmdbPerson(
        tmdbId: id,
        name: _orNull(data['name']?.toString()) ?? '',
        biography: _orNull(data['biography']?.toString()),
        birthday: _orNull(data['birthday']?.toString()),
        deathday: _orNull(data['deathday']?.toString()),
        placeOfBirth: _orNull(data['place_of_birth']?.toString()),
        knownForDepartment: _orNull(data['known_for_department']?.toString()),
        profileUrl: _img(data['profile_path']?.toString(), 'h632'),
        filmography: filmography,
        gender: (data['gender'] as int?) ?? 0,
        alsoKnownAs: (data['also_known_as'] as List?)
                ?.whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .toList() ??
            const [],
      );
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch detailed metadata for every episode of one season. Keyed by
  /// `episode_number` so callers can merge per-episode without scanning.
  Future<Map<int, TmdbEpisode>> getTvSeason({
    required int tmdbId,
    required int seasonNumber,
    required String language,
  }) async {
    if (!enabled) return const {};
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$_base/tv/$tmdbId/season/$seasonNumber',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
        },
      );
      final episodes = (r.data?['episodes'] as List?) ?? const [];
      final out = <int, TmdbEpisode>{};
      for (final e in episodes.whereType<Map>()) {
        final num = e['episode_number'];
        if (num is! int) continue;
        out[num] = TmdbEpisode(
          episodeNumber: num,
          name: _orNull(e['name']?.toString()),
          overview: _orNull(e['overview']?.toString()),
          stillUrl: _img(e['still_path']?.toString(), 'w300'),
          airDate: _orNull(e['air_date']?.toString()),
        );
      }
      return out;
    } on DioException {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  // Flatten the YouTube videos block into a typed list, ordered so the
  // most "headline-worthy" entries surface first: official trailers,
  // unofficial trailers, teasers, then everything else (clips, behind
  // the scenes…). Only YouTube-hosted entries - site-agnostic embedding
  // is out of scope.
  List<TmdbVideo> _trailers(dynamic videos) {
    if (videos is! Map) return const [];
    final raw = (videos['results'] as List?) ?? const [];
    final out = <TmdbVideo>[];
    for (final v in raw.whereType<Map>()) {
      if ((v['site'] ?? '').toString().toLowerCase() != 'youtube') continue;
      final key = (v['key'] ?? '').toString();
      if (key.isEmpty) continue;
      final type = (v['type'] ?? '').toString();
      out.add(TmdbVideo(
        key: key,
        name: _orNull(v['name']?.toString()) ?? type,
        type: type,
        official: v['official'] == true,
      ));
    }
    int rank(TmdbVideo v) {
      final t = v.type.toLowerCase();
      if (t == 'trailer' && v.official) return 0;
      if (t == 'trailer') return 1;
      if (t == 'teaser') return 2;
      if (t == 'clip') return 3;
      if (t == 'featurette') return 4;
      return 5;
    }

    out.sort((a, b) => rank(a).compareTo(rank(b)));
    return out;
  }

  /// Pick what plays automatically on the detail hero. User asked for
  /// "preview if available, otherwise trailer" - TMDB exposes the short
  /// pre-release promos as `Teaser`, so we prefer those first, fall back
  /// to a full trailer (official preferred), and finally anything we have.
  String? _pickHeroVideo(List<TmdbVideo> trailers) {
    if (trailers.isEmpty) return null;
    TmdbVideo? findBy(bool Function(TmdbVideo) match) {
      for (final v in trailers) {
        if (match(v)) return v;
      }
      return null;
    }

    final teaser = findBy((v) => v.type.toLowerCase() == 'teaser');
    if (teaser != null) return teaser.key;
    final officialTrailer = findBy(
        (v) => v.type.toLowerCase() == 'trailer' && v.official);
    if (officialTrailer != null) return officialTrailer.key;
    final anyTrailer = findBy((v) => v.type.toLowerCase() == 'trailer');
    if (anyTrailer != null) return anyTrailer.key;
    return trailers.first.key;
  }

  /// Merge two [TmdbDetail]s, taking [primary]'s value when present and
  /// [fallback]'s otherwise. Used by the provider to back-fill an English
  /// response when the user's locale leaves title/overview empty.
  TmdbDetail mergeLocaleFallback(TmdbDetail primary, TmdbDetail fallback) {
    bool has(String? s) => s != null && s.trim().isNotEmpty;
    return TmdbDetail(
      tmdbId: primary.tmdbId,
      title: has(primary.title) ? primary.title : fallback.title,
      originalTitle: primary.originalTitle ?? fallback.originalTitle,
      overview: has(primary.overview) ? primary.overview : fallback.overview,
      genres: primary.genres.isNotEmpty ? primary.genres : fallback.genres,
      certification: primary.certification ?? fallback.certification,
      rating: primary.rating ?? fallback.rating,
      backdropUrl: primary.backdropUrl ?? fallback.backdropUrl,
      posterUrl: primary.posterUrl ?? fallback.posterUrl,
      releaseDate: has(primary.releaseDate)
          ? primary.releaseDate
          : fallback.releaseDate,
      cast: primary.cast.isNotEmpty ? primary.cast : fallback.cast,
      directors:
          primary.directors.isNotEmpty ? primary.directors : fallback.directors,
      gallery: primary.gallery.isNotEmpty ? primary.gallery : fallback.gallery,
      trailers:
          primary.trailers.isNotEmpty ? primary.trailers : fallback.trailers,
      youtubeTrailerKey:
          primary.youtubeTrailerKey ?? fallback.youtubeTrailerKey,
      country: primary.country ?? fallback.country,
      keywords:
          primary.keywords.isNotEmpty ? primary.keywords : fallback.keywords,
      recommendations: primary.recommendations.isNotEmpty
          ? primary.recommendations
          : fallback.recommendations,
      reviews:
          primary.reviews.isNotEmpty ? primary.reviews : fallback.reviews,
      imdbId: primary.imdbId ?? fallback.imdbId,
    );
  }

  /// `keywords` payload: `{keywords: [...]}` for movies, `{results:
  /// [...]}` for TV. Each entry is a `{id, name}` map.
  List<String> _keywords(dynamic raw, {required bool isMovie}) {
    if (raw is! Map) return const [];
    final list = isMovie ? raw['keywords'] : raw['results'];
    if (list is! List) return const [];
    final out = <String>[];
    for (final e in list.whereType<Map>()) {
      final name = (e['name'] ?? '').toString().trim().toLowerCase();
      if (name.isEmpty) continue;
      out.add(name);
    }
    // More than 30 is rare; we cap it to keep the recommendation vector
    // a reasonable size - low-signal keywords are usually at the end.
    return out.take(30).toList();
  }

  List<TmdbRecommendation> _recommendations(
    dynamic raw, {
    required bool defaultIsMovie,
  }) {
    if (raw is! Map) return const [];
    final results = (raw['results'] as List?) ?? const [];
    final out = <TmdbRecommendation>[];
    for (final e in results.whereType<Map>()) {
      final id = e['id'];
      if (id is! int) continue;
      final type = (e['media_type'] ?? '').toString();
      final isMovie = type == 'movie'
          ? true
          : type == 'tv'
              ? false
              : defaultIsMovie;
      final title = isMovie
          ? (e['title'] ?? '').toString()
          : (e['name'] ?? '').toString();
      if (title.trim().isEmpty) continue;
      final originalTitle = isMovie
          ? (e['original_title'] ?? '').toString()
          : (e['original_name'] ?? '').toString();
      final date = (isMovie ? e['release_date'] : e['first_air_date'])
              ?.toString() ??
          '';
      int? year;
      if (date.length >= 4) year = int.tryParse(date.substring(0, 4));
      out.add(TmdbRecommendation(
        tmdbId: id,
        isMovie: isMovie,
        title: title,
        originalTitle: originalTitle.isEmpty ? null : originalTitle,
        year: year,
        posterUrl: _img(e['poster_path']?.toString(), 'w342'),
        rating: _toDouble(e['vote_average']),
      ));
      if (out.length >= 20) break;
    }
    return out;
  }

  List<TmdbReview> _reviews(dynamic raw) {
    if (raw is! Map) return const [];
    final results = (raw['results'] as List?) ?? const [];
    final out = <TmdbReview>[];
    for (final e in results.whereType<Map>()) {
      final id = (e['id'] ?? '').toString();
      final author = (e['author'] ?? '').toString();
      final content = (e['content'] ?? '').toString().trim();
      if (id.isEmpty || content.isEmpty) continue;
      final ad = e['author_details'];
      double? rating;
      String? avatar;
      if (ad is Map) {
        rating = _toDouble(ad['rating']);
        final ap = ad['avatar_path']?.toString();
        if (ap != null && ap.isNotEmpty) {
          // TMDB avatar_path sometimes wraps the Gravatar URL as
          // "/https://..."; in that case drop the leading slash.
          if (ap.startsWith('/http')) {
            avatar = ap.substring(1);
          } else {
            avatar = _img(ap, 'w185');
          }
        }
      }
      out.add(TmdbReview(
        id: id,
        author: author.isEmpty ? 'Anonymous' : author,
        content: content,
        rating: rating,
        createdAt: e['created_at']?.toString(),
        avatarUrl: avatar,
      ));
      if (out.length >= 10) break;
    }
    return out;
  }

  String? _imdbId(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['imdb_id']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String? _movieCountries(dynamic raw, String language) {
    if (raw is! List) return null;
    final names = <String>[];
    for (final e in raw.whereType<Map>()) {
      final iso = (e['iso_3166_1'] ?? '').toString().trim();
      // Use the localized name for the ISO if one exists; otherwise fall
      // back to the English `name` that TMDB sends.
      if (iso.isNotEmpty) {
        final localized = CountryNames.lookup(iso, locale: language);
        if (localized != null) {
          names.add(localized);
          continue;
        }
      }
      final name = (e['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        names.add(name);
      } else if (iso.isNotEmpty) {
        names.add(iso);
      }
    }
    if (names.isEmpty) return null;
    return names.take(3).join(', ');
  }

  /// TV detail `origin_country` payload is a list of ISO 3166-1 alpha-2
  /// codes ("US", "TR", ...). Translate to a localized name ("ABD" in
  /// TR, "United States" in EN); for unknown codes show the ISO as-is.
  /// Skip null elements in the payload - TMDB rarely puts `null` there,
  /// but even if it does in Dio's JSON parse, let's not throw an NPE.
  String? _tvCountries(dynamic raw, String language) {
    if (raw is! List) return null;
    final out = <String>[];
    for (final c in raw) {
      if (c == null) continue;
      final iso = c.toString().trim().toUpperCase();
      if (iso.isEmpty) continue;
      out.add(CountryNames.forCode(iso, locale: language));
    }
    if (out.isEmpty) return null;
    return out.take(3).join(', ');
  }

  // TMDB `images` payload: pick backdrops first (16:9, gallery-friendly),
  // fall back to posters if a title has only key art. Sorted by TMDB's
  // vote_average so the strongest art surfaces first.
  List<String> _gallery(dynamic images) {
    if (images is! Map) return const [];
    List<Map> _list(String key) =>
        (images[key] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final backdrops = _list('backdrops');
    final posters = _list('posters');
    final pool = backdrops.isNotEmpty ? backdrops : posters;
    pool.sort((a, b) {
      final av = (a['vote_average'] as num?)?.toDouble() ?? 0;
      final bv = (b['vote_average'] as num?)?.toDouble() ?? 0;
      return bv.compareTo(av);
    });
    final size = backdrops.isNotEmpty ? 'w780' : 'w500';
    return pool
        .map((m) => _img(m['file_path']?.toString(), size))
        .whereType<String>()
        .take(20)
        .toList();
  }

  // TMDB returns one entry per release_dates.results country, each with a list
  // of certification strings. Prefer the user's region, fall back to US, then
  // to anything non-empty.
  String? _movieCert(dynamic releaseDates, String region) {
    final results = (releaseDates is Map)
        ? (releaseDates['results'] as List?) ?? const []
        : const [];
    String? pick(String iso) {
      for (final r in results.whereType<Map>()) {
        if ((r['iso_3166_1'] ?? '').toString().toUpperCase() ==
            iso.toUpperCase()) {
          final dates = (r['release_dates'] as List?) ?? const [];
          for (final d in dates.whereType<Map>()) {
            final c = (d['certification'] ?? '').toString().trim();
            if (c.isNotEmpty) return c;
          }
        }
      }
      return null;
    }

    return pick(region) ?? pick('US') ?? pick('GB');
  }

  String? _tvCert(dynamic contentRatings, String region) {
    final results = (contentRatings is Map)
        ? (contentRatings['results'] as List?) ?? const []
        : const [];
    String? pick(String iso) {
      for (final r in results.whereType<Map>()) {
        if ((r['iso_3166_1'] ?? '').toString().toUpperCase() ==
            iso.toUpperCase()) {
          final c = (r['rating'] ?? '').toString().trim();
          if (c.isNotEmpty) return c;
        }
      }
      return null;
    }

    return pick(region) ?? pick('US') ?? pick('GB');
  }

  List<String> _topCast(Map? credits) {
    if (credits == null) return const [];
    final cast = (credits['cast'] as List?) ?? const [];
    return cast
        .whereType<Map>()
        .map((c) => (c['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .take(10)
        .toList();
  }

  List<String> _directors(Map? credits) {
    if (credits == null) return const [];
    final crew = (credits['crew'] as List?) ?? const [];
    return crew
        .whereType<Map>()
        .where((c) => (c['job'] ?? '').toString() == 'Director')
        .map((c) => (c['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String? _img(String? path, String size) {
    if (path == null || path.isEmpty) return null;
    return '$_imgBase/$size$path';
  }

  String? _orNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s;

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

enum TmdbVerifyResult { ok, invalid, empty, networkError }

class TmdbDetail {
  final int tmdbId;
  final String? title;
  final String? originalTitle;
  final String? overview;
  final List<String> genres;
  final String? certification;
  final double? rating;
  final String? backdropUrl;
  final String? posterUrl;
  final String? releaseDate;
  final List<String> cast;
  final List<String> directors;
  final List<String> gallery;
  final List<TmdbVideo> trailers;
  final String? youtubeTrailerKey;
  /// Localized country labels. Resolved from `production_countries` ISO
  /// codes for movies and `origin_country` for TV. When the IPTV panel's
  /// `country` field is empty, the UI uses this as a fallback.
  final String? country;
  /// TMDB keywords - a sharper signal than genre ("alien-invasion",
  /// "heist-gone-wrong"). The main feature set of the personalized
  /// recommendation engine.
  final List<String> keywords;
  /// TMDB's "watch something similar" suggestions. Each entry holds a
  /// tmdbId + title + poster; the app maps these to the catalog and
  /// feeds them as raw candidates into the "For you" row.
  final List<TmdbRecommendation> recommendations;
  /// User/critic reviews from TMDB. Shown in the UI's "Reviews"
  /// section; it doesn't mix into the AI recommendation's user reviews
  /// (our own reviews are held by UserRatings).
  final List<TmdbReview> reviews;
  /// IMDB ID - not used in the UI right now, but we keep it to bridge to
  /// other sources like RT/Letterboxd in the future.
  final String? imdbId;

  const TmdbDetail({
    required this.tmdbId,
    this.title,
    this.originalTitle,
    this.overview,
    this.genres = const [],
    this.certification,
    this.rating,
    this.backdropUrl,
    this.posterUrl,
    this.releaseDate,
    this.cast = const [],
    this.directors = const [],
    this.gallery = const [],
    this.trailers = const [],
    this.youtubeTrailerKey,
    this.country,
    this.keywords = const [],
    this.recommendations = const [],
    this.reviews = const [],
    this.imdbId,
  });
}

/// A single TMDB review row. `rating` is the author's own score (null
/// if absent); content can be long, shown with expand/collapse in the UI.
class TmdbReview {
  final String id;
  final String author;
  final String content;
  final double? rating;
  final String? createdAt;
  final String? avatarUrl;
  const TmdbReview({
    required this.id,
    required this.author,
    required this.content,
    this.rating,
    this.createdAt,
    this.avatarUrl,
  });
}

/// "Watch something similar" candidates. Not shown raw on the detail
/// page; the recommendation engine maps them to the catalog and scores them.
class TmdbRecommendation {
  final int tmdbId;
  final bool isMovie;
  final String title;
  final String? originalTitle;
  final int? year;
  final String? posterUrl;
  final double? rating;
  const TmdbRecommendation({
    required this.tmdbId,
    required this.isMovie,
    required this.title,
    this.originalTitle,
    this.year,
    this.posterUrl,
    this.rating,
  });
}

class TmdbPerson {
  final int tmdbId;
  final String name;
  final String? biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final String? knownForDepartment;
  final String? profileUrl;
  final List<TmdbPersonCredit> filmography;
  /// TMDB-coded gender: 0 = not specified, 1 = female, 2 = male, 3 = non-binary.
  final int gender;
  final List<String> alsoKnownAs;
  const TmdbPerson({
    required this.tmdbId,
    required this.name,
    this.biography,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.knownForDepartment,
    this.profileUrl,
    this.filmography = const [],
    this.gender = 0,
    this.alsoKnownAs = const [],
  });

  /// Best-effort age in whole years. Uses [deathday] when available so
  /// posthumous credits aren't shown with a constantly-aging number.
  int? get age {
    final birth = _parseYmd(birthday);
    if (birth == null) return null;
    final end = _parseYmd(deathday) ?? DateTime.now();
    int years = end.year - birth.year;
    if (end.month < birth.month ||
        (end.month == birth.month && end.day < birth.day)) {
      years -= 1;
    }
    return years < 0 ? null : years;
  }

  static DateTime? _parseYmd(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }
}

class TmdbPersonCredit {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final String? character;
  final String? posterUrl;
  final String? releaseDate;
  final double popularity;
  const TmdbPersonCredit({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.character,
    this.posterUrl,
    this.releaseDate,
    this.popularity = 0,
  });
}

class TmdbVideo {
  final String key;
  final String name;
  final String type;
  final bool official;
  const TmdbVideo({
    required this.key,
    required this.name,
    required this.type,
    required this.official,
  });

  /// Stable YouTube CDN thumbnail derived from the key. `hqdefault` (480x360)
  /// is the highest-resolution variant that's guaranteed to exist for every
  /// upload.
  String get thumbnailUrl => 'https://img.youtube.com/vi/$key/hqdefault.jpg';
  String get watchUrl => 'https://www.youtube.com/watch?v=$key';
}

class TmdbSearchHit {
  final int? tmdbId;
  final String title;
  final String originalTitle;
  final int? year;
  final bool isMovie;
  final String? posterUrl;
  final double? rating;
  const TmdbSearchHit({
    required this.title,
    required this.originalTitle,
    required this.year,
    required this.isMovie,
    this.tmdbId,
    this.posterUrl,
    this.rating,
  });
}

class TmdbEpisode {
  final int episodeNumber;
  final String? name;
  final String? overview;
  final String? stillUrl;
  final String? airDate;
  const TmdbEpisode({
    required this.episodeNumber,
    this.name,
    this.overview,
    this.stillUrl,
    this.airDate,
  });
}
