import 'package:flutter_test/flutter_test.dart';
import 'package:ipdigi/features/sources/domain/category_decomposer.dart';

/// Category names taken from the real "Zenith" panel. Separator "✨" (U+2728).
/// A handful of "|" / "✦" variants are mixed in too; the dominant one "✨" must be picked.
const _realNames = <String>[
  'DE ✨Netflix',
  'DE ✨Horror-thriller Filme',
  'DE ✨Action-abendenteuer Filme',
  'DE ✨Comedy Filme',
  'DE ✨2024 Filme',
  'DE ✨Anime Serien',
  'TR ✨Netflix (yabanci)',
  'TR ✨Vizyon (Multi)',
  'TR ✨Ulusal HEVC',
  'TR ✨ Zenith Relax',
  'TR ✨Altyazili Film',
  'TR ✨Animasyon',
  'XXX ✨Mix Movie',
  'XXX ✨Turk Movie',
  'TR| Sinema Protürk ✦',
];

void main() {
  test('CategoryDecomposer baskın ayraç olarak "✨" seçer', () {
    final d = CategoryDecomposer.analyze(_realNames);
    expect(d.splitter, '✨',
        reason: 'panel ayracı ✨; analyze bunu seçmeli (gövde+sidebar buna bağlı)');
  });

  test('parse: ülke prefix + alt kategori doğru ayrışır', () {
    final d = CategoryDecomposer.analyze(_realNames);
    final de = d.parse('DE ✨Netflix');
    expect(de.country, 'DE');
    expect(de.subCategory, 'Netflix');

    final tr = d.parse('TR ✨Vizyon (Multi)');
    expect(tr.country, 'TR');
    expect(tr.subCategory, 'Vizyon (Multi)');

    final xxx = d.parse('XXX ✨Mix Movie');
    expect(xxx.country, 'XXX'); // unknown but short ALL-CAPS -> group
    expect(xxx.subCategory, 'Mix Movie');
  });

  test('alt kategoriler tek "OTHER"a düşmemeli: ülke kümesi > 1', () {
    final d = CategoryDecomposer.analyze(_realNames);
    final countries =
        _realNames.map((n) => d.parse(n).country).whereType<String>().toSet();
    expect(countries, containsAll(<String>{'DE', 'TR', 'XXX'}));
  });
}
