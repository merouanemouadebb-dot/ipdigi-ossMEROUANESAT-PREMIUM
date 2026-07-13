/// Parses provider-supplied category names of the form `XX | Subcategory`
/// (e.g. "TR | Ulusal HEVC ✦") into a country prefix and the actual sub-
/// category. Names without that prefix fall through with `country == null`,
/// so they can be grouped under "Other" in the sidebar.
class CategoryGroup {
  final String? country;
  final String subCategory;
  final String original;
  const CategoryGroup({
    required this.country,
    required this.subCategory,
    required this.original,
  });
}

class CategoryGrouping {
  // Accepts 2-4 character prefixes followed by `|` or `-` and the rest.
  // Allows latin + cyrillic letters (some panels use "RU | …" / "KZ | …").
  static final _pattern = RegExp(
    r'^\s*([A-Za-zЀ-ӿ]{2,5})\s*[|\-–]\s*(.+?)\s*$',
  );

  static CategoryGroup parse(String input) {
    final m = _pattern.firstMatch(input);
    if (m != null) {
      return CategoryGroup(
        country: m.group(1)!.toUpperCase(),
        subCategory: m.group(2)!.trim(),
        original: input,
      );
    }
    return CategoryGroup(
      country: null,
      subCategory: input.trim(),
      original: input,
    );
  }
}
