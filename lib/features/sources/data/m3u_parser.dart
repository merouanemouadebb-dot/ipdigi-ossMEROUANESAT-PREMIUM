import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/media_item.dart';

class M3uEntry {
  final String name;
  final String url;
  final String? tvgId;
  final String? tvgName;
  final String? logo;
  final String? groupTitle;

  const M3uEntry({
    required this.name,
    required this.url,
    this.tvgId,
    this.tvgName,
    this.logo,
    this.groupTitle,
  });
}

class M3uParseResult {
  final List<M3uEntry> entries;
  const M3uParseResult(this.entries);
}

class M3uParser {
  static final RegExp _attrRegex = RegExp(r'([a-zA-Z0-9\-]+)="([^"]*)"');

  static M3uParseResult parse(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final entries = <M3uEntry>[];

    String? pendingName;
    Map<String, String> pendingAttrs = const {};

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTM3U')) continue;

      if (line.startsWith('#EXTINF')) {
        final commaIndex = line.indexOf(',');
        final attrsPart = commaIndex >= 0
            ? line.substring(0, commaIndex)
            : line;
        final namePart = commaIndex >= 0
            ? line.substring(commaIndex + 1).trim()
            : '';
        pendingAttrs = {
          for (final m in _attrRegex.allMatches(attrsPart))
            m.group(1)!.toLowerCase(): m.group(2)!,
        };
        pendingName = namePart;
        continue;
      }

      if (line.startsWith('#')) continue;

      if (pendingName != null) {
        entries.add(
          M3uEntry(
            name: pendingName,
            url: line,
            tvgId: pendingAttrs['tvg-id'],
            tvgName: pendingAttrs['tvg-name'],
            logo: pendingAttrs['tvg-logo'],
            groupTitle: pendingAttrs['group-title'],
          ),
        );
        pendingName = null;
        pendingAttrs = const {};
      }
    }
    return M3uParseResult(entries);
  }

  static String _hash(String s) => md5.convert(utf8.encode(s)).toString();

  static List<MediaItem> toMediaItems(String sourceId, M3uParseResult parsed) {
    final items = <MediaItem>[];
    // Flat M3U lists each series episode as its own entry. Collapse them into
    // one container per series (shown in the grid) plus hidden episode rows.
    final containers = <String, MediaItem>{};
    for (final e in parsed.entries) {
      final kind = _inferKind(e.url, e.groupTitle);
      final name = e.name.isEmpty ? (e.tvgName ?? 'Unnamed') : e.name;
      // Most panels emit tvg-id="" (empty, not absent) on VOD/series entries.
      // An empty string is not null, so "tvgId ?? url" would keep "" and every
      // entry would collapse to the same id (sourceId|""), wiping the whole
      // catalog down to a single row on insertOrReplace. Treat empty as absent.
      final tvgId = (e.tvgId == null || e.tvgId!.isEmpty) ? null : e.tvgId;

      if (kind == MediaKind.series) {
        final ep = parseEpisodeNaming(name);
        // Groupable episodes share a key derived from the series title;
        // unparseable series entries get a per-URL key (stand alone, one
        // episode each) so they still open and play.
        final seriesKey = ep != null
            ? _hash('series:${ep.title.toLowerCase()}')
            : _hash('series:${e.url}');
        final seriesTitle = ep?.title ?? name;
        containers.putIfAbsent(
          seriesKey,
          () => MediaItem(
            id: MediaItem.makeId(sourceId, seriesKey),
            sourceId: sourceId,
            streamId: seriesKey,
            name: seriesTitle,
            // Containers are not played directly; keep a representative URL so
            // the non-null column is satisfied. Episodes carry the real URLs.
            streamUrl: e.url,
            kind: MediaKind.series,
            logoUrl: e.logo,
            categoryName: e.groupTitle,
            categoryId: e.groupTitle,
          ),
        );
        // Episode row: hidden from the grid (seriesId != null), looked up by
        // the detail page via seriesId == the container's streamId.
        final epStreamId = _hash(e.url);
        items.add(
          MediaItem(
            id: MediaItem.makeId(sourceId, epStreamId),
            sourceId: sourceId,
            streamId: epStreamId,
            name: name,
            streamUrl: e.url,
            kind: MediaKind.series,
            logoUrl: e.logo,
            categoryName: e.groupTitle,
            categoryId: e.groupTitle,
            seriesId: seriesKey,
          ),
        );
        continue;
      }

      // The id (sourceId|streamId) is embedded in detail-page routes like
      // /movie/:sourceId/:id, so streamId must be path-safe. A raw stream URL
      // contains "/" and ":" and breaks go_router. When there is no tvg-id,
      // derive a stable, unique, path-safe streamId by hashing the URL.
      // Playback uses MediaItem.streamUrl, not streamId, so this is safe.
      final streamId = tvgId ?? _hash(e.url);
      items.add(
        MediaItem(
          id: MediaItem.makeId(sourceId, streamId),
          sourceId: sourceId,
          streamId: streamId,
          name: name,
          streamUrl: e.url,
          kind: kind,
          logoUrl: e.logo,
          categoryName: e.groupTitle,
          categoryId: e.groupTitle,
          // Same value as streamId for M3U when tvg-id is present, but
          // kept explicit so the EPG lookup never has to guess which
          // field carries the XMLTV channel identifier.
          epgChannelId: tvgId,
        ),
      );
    }
    items.addAll(containers.values);
    return items;
  }

  /// Parsed "SxxExx" episode naming. `title` is the series name with the
  /// season/episode suffix stripped.
  static final RegExp _seRegex = RegExp(r'[sS](\d{1,3})\s*[eE](\d{1,3})');
  static final RegExp _seasonOnlyRegex = RegExp(r'\s[sS]\d{1,3}(?![\deE])');

  static ({String title, int season, int episode})? parseEpisodeNaming(String name) {
    final m = _seRegex.firstMatch(name);
    if (m == null) return null;
    final season = int.tryParse(m.group(1)!) ?? 1;
    final episode = int.tryParse(m.group(2)!) ?? 1;
    // Cut the title at the earliest of a standalone season block (" S01") or
    // the SxxExx token itself.
    var cut = m.start;
    final seasonOnly = _seasonOnlyRegex.firstMatch(name);
    if (seasonOnly != null && seasonOnly.start < cut) cut = seasonOnly.start;
    var title = name.substring(0, cut).trim();
    title = title.replaceAll(RegExp(r'[\s\-–—:]+$'), '').trim();
    if (title.isEmpty) title = name.trim();
    return (title: title, season: season, episode: episode);
  }

  /// Series category names across the locales these panels ship: "Dizi" (TR),
  /// "Serie/Serien" (DE/NL), "Series" (EN), "Séries", "Σειρες" (GR), plus
  /// season/episode markers. Deliberately avoids bare "seri" so that the
  /// Turkish movie group "Seri Filmler" (film collections) is NOT caught here.
  static final RegExp _seriesHint = RegExp(
    r'(dizi|serien|serie\b|series|s[ée]ries|seizoen|sezon|season|episode|b[öo]l[üu]m|σειρ)',
    caseSensitive: false,
  );

  /// Movie / VOD category names: "Film/Filme/Filmler", "Movie(s)", and the
  /// common panel labels "Vizyon", "Sinema/Cinema", "Kino", "Pelicula".
  static final RegExp _movieHint = RegExp(
    r'(film|movie|vizyon|sinema|cinema|kino|pelicula|ταιν)',
    caseSensitive: false,
  );

  /// Classifies an M3U entry into a [MediaKind] using the strongest available
  /// signal, in priority order:
  ///   1. Xtream-style URL path segment (`/series/`, `/movie/`, `/live/`);
  ///      authoritative when the panel exports it.
  ///   2. group-title keyword (series before movie, since a VOD container can
  ///      be either a film or a series episode; the category name disambiguates).
  ///   3. File extension: a VOD container (.mkv/.mp4/...) implies on-demand.
  ///   4. Fallback: live (.ts, .m3u8, radio, unknown).
  ///
  /// Note the path checks run before the extension check: series entries end
  /// in .mkv/.mp4 just like movies, so extension alone would dump every series
  /// into Movies. Categories themselves come straight from group-title via the
  /// CategoryDecomposer, so this only decides which top-level tab an item lands
  /// in. Xtream sources never reach here; they set kind from the API directly.
  static MediaKind _inferKind(String url, String? groupTitle) {
    final u = url.toLowerCase();
    if (u.contains('/series/')) return MediaKind.series;
    if (u.contains('/movie/')) return MediaKind.movie;
    if (u.contains('/live/')) return MediaKind.live;

    final g = groupTitle ?? '';
    if (g.isNotEmpty) {
      if (_seriesHint.hasMatch(g)) return MediaKind.series;
      if (_movieHint.hasMatch(g)) return MediaKind.movie;
    }

    if (u.endsWith('.mp4') ||
        u.endsWith('.mkv') ||
        u.endsWith('.avi') ||
        u.endsWith('.mov') ||
        u.endsWith('.mpg')) {
      return MediaKind.movie;
    }
    return MediaKind.live;
  }
}
