import 'package:flutter_test/flutter_test.dart';
import 'package:ipdigi/features/sources/data/m3u_parser.dart';
import 'package:ipdigi/features/sources/data/source_repository.dart';
import 'package:ipdigi/features/sources/domain/media_item.dart';

/// Builds a one-entry M3U and returns the inferred kind of that entry.
MediaKind kindOf({required String url, String? group}) {
  final attrs = group == null ? '' : ' group-title="$group"';
  final m3u = '#EXTM3U\n#EXTINF:-1$attrs,Sample\n$url\n';
  final items = M3uParser.toMediaItems('src', M3uParser.parse(m3u));
  // A series entry expands to an episode row plus a container row; other kinds
  // produce a single row. The episode is added first, so first.kind is the
  // classified kind in all cases.
  expect(items, isNotEmpty);
  return items.first.kind;
}

void main() {
  _cleanUrlTests();
  _seriesGroupingTests();
  test('empty tvg-id does not collapse items to one id', () {
    const m3u = '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="" group-title="Open Movies",A\n'
        'http://h/movie/u/p/1.mkv\n'
        '#EXTINF:-1 tvg-id="" group-title="Open Movies",B\n'
        'http://h/movie/u/p/2.mkv\n';
    final items = M3uParser.toMediaItems('src', M3uParser.parse(m3u));
    expect(items, hasLength(2));
    expect(items[0].id, isNot(items[1].id));
  });

  group('M3U kind classification', () {
    // Real-world Xtream panel export style: URL path is the
    // authoritative signal and must win over the file extension.
    test('Xtream /series/ .mkv -> series (NOT movie)', () {
      expect(
        kindOf(
          url: 'http://panel.example:8080/series/user/pass/12345.mkv',
          group: 'TR ✨Amazon Dizi',
        ),
        MediaKind.series,
      );
    });

    test('Xtream /movie/ .mkv -> movie', () {
      expect(
        kindOf(
          url: 'http://panel.example:8080/movie/user/pass/678.mkv',
          group: 'TR ✨Netflix (yabanci)',
        ),
        MediaKind.movie,
      );
    });

    test('Xtream /live/ .ts -> live', () {
      expect(
        kindOf(
          url: 'http://panel.example:8080/live/user/pass/603307.ts',
          group: 'TR ✨ Zenith Relax',
        ),
        MediaKind.live,
      );
    });

    // Playlists without path segments: group-title disambiguates.
    test('pathless .mkv with "Dizi" group -> series', () {
      expect(
        kindOf(url: 'http://h/x/9.mkv', group: 'TR ✨Netflix Dizi'),
        MediaKind.series,
      );
    });

    test('pathless .mkv with "Filme" group -> movie', () {
      expect(
        kindOf(url: 'http://h/x/9.mkv', group: 'DE ✨Action-abendenteuer Filme'),
        MediaKind.movie,
      );
    });

    // Tricky: Turkish "Seri Filmler" is a MOVIE collection, must not be
    // mistaken for a series because of the substring "Seri".
    test('"Seri Filmler" group -> movie (not series)', () {
      expect(
        kindOf(url: 'http://h/x/9.mkv', group: 'TR ✨Seri Filmler'),
        MediaKind.movie,
      );
    });

    test('German "Serien" group -> series', () {
      expect(
        kindOf(url: 'http://h/x/9.mkv', group: 'DE ✨Prime Serien'),
        MediaKind.series,
      );
    });

    // Plain live channel: no path, no VOD extension, no movie/series hint.
    test('.ts with no hints -> live', () {
      expect(
        kindOf(url: 'http://h/stream/9.ts', group: 'TR ✨ Spor'),
        MediaKind.live,
      );
    });

    test('.m3u8 with no hints -> live', () {
      expect(kindOf(url: 'https://cdn/live/x.m3u8'), MediaKind.live);
    });

    // Bare VOD file with no path and no useful group -> treated as movie.
    test('bare .mp4 -> movie', () {
      expect(kindOf(url: 'https://cdn/files/clip.mp4'), MediaKind.movie);
    });
  });
}

void _seriesGroupingTests() {
  group('series grouping', () {
    const m3u = '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="" group-title="TR Dizi",Foo (2026) S01 Foo (2026) - S01E01 - 1. Bolum\n'
        'http://h/series/u/p/1.mkv\n'
        '#EXTINF:-1 tvg-id="" group-title="TR Dizi",Foo (2026) S01 Foo (2026) - S01E02 - 2. Bolum\n'
        'http://h/series/u/p/2.mkv\n'
        '#EXTINF:-1 tvg-id="" group-title="TR Dizi",Foo (2026) S02 Foo (2026) - S02E01 - 1. Bolum\n'
        'http://h/series/u/p/3.mkv\n';
    final items = M3uParser.toMediaItems('src', M3uParser.parse(m3u));

    test('one container (seriesId null) + episodes (seriesId set)', () {
      final containers =
          items.where((i) => i.kind == MediaKind.series && i.seriesId == null);
      final episodes =
          items.where((i) => i.kind == MediaKind.series && i.seriesId != null);
      expect(containers.length, 1);
      expect(episodes.length, 3);
      expect(containers.first.name, 'Foo (2026)');
      // every episode links to the single container
      expect(episodes.every((e) => e.seriesId == containers.first.streamId),
          isTrue);
    });

    test('parseEpisodeNaming extracts title/season/episode', () {
      final p = M3uParser.parseEpisodeNaming(
          'Foo (2026) S02 Foo (2026) - S02E07 - 7. Bolum');
      expect(p?.title, 'Foo (2026)');
      expect(p?.season, 2);
      expect(p?.episode, 7);
    });
  });
}

void _cleanUrlTests() {
  group('cleanM3uUrl', () {
    test('strips glued EPG: and Cpanel: blob (real paste shape)', () {
      const raw =
          'http://panel.example:8080/get.php?username=demo&password=demo&type=m3u_plus&output=tsEPG: http://panel.example:8080/xmltv.php?username=demo&password=demoCpanel: http://panel.example:8080/access/?token=XXXX';
      expect(
        SourceRepository.cleanM3uUrl(raw),
        'http://panel.example:8080/get.php?username=demo&password=demo&type=m3u_plus&output=ts',
      );
    });
    test('leaves a clean url untouched', () {
      const raw = 'http://h:8080/get.php?username=a&password=b&type=m3u_plus&output=ts';
      expect(SourceRepository.cleanM3uUrl(raw), raw);
    });
    test('trims surrounding whitespace', () {
      expect(SourceRepository.cleanM3uUrl('  http://h/x.m3u  '), 'http://h/x.m3u');
    });
  });
}
