import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/i18n.dart';
import '../network/dio_client.dart';
import '../../features/settings/providers/adult_filter_provider.dart'
    as adult;
import '../../features/settings/providers/tmdb_credentials_provider.dart';
import '../../features/sources/domain/media_item.dart';
import 'tmdb_overrides_provider.dart';
import 'tmdb_service.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  final key = ref.watch(tmdbApiKeyProvider).value ?? '';
  return TmdbService(dio: ref.watch(dioProvider), apiKey: key);
});

class TmdbLookupArgs {
  final String sourceId;
  final String streamId;
  final String name;
  final int? year;
  final MediaKind kind;
  /// Item lives in an XXX/porn/etc. category. Skip TMDB entirely -
  /// those titles never have legitimate matches, the API calls just
  /// burn rate limit and never resolve to a poster.
  final bool isAdult;
  const TmdbLookupArgs({
    required this.sourceId,
    required this.streamId,
    required this.name,
    required this.kind,
    this.year,
    this.isAdult = false,
  });

  factory TmdbLookupArgs.fromItem(MediaItem item) => TmdbLookupArgs(
        sourceId: item.sourceId,
        streamId: item.streamId,
        name: item.name,
        // Xtream `year` is often missing for classic catalogs - fall
        // back to a year embedded in the title ("Superman (1978)",
        // "Inception 2010") so TMDB search can disambiguate by year.
        year: item.year ?? _extractYear(item.name),
        kind: item.kind,
        isAdult: adult.isAdult(item),
      );

  @override
  bool operator ==(Object other) =>
      other is TmdbLookupArgs &&
      other.sourceId == sourceId &&
      other.streamId == streamId &&
      other.kind == kind &&
      other.isAdult == isAdult;

  @override
  int get hashCode => Object.hash(sourceId, streamId, kind, isAdult);
}

