import 'package:flutter_test/flutter_test.dart';
import 'package:ipdigi/core/metadata/tmdb_provider.dart';

void main() {
  group('cleanTitle: scene release filename cleanup', () {
    test('Star Wars + AC3.5.1 audio layout stripped', () {
      final out = cleanTitle(
          'Star.Wars.Episode.III.Revenge.of.the.Sith.2005.m1080p.BluRay.X264.AC3.5.1.DuaL');
      // Drop year + codec + 5.1 channels + dual; no "5 1" residue should remain.
      expect(out, equals('Star Wars Episode III Revenge of the Sith'));
    });

    test('Faraway NF tag stripped, year removed', () {
      final out = cleanTitle('Faraway (2023).NF');
      expect(out, equals('Faraway'));
    });

    test('Mission Impossible REMASTERED + codec tags stripped', () {
      final out = cleanTitle(
          'Mission.Impossible.1.1996.REMASTERED.m1080p.BluRay.H264.DUAL');
      expect(out, equals('Mission Impossible 1'));
    });

    test('Transporter 2 + dual tag stripped', () {
      final out = cleanTitle(
          'The.Transporter.2.2005.m1080p.Bluray.x264.DUAL');
      expect(out, equals('The Transporter 2'));
    });

    test('Audio format ac3.5.1 with letters intact', () {
      final out = cleanTitle('Inception.2010.BluRay.AC3.5.1.x264-FOO');
      expect(out, equals('Inception'));
    });

    test('DTS.7.1 audio layout', () {
      final out = cleanTitle(
          'Interstellar.2014.1080p.BluRay.DTS.7.1.x264-RELEASE');
      expect(out, equals('Interstellar'));
    });

    test('DD.2.0 audio layout', () {
      final out = cleanTitle('Joker.2019.1080p.BluRay.DD.2.0.x265');
      expect(out, equals('Joker'));
    });

    test('streaming source tags (NF / AMZN) stripped', () {
      final out =
          cleanTitle('The.Crown.S04.2020.AMZN.WEB-DL.1080p.x264-FOO');
      expect(out, equals('The Crown S04'));
    });

    test('clean title without scene tags is preserved', () {
      final out = cleanTitle('Inception (2010)');
      expect(out, equals('Inception'));
    });

    test('Turkish characters preserved', () {
      final out = cleanTitle('Yeşilçam.2021.Dublaj.1080p');
      expect(out, equals('Yeşilçam'));
    });

    test('trailing standalone digits stripped only if scene-tag residue', () {
      // "Episode 3" should be in the middle of the title, keep the last token
      final out = cleanTitle('Star.Wars.Episode.3.2005.BluRay.x264.AC3.5.1');
      // There is a "3" at the end of the title, keep it; only the AUDIO
      // residue "5 1" and the trailing release-group are cleaned.
      expect(out, equals('Star Wars Episode 3'));
    });

    test('cleanTitleStrict cuts at year', () {
      final out = cleanTitleStrict(
          'Star.Wars.Episode.III.Revenge.of.the.Sith.2005.m1080p.BluRay.X264.AC3.5.1.DuaL');
      expect(out, equals('Star Wars Episode III Revenge of the Sith'));
    });

    test('cleanTitleStrict no-op when no year', () {
      final out = cleanTitleStrict('The Office');
      expect(out, equals('The Office'));
    });

    test('cleanTitleStrict drops post-year content even if no scene tags', () {
      final out = cleanTitleStrict('Movie Title 2020 some leftover');
      expect(out, equals('Movie Title'));
    });
  });
}