/// Localized metadata for a [MediaItem]. Watches [localeProvider] so the
/// query re-fires with the new language/region whenever the user switches
/// the UI language (cached results from the previous locale are dropped
/// because the family key is stable but the watched dependency invalidates).
final tmdbDetailProvider =
    FutureProvider.autoDispose.family<TmdbDetail?, TmdbLookupArgs>(
        (ref, args) async {
  final svc = ref.watch(tmdbServiceProvider);
  if (!svc.enabled) return null;
  if (args.kind == MediaKind.live) return null;
  // Adult titles never match anything sensible on TMDB; skipping the
  // call saves HTTP traffic and avoids burning the rate-limit budget.
  if (args.isAdult) return null;
  final locale = ref.watch(localeProvider).value?.code ?? 'en';
  final language = _tmdbLanguage(locale);
  final region = _tmdbRegion(locale);
  final isMovie = args.kind == MediaKind.movie;
  // Manual override: if the user picked a different movie/series for this
  // item via the TMDB picker, skip search and fetch that id directly.
  final overrides = ref.watch(tmdbOverridesProvider).value;
  final compositeId = MediaItem.makeId(args.sourceId, args.streamId);
  final override = overrides?[compositeId];
  if (override != null) {
    final detail = override.isMovie
        ? await svc.fetchMovieById(override.tmdbId,
            language: language, region: region)
        : await svc.fetchTvById(override.tmdbId,
            language: language, region: region);
    if (detail != null) {
      bool hasText(String? s) => s != null && s.trim().isNotEmpty;
      final needsFallback = language != 'en-US' &&
          (!hasText(detail.title) ||
              !hasText(detail.overview) ||
              detail.gallery.isEmpty ||
              detail.trailers.isEmpty ||
              detail.reviews.isEmpty);
      if (!needsFallback) {
        ref.keepAlive();
        return detail;
      }
      final en = override.isMovie
          ? await svc.fetchMovieById(override.tmdbId,
              language: 'en-US', region: region)
          : await svc.fetchTvById(override.tmdbId,
              language: 'en-US', region: region);
      ref.keepAlive();
      return en == null ? detail : svc.mergeLocaleFallback(detail, en);
    }
    // Override fetch failed → fall back to the normal lookup.
  }
  final cleaned = cleanTitle(args.name);
  if (cleaned.isEmpty) return null;
  Future<TmdbDetail?> doSearch(String lang, String query) => isMovie
      ? svc.lookupMovie(
          query: query,
          year: args.year,
          language: lang,
          region: region,
        )
      : svc.lookupTv(
          query: query,
          year: args.year,
          language: lang,
          region: region,
        );
  // Localized search misses for brand-new titles that have only an
  // English entry on TMDB so far - retry in en-US so we still get the
  // canonical record (the per-field locale fallback below will then
  // back-fill anything that ends up missing).
  var localized = await doSearch(language, cleaned);
  if (localized == null && language != 'en-US') {
    localized = await doSearch('en-US', cleaned);
  }
  // Second pass: the scene-release cleaner may miss some leftovers
  // (e.g. residue after "AC3.5.1.DuaL"). Retry with the strict variant,
  // trimming the title down to the first year token. For long-named films
  // like Star Wars this can be the only trigger that makes a difference.
  if (localized == null) {
    final strict = cleanTitleStrict(args.name);
    if (strict.isNotEmpty && strict != cleaned) {
      // ignore: avoid_print
      print('[TMDB] fallback strict clean: "$strict" (from "${args.name}")');
      localized = await doSearch(language, strict);
      if (localized == null && language != 'en-US') {
        localized = await doSearch('en-US', strict);
      }
    }
  }
  if (localized == null) return null;
  // If the user's locale left core fields blank (TMDB has partial
  // translations for plenty of older titles) fetch the canonical English
  // record by id and fill the gaps - UI text never collapses to "no
  // description" just because the localized response was thin.
  bool _hasText(String? s) => s != null && s.trim().isNotEmpty;
  // Reviews are rarely populated in the TR locale - TMDB's Turkish
  // translations are minimal. Pulling the EN fallback makes the reviews
  // section genuinely useful for most films. Core fields like title/
  // overview were already covered; adding reviews means fewer empty tabs.
  final needsFallback = language != 'en-US' &&
      (!_hasText(localized.title) ||
          !_hasText(localized.overview) ||
          localized.gallery.isEmpty ||
          localized.trailers.isEmpty ||
          localized.reviews.isEmpty);
  if (!needsFallback) {
    // Keep the loaded record alive for the rest of the session. Without
    // this, scrolling a card off-screen disposes the provider; scrolling
    // back re-fires the TMDB fetch and the poster blinks while the new
    // image decodes. The result is tiny (a few KB), so the memory cost
    // is negligible. Locale switches still invalidate via the watched
    // `localeProvider` dependency.
    ref.keepAlive();
    return localized;
  }
  final en = isMovie
      ? await svc.fetchMovieById(localized.tmdbId,
          language: 'en-US', region: region)
      : await svc.fetchTvById(localized.tmdbId,
          language: 'en-US', region: region);
  if (en == null) {
    ref.keepAlive();
    return localized;
  }
  ref.keepAlive();
  return svc.mergeLocaleFallback(localized, en);
});

/// Layer a TMDB lookup on top of the source's own metadata. The source
/// (Xtream / M3U) wins for every field where it has content - TMDB only
/// fills gaps. This matches the user's preference of treating IPTV-supplied
/// plots/cast as authoritative and only using TMDB as enrichment.
/// Certification has no source-side analogue so it always comes from TMDB.
///
/// [preferTmdb]: set to true when the user made a manual TMDB override.
/// In that case the "source wins" policy is reversed - every field like
/// cast, director, plot, year, and genre comes from TMDB; the panel
/// metadata is only a fallback when that field is empty on TMDB.
/// Otherwise the override loses its meaning (the user says "this is a
/// different film" but the cast still shows the wrong panel's actors).
MediaDetail mergeWithTmdb(
  MediaDetail base,
  TmdbDetail? tmdb, {
  bool preferTmdb = false,
}) {
  if (tmdb == null) return base;
  bool hasText(String? s) => s != null && s.trim().isNotEmpty;
  if (preferTmdb) {
    return MediaDetail(
      cast: tmdb.cast.isNotEmpty ? tmdb.cast : base.cast,
      directors:
          tmdb.directors.isNotEmpty ? tmdb.directors : base.directors,
      genres: tmdb.genres.isNotEmpty ? tmdb.genres : base.genres,
      // runtimeSeconds still from base - TMDB only gives minutes and the
      // panel's real file duration is more accurate for the player.
      runtimeSeconds: base.runtimeSeconds,
      releaseDate:
          hasText(tmdb.releaseDate) ? tmdb.releaseDate : base.releaseDate,
      country: hasText(tmdb.country) ? tmdb.country : base.country,
      gallery: tmdb.gallery.isNotEmpty ? tmdb.gallery : base.gallery,
      youtubeTrailer: hasText(tmdb.youtubeTrailerKey)
          ? tmdb.youtubeTrailerKey
          : base.youtubeTrailer,
      imdbId: tmdb.imdbId ?? base.imdbId,
      keywords: tmdb.keywords.isNotEmpty ? tmdb.keywords : base.keywords,
      rating: tmdb.rating ?? base.rating,
      plot: hasText(tmdb.overview) ? tmdb.overview : base.plot,
      coverUrl: hasText(tmdb.posterUrl) ? tmdb.posterUrl : base.coverUrl,
      backdropUrl:
          hasText(tmdb.backdropUrl) ? tmdb.backdropUrl : base.backdropUrl,
      certification: tmdb.certification,
      originalTitle: hasText(tmdb.originalTitle)
          ? tmdb.originalTitle
          : base.originalTitle,
      localizedTitle:
          hasText(tmdb.title) ? tmdb.title : base.localizedTitle,
    );
  }
  return MediaDetail(
    cast: base.cast.isNotEmpty ? base.cast : tmdb.cast,
    directors: base.directors.isNotEmpty ? base.directors : tmdb.directors,
    genres: base.genres.isNotEmpty ? base.genres : tmdb.genres,
    runtimeSeconds: base.runtimeSeconds,
    releaseDate:
        hasText(base.releaseDate) ? base.releaseDate : tmdb.releaseDate,
    // The IPTV panel leaves the country field empty very often; patch it
    // with TMDB production_countries / origin_country as a fallback.
    country: hasText(base.country) ? base.country : tmdb.country,
    // Artwork policy: TMDB wins outright for posters/backdrops/galleries.
    // Xtream / M3U panels often surface heavily cropped or low-res cover
    // art (or empty strings that masquerade as URLs), so we sidestep them
    // entirely whenever TMDB has the real thing. Plot/cast/director still
    // honor the source-first rule above.
    gallery: tmdb.gallery.isNotEmpty ? tmdb.gallery : base.gallery,
    youtubeTrailer: hasText(base.youtubeTrailer)
        ? base.youtubeTrailer
        : tmdb.youtubeTrailerKey,
    imdbId: base.imdbId ?? tmdb.imdbId,
    keywords: base.keywords.isNotEmpty ? base.keywords : tmdb.keywords,
    // Xtream panels routinely surface `rating=0` for titles they don't
    // have a real score for. Treat that as "no rating" and prefer the
    // TMDB score, which is essentially always populated.
    rating: (base.rating != null && base.rating! > 0)
        ? base.rating
        : tmdb.rating,
    plot: hasText(base.plot) ? base.plot : tmdb.overview,
    coverUrl: hasText(tmdb.posterUrl) ? tmdb.posterUrl : base.coverUrl,
    backdropUrl:
        hasText(tmdb.backdropUrl) ? tmdb.backdropUrl : base.backdropUrl,
    certification: tmdb.certification,
    // So the search index can also match on alternate titles, we carry
    // TMDB's original + localized titles into the merge.
    originalTitle: hasText(base.originalTitle)
        ? base.originalTitle
        : tmdb.originalTitle,
    localizedTitle:
        hasText(base.localizedTitle) ? base.localizedTitle : tmdb.title,
  );
}

class TmdbSeasonArgs {
  final int tmdbId;
  final int seasonNumber;
  const TmdbSeasonArgs({required this.tmdbId, required this.seasonNumber});

  @override
  bool operator ==(Object other) =>
      other is TmdbSeasonArgs &&
      other.tmdbId == tmdbId &&
      other.seasonNumber == seasonNumber;

  @override
  int get hashCode => Object.hash(tmdbId, seasonNumber);
}

/// TMDB person lookup keyed by actor display name. Searches first to find
/// the canonical id, then pulls the full record (bio + combined credits).
/// Locale-aware so the bio comes back in the user's UI language when TMDB
/// has a translation.
final tmdbPersonProvider =
    FutureProvider.autoDispose.family<TmdbPerson?, String>((ref, name) async {
  final svc = ref.watch(tmdbServiceProvider);
  if (!svc.enabled) return null;
  final locale = ref.watch(localeProvider).value?.code ?? 'en';
  final language = _tmdbLanguage(locale);
  final localized = await svc.lookupPerson(query: name, language: language);
  if (localized == null) return null;
  // Bio frequently missing in non-English locales - fill from en-US.
  if (language != 'en-US' &&
      (localized.biography == null || localized.biography!.trim().isEmpty)) {
    final en = await svc.fetchPersonById(localized.tmdbId, language: 'en-US');
    if (en != null && en.biography != null && en.biography!.isNotEmpty) {
      return TmdbPerson(
        tmdbId: localized.tmdbId,
        name: localized.name,
        biography: en.biography,
        birthday: localized.birthday ?? en.birthday,
        deathday: localized.deathday ?? en.deathday,
        placeOfBirth: localized.placeOfBirth ?? en.placeOfBirth,
        knownForDepartment:
            localized.knownForDepartment ?? en.knownForDepartment,
        profileUrl: localized.profileUrl ?? en.profileUrl,
        filmography: localized.filmography.isNotEmpty
            ? localized.filmography
            : en.filmography,
        gender: localized.gender != 0 ? localized.gender : en.gender,
        alsoKnownAs: localized.alsoKnownAs.isNotEmpty
            ? localized.alsoKnownAs
            : en.alsoKnownAs,
      );
    }
  }
  return localized;
});

/// TMDB metadata for every episode of one season, keyed by episode number.
/// Locale-aware: same `localeProvider` dependency invalidates the cache so
/// switching language re-fetches in the new tongue.
final tmdbSeasonProvider =
    FutureProvider.autoDispose.family<Map<int, TmdbEpisode>, TmdbSeasonArgs>(
        (ref, args) async {
  final svc = ref.watch(tmdbServiceProvider);
  if (!svc.enabled) return const {};
  final locale = ref.watch(localeProvider).value?.code ?? 'en';
  final language = _tmdbLanguage(locale);
  return svc.getTvSeason(
    tmdbId: args.tmdbId,
    seasonNumber: args.seasonNumber,
    language: language,
  );
});

/// Finds a Latin alias from TMDB's `also_known_as` list so actor names
/// can appear in ASCII / Latin form. Some IPTV panels and TMDB localized
/// cast responses return names with Chinese / Korean / Japanese
/// characters; the user wants Latin letters in the UI, so this provider
/// does a background lookup and returns the first Latin alias. Inputs that
/// are already Latin return [name] instantly (no HTTP call). If the API
/// key is missing or the person isn't found, the original value is returned.
final latinizedNameProvider =
    FutureProvider.autoDispose.family<String, String>((ref, name) async {
  if (_isLatinish(name)) return name;
  final svc = ref.watch(tmdbServiceProvider);
  if (!svc.enabled) return name;
  final locale = ref.watch(localeProvider).value?.code ?? 'en';
  final language = _tmdbLanguage(locale);
  // Try the user's locale first (TMDB can return "Jackie Chan" in a
  // tr-TR response); on failure fall back to en-US - the Latin alias is
  // most reliably found there.
  var person = await svc.lookupPerson(query: name, language: language);
  if (person == null && language != 'en-US') {
    person = await svc.lookupPerson(query: name, language: 'en-US');
  }
  if (person == null) return name;
  // 1) The first Latin form inside `also_known_as`.
  for (final alias in person.alsoKnownAs) {
    if (_isLatinish(alias)) {
      // Cache the first match and keep it a long time - actor names are stable.
      ref.keepAlive();
      return alias;
    }
  }
  // 2) If the person's canonical `name` is already Latin, use it.
  if (_isLatinish(person.name)) {
    ref.keepAlive();
    return person.name;
  }
  // 3) If there is no Latin alias, return the original - at least the
  //    chip won't be empty.
  return name;
});

/// Checks character by character whether the string lies in the Latin /
/// extended-Latin range. Combining marks (accents), spaces, digits,
/// common punctuation and a few typographic characters (smart quote,
/// en/em dash) count as Latin; CJK / Cyrillic / Arabic blocks are rejected.
bool _isLatinish(String s) {
  for (final ch in s.runes) {
    if (ch <= 0x00FF) continue; // Latin-1 Supplement (é, ñ, à ...)
    if (ch <= 0x024F) continue; // Latin Extended-A/B
    if (ch <= 0x02AF) continue; // IPA / spacing
    if (ch == 0x2019 || ch == 0x2018) continue; // smart quote
    if (ch == 0x2013 || ch == 0x2014) continue; // en/em dash
    return false;
  }
  return true;
}

/// TMDB multi-search for a user search query. When the local item catalog
/// says "Kara Kule" but the user types "Dark Tower", TMDB returns both the
/// original and localized title; the search page takes this output and
/// fuzzy-matches it against the local item name to catch hidden matches.
/// Returns an empty list for empty / short queries or a missing API key.
final tmdbQuerySearchProvider = FutureProvider.autoDispose
    .family<List<TmdbSearchHit>, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.length < 3) return const [];
  final svc = ref.watch(tmdbServiceProvider);
  if (!svc.enabled) return const [];
  final locale = ref.watch(localeProvider).value?.code ?? 'en';
  final language = _tmdbLanguage(locale);
  return svc.searchMulti(query: trimmed, language: language);
});

/// Map the app locale code ('tr', 'en', …) to a TMDB `language` value.
/// TMDB accepts the BCP-47-ish `xx-XX` form; anything else falls back to
/// `en-US`.
String _tmdbLanguage(String code) {
  switch (code.toLowerCase()) {
    case 'tr':
      return 'tr-TR';
    case 'en':
      return 'en-US';
    case 'de':
      return 'de-DE';
    case 'fr':
      return 'fr-FR';
    case 'es':
      return 'es-ES';
    case 'pt':
      return 'pt-PT';
    case 'ru':
      return 'ru-RU';
    case 'ar':
      return 'ar-SA';
    default:
      return 'en-US';
  }
}

/// ISO 3166-1 region used for picking the right age certification. Defaults
/// to the locale's native country; for English we use US since that's the
/// most well-populated certification set in TMDB.
String _tmdbRegion(String code) {
  switch (code.toLowerCase()) {
    case 'tr':
      return 'TR';
    case 'en':
      return 'US';
    case 'de':
      return 'DE';
    case 'fr':
      return 'FR';
    case 'es':
      return 'ES';
    case 'pt':
      return 'PT';
    case 'ru':
      return 'RU';
    case 'ar':
      return 'SA';
    default:
      return 'US';
  }
}

/// Pull a 4-digit release year out of an IPTV title. Catalogs embed it
/// as "Title (1978)", "Title 2010", or "Title - 1999"; we use it as a
/// year hint when the source-level `year` field is missing. Any 4-digit
/// run that falls into the (1900, currentYear + 2) window counts -
/// anything outside that range is almost certainly an unrelated number
/// in the title.
int? _extractYear(String raw) {
  // Normalize separators first so dotted scene-style names like
  // "Mission.Impossible.1.1996.REMASTERED" surface the year.
  final normalized = raw.replaceAll(RegExp(r'[._]'), ' ');
  final maxYear = DateTime.now().year + 2;
  for (final m in RegExp(r'\b\d{4}\b').allMatches(normalized)) {
    final y = int.tryParse(m.group(0)!);
    if (y == null) continue;
    if (y > 1900 && y < maxYear) return y;
  }
  return null;
}

/// IPTV catalog names range from clean ("Inception (2010)") to full
/// scene-release filenames ("Mission.Impossible.1.1996.REMASTERED.m1080p
/// .BluRay.H264.DUAL"). Strip separators, release tags, codec/quality
/// markers, and trailing release-group suffixes so the bare title hits
/// TMDB cleanly.
String cleanTitle(String raw) {
  var s = raw;
  // First the audio channel-layout notations: strip patterns like
  // AC3.5.1 / DTS.7.1 / DD.2.0 in one shot (before the dots become
  // spaces). Otherwise "AC3 5 1" gets split and "5 1" escapes cleanup,
  // turning the TMDB query into nonsense like "Title 5 1".
  s = s.replaceAll(
    RegExp(
      r'\b(ac3|dts|dd|ddp|truehd|atmos|aac|eac3|opus|flac)[.\s_-]?[257][.\s_-][012]\b',
      caseSensitive: false,
    ),
    ' ',
  );
  // The same channel-layout expressions (5.1, 7.1, 2.0, 5 1, 7 1) can
  // also appear without an audio-format tag. Catch the standalone
  // 5.1 / 7.1 format too.
  s = s.replaceAll(
    RegExp(r'\b[257][.\s_-][012]\b'),
    ' ',
  );
  // Filename-style separators → spaces. Without this, dots between
  // words leave word boundaries oddly placed and most tag matches miss.
  s = s.replaceAll(RegExp(r'[._]'), ' ');
  // Drop bracketed segments like "(2010)", "[4K]", "{HDR}".
  s = s.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]'), ' ');
  // Drop a 4-digit year wherever it appears, but only if it falls in
  // the plausible release-year window (1900, currentYear + 2). Random
  // 4-digit numbers in titles ("Apollo 13" is 4 digits if you count
  // the surrounding context badly) are left alone.
  final maxYear = DateTime.now().year + 2;
  s = s.replaceAllMapped(RegExp(r'\b\d{4}\b'), (m) {
    final y = int.tryParse(m.group(0)!) ?? 0;
    return (y > 1900 && y < maxYear) ? ' ' : m.group(0)!;
  });
  // Drop resolution markers including the scene "m1080p" / "m720p"
  // variants that the static tag list below would miss.
  s = s.replaceAll(
      RegExp(r'\bm?\d{3,4}p\b', caseSensitive: false), ' ');
  // Drop re-encode version markers ("v2", "v3") that scene releases
  // append after the codec/quality tags. Leaving them in turned a TMDB
  // search for "The Expendables 3" into "The Expendables 3 v2" which
  // returns zero results.
  s = s.replaceAll(
      RegExp(r'\bv\d{1,2}\b', caseSensitive: false), ' ');
  // Drop common quality / language / release tags wherever they appear.
  const tags = [
    '4k', 'uhd', 'fhd', 'hd', 'sd', 'hdr', 'dv', 'imax',
    'bluray', 'blu-ray', 'bdrip', 'brrip', 'webrip', 'web-dl', 'webdl',
    'hdrip', 'hdcam', 'cam', 'ts', 'dvdrip', 'remux',
    'x264', 'x265', 'hevc', 'h264', 'h265', '10bit', '8bit',
    'aac', 'ac3', 'dd5', 'dts', 'ddp', 'ddp5', 'atmos', 'truehd',
    'eac3', 'opus', 'flac',
    'remastered', 'extended', 'unrated', 'directors', 'cut',
    'proper', 'repack', 'internal', 'limited', 'retail',
    'dublaj', 'dub', 'dubbed', 'altyazi', 'altyazılı', 'altyazili', 'sub',
    'subbed', 'turkce', 'türkçe', 'english', 'eng', 'multi', 'multi-audio',
    'dual', 'nf', 'amzn', 'dsnp', 'hulu', 'hbo',
  ];
  for (final t in tags) {
    s = s.replaceAll(
        RegExp(r'\b' + RegExp.escape(t) + r'\b', caseSensitive: false), ' ');
  }
  // Drop trailing release-group suffix ("-DuaL", "-NGR", "-PROGRESS.HDM").
  s = s.replaceAll(RegExp(r'\s*-\s*[A-Za-z0-9.]+\s*$'), ' ');
  // Drop trailing language separators ("- TR", " | EN", etc.).
  s = s.replaceAll(RegExp(r'[\-\|:]+\s*$'), ' ');
  // Collapse whitespace.
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Aggressive fallback: take the part up to the first year token and drop
/// the rest entirely. In scene-release filenames the year usually sits
/// right after the real title ("Star.Wars.Episode.III.Revenge.of.the.
/// Sith.2005...") - it is the safest boundary hint. Used when the first
/// `_cleanTitle` attempt fails.
String cleanTitleStrict(String raw) {
  // Normalize the separators first.
  var s = raw.replaceAll(RegExp(r'[._]'), ' ');
  s = s.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]'), ' ');
  final maxYear = DateTime.now().year + 2;
  // Find the position of the first year token.
  final yearMatch = RegExp(r'\b(\d{4})\b').firstMatch(s);
  if (yearMatch != null) {
    final y = int.tryParse(yearMatch.group(1)!) ?? 0;
    if (y > 1900 && y < maxYear) {
      s = s.substring(0, yearMatch.start);
    }
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
