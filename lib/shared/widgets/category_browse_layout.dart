import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../core/config/platform_info.dart';
import '../../core/l10n/i18n.dart';
import '../../core/utils/fuzzy.dart';
import '../../core/widgets/dpad_text_field.dart';
import '../../core/theme/app_theme.dart';
import '../../features/sources/domain/category_decomposer.dart';
import '../../features/sources/domain/category_grouping.dart';
import '../../features/sources/domain/country_names.dart';
import '../../features/sources/domain/media_item.dart';

class SmartCategoryDef {
  final String id;
  final String label;
  final IconData icon;
  final List<MediaItem> Function(List<MediaItem> all) selector;
  const SmartCategoryDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.selector,
  });
}

/// Build-time info: WHICH category is selected in the main panel and how
/// many items it has. `headerSlotBuilder` takes this selection to build an
/// extra header widget (e.g. MovieCategoryHero). Existing consumers don't
/// need to know the category state - if they don't use the slot the builder
/// stays null and nothing changes.
class CategorySelection {
  /// Id of the active smart category (favs/top/new/...) if any. Null = no smart.
  final String? smartId;

  /// Selected country code (M3U group-title prefix). Null = no specific country.
  final String? country;

  /// Selected sub-category name (parsed `subCategory`). Null = "All" or
  /// only a country selection.
  final String? subCategory;

  /// The sub-category's full original name (the whole M3U group-title).
  /// Useful for theme resolution - gives access to the original token
  /// including the country prefix.
  final String? fullName;

  /// The items list after `_baseSelection`, before search is applied. The
  /// slot builder uses this for featured-movie selection.
  final List<MediaItem> items;

  const CategorySelection({
    this.smartId,
    this.country,
    this.subCategory,
    this.fullName,
    required this.items,
  });
}

class CategoryBrowseLayout extends ConsumerStatefulWidget {
  final String title;
  final List<MediaItem> items;
  final Widget Function(BuildContext, MediaItem) itemBuilder;
  final double itemMaxExtent;
  final double itemAspectRatio;
  final List<Widget>? trailingHeader;
  final List<SmartCategoryDef> smartCategories;

  /// Optional header area rendered ABOVE the title row. The Movies tab
  /// shows [MovieCategoryHero] here; other consumers leave it null. The
  /// builder is called again on every selection change - memoize
  /// internally if needed.
  final Widget Function(BuildContext, CategorySelection)? headerSlotBuilder;

  const CategoryBrowseLayout({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.itemMaxExtent = 180,
    this.itemAspectRatio = 2 / 3.4,
    this.trailingHeader,
    this.smartCategories = const [],
    this.headerSlotBuilder,
  });

  @override
  ConsumerState<CategoryBrowseLayout> createState() =>
      _CategoryBrowseLayoutState();
}

class _CategoryBrowseLayoutState extends ConsumerState<CategoryBrowseLayout> {
  // Whatever the user picked from the sidebar.
  String? _selectedSubCategory; // matches MediaItem.categoryName (full)
  String? _selectedCountry; // filter only by country prefix
  SmartCategoryDef? _selectedSmart;
  String _query = '';
  final _searchCtrl = TextEditingController();

  /// As long as the `widget.items` reference stays the same, the category
  /// map and country buckets aren't recomputed - on large catalogs a full
  /// scan of 50K items 2-3 times was a serious cost per rebuild.
  List<MediaItem>? _itemsRef;
  Map<String, List<MediaItem>>? _byCategoryCache;
  List<_CountryBucket>? _bucketsCache;

  /// Adaptive category parser. Re-analyzed lazily as `widget.items`
  /// changes; this instance is used instead of the static
  /// `CategoryGrouping.parse`. The result: the panel resolves different
  /// formats like "TR:Netflix", "TR ✨ Netflix", "TR » Netflix" with the
  /// same code.
  CategoryDecomposer? _decomposerCache;
  CategoryDecomposer get _decomposer {
    if (_decomposerCache != null && identical(_itemsRef, widget.items)) {
      return _decomposerCache!;
    }
    final names = <String>{};
    for (final i in widget.items) {
      final n = i.categoryName;
      if (n != null && n.isNotEmpty) names.add(n);
    }
    _decomposerCache = CategoryDecomposer.analyze(names);
    return _decomposerCache!;
  }

  /// Adaptive version that yields the same shape as `CategoryGrouping.parse`.
  /// If the decomposer finds no separator it falls back to the old regex
  /// (`CategoryGrouping`); zero regression for legacy panels.
  CategoryGroup _parseCategory(String name) {
    final d = _decomposer;
    if (d.splitter == null) {
      return CategoryGrouping.parse(name);
    }
    final r = d.parse(name);
    return CategoryGroup(
      country: r.country,
      subCategory: r.subCategory,
      original: r.original,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// `categoryName -> items`, preserving server order.
  Map<String, List<MediaItem>> get _byCategory {
    if (identical(_itemsRef, widget.items) && _byCategoryCache != null) {
      return _byCategoryCache!;
    }
    final map = <String, List<MediaItem>>{};
    for (final i in widget.items) {
      final key = (i.categoryName?.isNotEmpty == true)
          ? i.categoryName!
          : ref.tr('common.other');
      map.putIfAbsent(key, () => []).add(i);
    }
    _itemsRef = widget.items;
    _byCategoryCache = map;
    _bucketsCache = null;
    return map;
  }

  /// `country (or '' for Other) -> [(subLabel, fullCategoryName, count)]`.
  ///
  /// Bucket order follows the order each country first appears in the raw
  /// item list - not the category-name iteration order. This matters when
  /// channels in an M3U are interleaved (TR / USA / TR / USA) and we want
  /// the country that has the very first channel to lead the sidebar.
  List<_CountryBucket> _buildCountryBuckets(Map<String, List<MediaItem>> byCat) {
    if (_bucketsCache != null && identical(_itemsRef, widget.items)) {
      return _bucketsCache!;
    }
    final buckets = <String, _CountryBucket>{};
    final firstSeen = <String, int>{};

    for (var i = 0; i < widget.items.length; i++) {
      final name = widget.items[i].categoryName;
      if (name == null || name.isEmpty) {
        firstSeen.putIfAbsent('', () => i);
        continue;
      }
      final code = _parseCategory(name).country ?? '';
      firstSeen.putIfAbsent(code, () => i);
    }

    for (final entry in byCat.entries) {
      final parsed = _parseCategory(entry.key);
      final code = parsed.country ?? '';
      buckets.putIfAbsent(
        code,
        () => _CountryBucket(country: code, entries: []),
      );
      buckets[code]!.entries.add(
            _CategoryEntry(
              fullName: entry.key,
              subLabel: parsed.subCategory,
              count: entry.value.length,
            ),
          );
    }
    final list = buckets.values.toList();
    list.sort((a, b) {
      // "Other" (no country prefix) sticks to the end.
      if (a.country.isEmpty && b.country.isNotEmpty) return 1;
      if (a.country.isNotEmpty && b.country.isEmpty) return -1;
      final ai = firstSeen[a.country] ?? 1 << 30;
      final bi = firstSeen[b.country] ?? 1 << 30;
      return ai.compareTo(bi);
    });
    _bucketsCache = list;
    return list;
  }

  List<MediaItem> _baseSelection(
    Map<String, List<MediaItem>> byCat,
    Map<String, List<MediaItem>> smartSnapshot,
  ) {
    if (_selectedSmart != null) {
      return smartSnapshot[_selectedSmart!.id] ?? const [];
    }
    if (_selectedSubCategory != null) return byCat[_selectedSubCategory!] ?? const [];
    if (_selectedCountry != null) {
      return widget.items.where((i) {
        final n = i.categoryName;
        if (n == null) return false;
        final p = _parseCategory(n);
        return p.country == _selectedCountry;
      }).toList();
    }
    return widget.items;
  }

  /// Lowercase + collapse scene-release punctuation to whitespace so a
  /// query like "Mission Impossible" still matches a catalog entry
  /// named "Mission.Impossible.1.1996.REMASTERED..." - without this the
  /// moment the user typed a space the result list went empty.
  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[._\-]+'), ' ').trim();

  /// Each query token must either appear as a substring in the item's
  /// normalized name or fuzzy-match a single word in it. The fuzzy fall
  /// back covers typos and near misses ("Expandables" → "Expendables").
  /// Short tokens (under 4 chars) require an exact substring to avoid
  /// flooding the list with weak matches.
  bool _tokenMatches(String token, String normalizedName) {
    if (normalizedName.contains(token)) return true;
    if (token.length < 4) return false;
    for (final word in normalizedName.split(RegExp(r'\s+'))) {
      if (word.length < 4) continue;
      if (partialRatio(token, word) >= 85) return true;
    }
    return false;
  }

  List<MediaItem> _filtered(
    Map<String, List<MediaItem>> byCat,
    Map<String, List<MediaItem>> smartSnapshot,
  ) {
    final base = _baseSelection(byCat, smartSnapshot);
    final q = _normalize(_query);
    if (q.isEmpty) return base;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    return base.where((i) {
      final n = _normalize(i.name);
      return tokens.every((t) => _tokenMatches(t, n));
    }).toList();
  }

  String get _activeLabel {
    if (_selectedSmart != null) return _selectedSmart!.label;
    if (_selectedSubCategory != null) {
      return _parseCategory(_selectedSubCategory!).subCategory;
    }
    if (_selectedCountry != null) return _selectedCountry!;
    return widget.title;
  }

  void _selectSmart(SmartCategoryDef s) => setState(() {
        _selectedSmart = s;
        _selectedSubCategory = null;
        _selectedCountry = null;
      });

  void _selectAll() => setState(() {
        _selectedSmart = null;
        _selectedSubCategory = null;
        _selectedCountry = null;
      });

  void _selectCountry(String country) => setState(() {
        _selectedSmart = null;
        _selectedSubCategory = null;
        _selectedCountry = country;
      });

  void _selectSub(String fullName, String country) => setState(() {
        _selectedSmart = null;
        _selectedSubCategory = fullName;
        _selectedCountry = country.isEmpty ? null : country;
      });

  /// Category selection on the phone (narrow) layout: instead of a
  /// persistent chip strip at the top, a collapsible bottom sheet.
  /// Countries expand/collapse via [ExpansionTile]; picking a sub-category
  /// closes the sheet and filters the body to that category. Not called on
  /// the wide (TV) layout since it uses the sidebar.
  void _openCategorySheet() {
    final byCat = _byCategory;
    final buckets = _buildCountryBuckets(byCat);
    final smartCounts = <String, int>{
      for (final s in widget.smartCategories)
        s.id: s.selector(widget.items).length,
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CategorySheet(
        smartCategories: widget.smartCategories,
        smartCounts: smartCounts,
        buckets: buckets,
        totalCount: widget.items.length,
        selectedSmartId: _selectedSmart?.id,
        selectedCountry: _selectedCountry,
        selectedSub: _selectedSubCategory,
        title: ref.tr('common.categories'),
        allLabel: ref.tr('common.all'),
        otherLabel: ref.tr('common.other'),
        onSelectSmart: (s) {
          _selectSmart(s);
          Navigator.of(ctx).pop();
        },
        onSelectAll: () {
          _selectAll();
          Navigator.of(ctx).pop();
        },
        onSelectCountry: (c) {
          _selectCountry(c);
          Navigator.of(ctx).pop();
        },
        onSelectSub: (full, c) {
          _selectSub(full, c);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final byCat = _byCategory;
    final buckets = _buildCountryBuckets(byCat);
    // Call the smart selectors ONCE per build; the sidebar count badge
    // and the body list share the same snapshot. Previously the selector
    // ran twice per smart (sidebar count + body), which on a large catalog
    // turned into a full scan × 2 × N cost on every
    // rebuild.
    final smartSnapshot = <String, List<MediaItem>>{
      for (final s in widget.smartCategories) s.id: s.selector(widget.items),
    };
    final filtered = _filtered(byCat, smartSnapshot);
    // TV: wide layout with a category sidebar (categories navigated on the
    // left with the remote, grid on the right). Narrow chip-strip isn't fit for a remote.
    final isWide =
        PlatformInfo.isTv || MediaQuery.sizeOf(context).width >= 980;

    final sidebar = _Sidebar(
      smartCategories: widget.smartCategories,
      smartCounts: {
        for (final s in widget.smartCategories) s.id: smartSnapshot[s.id]!.length,
      },
      buckets: buckets,
      total: widget.items.length,
      selectedSmartId: _selectedSmart?.id,
      selectedCountry: _selectedCountry,
      selectedSub: _selectedSubCategory,
      onSelectSmart: _selectSmart,
      onSelectAll: _selectAll,
      onSelectCountry: _selectCountry,
      onSelectSub: _selectSub,
      collectionsLabel: ref.tr('common.collections'),
      categoriesLabel: ref.tr('common.categories'),
      allLabel: ref.tr('common.all'),
    );

    // Category-selection summary object for the slot builder. We want the
    // header slot to operate on the list before search is applied, because
    // featured-movie selection should be made over "all movies in this
    // category", regardless of what the user typed into the search box.
    final baseItems = _baseSelection(byCat, smartSnapshot);
    Widget? headerSlot;
    if (widget.headerSlotBuilder != null) {
      final selection = CategorySelection(
        smartId: _selectedSmart?.id,
        country: _selectedCountry,
        subCategory: _selectedSubCategory == null
            ? null
            : _parseCategory(_selectedSubCategory!).subCategory,
        fullName: _selectedSubCategory,
        items: baseItems,
      );
      headerSlot = widget.headerSlotBuilder!(context, selection);
    }

    final mainContent = _MainPanel(
      title: _activeLabel,
      hasActiveCategory: _selectedSmart != null ||
          _selectedSubCategory != null ||
          _selectedCountry != null,
      filteredCount: filtered.length,
      items: filtered,
      searchHint: ref.tr('common.searchInList'),
      noResultsLabel: ref.tr('common.noResults'),
      itemMaxExtent: widget.itemMaxExtent,
      itemAspectRatio: widget.itemAspectRatio,
      itemBuilder: widget.itemBuilder,
      trailingHeader: widget.trailingHeader,
      headerSlot: headerSlot,
      searchController: _searchCtrl,
      query: _query,
      onQueryChanged: (v) => setState(() => _query = v),
      // When "All" is selected, group rendered items by country so the user
      // sees the same grouping as the sidebar.
      groupByCountry: _selectedSmart == null &&
          _selectedSubCategory == null &&
          _selectedCountry == null,
      // Make the body groups use the ADAPTIVE parser too (same as the
      // sidebar/chip). Otherwise, on panels with a non-standard separator
      // like "✨", the body dropped everything into "OTHER" via the old static parse.
      countryOf: (name) => _parseCategory(name).country,
      // On the phone (narrow) layout category selection is done from the
      // collapsible bottom sheet; a "Categories" button is shown in the
      // header. On the wide (TV) layout it's null -> the sidebar is used.
      onOpenCategories: isWide ? null : _openCategorySheet,
      categoriesButtonLabel: ref.tr('common.categories'),
    );

    if (isWide) {
      return Row(
        children: [
          sidebar,
          const VerticalDivider(width: 1),
          Expanded(child: mainContent),
        ],
      );
    }
    // Narrow (phone) layout: NO persistent category strip at the top.
    // Category selection is done from the collapsible bottom sheet opened
    // by the header's "Categories" button (_openCategorySheet). The grid
    // uses the full width. SafeArea(top): so content starts below the status
    // bar (VodBrowsePage's Scaffold has no top inset). Live TV is already
    // inside a SafeArea; the nested SafeArea is a no-op.
    return SafeArea(
      top: true,
      bottom: false,
      child: mainContent,
    );
  }
}

class _CountryBucket {
  final String country; // '' = no country prefix
  final List<_CategoryEntry> entries;
  _CountryBucket({required this.country, required this.entries});
}

class _CategoryEntry {
  final String fullName;
  final String subLabel;
  final int count;
  const _CategoryEntry({
    required this.fullName,
    required this.subLabel,
    required this.count,
  });
}

/// The "Categories" button in the phone header. Shows the active category's
/// name + count if there is one, otherwise the "Categories" label; opens
/// the collapsible category sheet when tapped.
class _CategoriesButton extends StatelessWidget {
  final String activeLabel;
  final int count;
  final String fallbackLabel;
  final bool hasActiveCategory;
  final VoidCallback onTap;
  const _CategoriesButton({
    required this.activeLabel,
    required this.count,
    required this.fallbackLabel,
    required this.hasActiveCategory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = hasActiveCategory ? activeLabel : fallbackLabel;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  $count',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more_rounded,
                  size: 22, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed-height pinned sliver header. Used to pin the "Categories" button to
/// the top on scroll; opaque behind it (so no content shows through).
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  _PinnedHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.background,
        child: Center(child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) => true;
}

/// Collapsible category sheet (phone). Shows Collections + "All" + each
/// country's sub-categories via an [ExpansionTile] (expand/collapse). Once
/// a selection is made the sheet closes and the body filters to that
/// category.
class _CategorySheet extends ConsumerWidget {
  final List<SmartCategoryDef> smartCategories;
  final Map<String, int> smartCounts;
  final List<_CountryBucket> buckets;
  final int totalCount;
  final String? selectedSmartId;
  final String? selectedCountry;
  final String? selectedSub;
  final String title;
  final String allLabel;
  final String otherLabel;
  final ValueChanged<SmartCategoryDef> onSelectSmart;
  final VoidCallback onSelectAll;
  final void Function(String country) onSelectCountry;
  final void Function(String fullName, String country) onSelectSub;

  const _CategorySheet({
    required this.smartCategories,
    required this.smartCounts,
    required this.buckets,
    required this.totalCount,
    required this.selectedSmartId,
    required this.selectedCountry,
    required this.selectedSub,
    required this.title,
    required this.allLabel,
    required this.otherLabel,
    required this.onSelectSmart,
    required this.onSelectAll,
    required this.onSelectCountry,
    required this.onSelectSub,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).value?.code ?? 'tr';
    final maxH = MediaQuery.sizeOf(context).height * 0.82;
    final noneSelected =
        selectedSmartId == null && selectedCountry == null && selectedSub == null;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 8, 6),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (smartCategories.isNotEmpty) ...[
                  for (final s in smartCategories)
                    ListTile(
                      leading: Icon(s.icon,
                          color: selectedSmartId == s.id
                              ? AppColors.accent
                              : AppColors.textSecondary),
                      title: Text(s.label),
                      trailing: Text('${smartCounts[s.id] ?? 0}',
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 13)),
                      selected: selectedSmartId == s.id,
                      selectedTileColor: AppColors.accent.withValues(alpha: 0.10),
                      onTap: () => onSelectSmart(s),
                    ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: Icon(Icons.apps_rounded,
                      color: noneSelected
                          ? AppColors.accent
                          : AppColors.textSecondary),
                  title: Text(allLabel),
                  trailing: Text('$totalCount',
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 13)),
                  selected: noneSelected,
                  selectedTileColor: AppColors.accent.withValues(alpha: 0.10),
                  onTap: onSelectAll,
                ),
                for (final b in buckets) _countrySection(b, locale),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _countrySection(_CountryBucket b, String locale) {
    final isOther = b.country.isEmpty;
    final countryLabel = isOther
        ? otherLabel
        : CountryNames.labelWithCode(b.country, locale: locale);
    final total = b.entries.fold(0, (s, e) => s + e.count);
    // Is this country currently selected (also when a sub-category selection belongs to it).
    final activeCountry = isOther ? null : b.country;
    final countrySelected =
        activeCountry != null && selectedCountry == activeCountry;
    return ExpansionTile(
      initiallyExpanded: countrySelected,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: EdgeInsets.zero,
      leading: Icon(
        isOther ? Icons.folder_open_rounded : Icons.public_rounded,
        color: countrySelected ? AppColors.accent : AppColors.textSecondary,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              countryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: countrySelected
                    ? AppColors.accent
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Text('$total',
              style: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 13)),
        ],
      ),
      children: [
        // "All {country}" (the whole country). Skipped in the Other bucket
        // because country-code-less content can't be selected by the country
        // filter alone; their sub-categories can still be selected directly.
        if (!isOther)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            dense: true,
            title: Text(allLabel),
            trailing: Text('$total',
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12)),
            selected: countrySelected && selectedSub == null,
            selectedTileColor: AppColors.accent.withValues(alpha: 0.10),
            onTap: () => onSelectCountry(b.country),
          ),
        for (final e in b.entries)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            dense: true,
            title: Text(e.subLabel,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text('${e.count}',
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12)),
            selected: selectedSub == e.fullName,
            selectedTileColor: AppColors.accent.withValues(alpha: 0.10),
            onTap: () => onSelectSub(e.fullName, b.country),
          ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<SmartCategoryDef> smartCategories;
  final Map<String, int> smartCounts;
  final List<_CountryBucket> buckets;
  final int total;
  final String? selectedSmartId;
  final String? selectedCountry;
  final String? selectedSub;
  final ValueChanged<SmartCategoryDef> onSelectSmart;
  final VoidCallback onSelectAll;
  final void Function(String country) onSelectCountry;
  final void Function(String fullName, String country) onSelectSub;
  final String collectionsLabel;
  final String categoriesLabel;
  final String allLabel;

  const _Sidebar({
    required this.smartCategories,
    required this.smartCounts,
    required this.buckets,
    required this.total,
    required this.selectedSmartId,
    required this.selectedCountry,
    required this.selectedSub,
    required this.onSelectSmart,
    required this.onSelectAll,
    required this.onSelectCountry,
    required this.onSelectSub,
    required this.collectionsLabel,
    required this.categoriesLabel,
    required this.allLabel,
  });

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[];

    if (smartCategories.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: _SectionHeading(text: collectionsLabel),
      ));
      for (final s in smartCategories) {
        slivers.add(SliverToBoxAdapter(
          child: _SidebarEntry(
            label: s.label,
            icon: s.icon,
            count: smartCounts[s.id] ?? 0,
            selected: selectedSmartId == s.id,
            onTap: () => onSelectSmart(s),
          ),
        ));
      }
      slivers.add(const SliverToBoxAdapter(
        child: Divider(height: 1, indent: 16, endIndent: 16),
      ));
    }

    slivers.add(SliverToBoxAdapter(
      child: _SectionHeading(text: categoriesLabel),
    ));
    slivers.add(SliverToBoxAdapter(
      child: _SidebarEntry(
        label: allLabel,
        count: total,
        selected: selectedSmartId == null &&
            selectedCountry == null &&
            selectedSub == null,
        onTap: onSelectAll,
      ),
    ));

    for (final b in buckets) {
      final list = SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final e = b.entries[i];
            return _SidebarEntry(
              label: e.subLabel,
              count: e.count,
              indented: b.country.isNotEmpty,
              selected: selectedSub == e.fullName,
              onTap: () => onSelectSub(e.fullName, b.country),
            );
          },
          childCount: b.entries.length,
        ),
      );
      if (b.country.isEmpty) {
        slivers.add(list);
      } else {
        slivers.add(SliverStickyHeader(
          header: _CountryHeader(
            country: b.country,
            count: b.entries.fold(0, (s, e) => s + e.count),
            selected: selectedCountry == b.country && selectedSub == null,
            onTap: () => onSelectCountry(b.country),
          ),
          sliver: list,
        ));
      }
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));

    return Container(
      width: 210,
      color: AppColors.surface,
      child: SafeArea(
        child: CustomScrollView(slivers: slivers),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _CountryHeader extends ConsumerWidget {
  final String country;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _CountryHeader({
    required this.country,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).value?.code ?? 'tr';
    final label = CountryNames.labelWithCode(country, locale: locale);
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.14)
          : AppColors.surfaceElevated,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarEntry extends StatefulWidget {
  final String label;
  final int count;
  final bool selected;
  final IconData? icon;
  final bool indented;
  final VoidCallback onTap;
  const _SidebarEntry({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon,
    this.indented = false,
  });

  @override
  State<_SidebarEntry> createState() => _SidebarEntryState();
}

class _SidebarEntryState extends State<_SidebarEntry> {
  bool _hover = false;
  bool _focus = false;

  bool get _highlighted => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final accent = widget.selected || _focus;
    final color = accent ? AppColors.accent : AppColors.textPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _focus = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.fromLTRB(widget.indented ? 36 : 18, 8, 18, 8),
            color: widget.selected
                ? AppColors.accent.withValues(alpha: 0.10)
                : (_highlighted
                    ? AppColors.accent.withValues(alpha: 0.16)
                    : Colors.transparent),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 16,
                    color: accent ? AppColors.accent : AppColors.textTertiary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${widget.count}',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _MainPanel extends StatefulWidget {
  final String title;
  final bool hasActiveCategory;
  final int filteredCount;
  final List<MediaItem> items;
  final double itemMaxExtent;
  final double itemAspectRatio;
  final Widget Function(BuildContext, MediaItem) itemBuilder;
  final List<Widget>? trailingHeader;
  final Widget? headerSlot;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final bool groupByCountry;
  final String searchHint;
  final String noResultsLabel;
  /// Adaptive resolver that extracts the country code from a category name
  /// (`_parseCategory(name).country`). Passed in from outside so the body
  /// grouping uses the same parser as the sidebar/chip.
  final String? Function(String name) countryOf;
  /// Tap callback of the "Categories" button shown in the header on the
  /// phone (narrow) layout (opens the collapsible bottom sheet). If null
  /// we're on the wide (TV) layout and the button is hidden (sidebar used).
  final VoidCallback? onOpenCategories;
  /// Label of the "Categories" button (i18n).
  final String categoriesButtonLabel;

  const _MainPanel({
    required this.title,
    required this.hasActiveCategory,
    required this.filteredCount,
    required this.items,
    required this.itemMaxExtent,
    required this.itemAspectRatio,
    required this.itemBuilder,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.trailingHeader,
    required this.groupByCountry,
    required this.searchHint,
    required this.noResultsLabel,
    required this.countryOf,
    required this.categoriesButtonLabel,
    this.onOpenCategories,
    this.headerSlot,
  });

  @override
  State<_MainPanel> createState() => _MainPanelState();
}

class _MainPanelState extends State<_MainPanel> {
  // On TV the search box is skipped in D-pad traversal (skipTraversal):
  // moving into content with the remote sends focus straight to the grid,
  // not the keyboard-opening search field. (Normal on phone/mouse.)
  final FocusNode? _searchFocus =
      PlatformInfo.isTv ? FocusNode(skipTraversal: true) : null;

  @override
  void dispose() {
    _searchFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final filteredCount = widget.filteredCount;
    final items = widget.items;
    final itemMaxExtent = widget.itemMaxExtent;
    final itemAspectRatio = widget.itemAspectRatio;
    final itemBuilder = widget.itemBuilder;
    final trailingHeader = widget.trailingHeader;
    final headerSlot = widget.headerSlot;
    final searchController = widget.searchController;
    final query = widget.query;
    final onQueryChanged = widget.onQueryChanged;
    final groupByCountry = widget.groupByCountry;
    final searchHint = widget.searchHint;
    final noResultsLabel = widget.noResultsLabel;
    // Header slot + search row + grid are placed as slivers under a single
    // CustomScrollView. On scroll the hero slides up and disappears; the
    // grid fills the whole screen.
    final slivers = <Widget>[];
    if (headerSlot != null) {
      slivers.add(SliverToBoxAdapter(child: headerSlot));
    }
    // Search field (shared by both layouts).
    final searchField = DpadTextField(
      child: TextField(
        focusNode: _searchFocus,
        controller: searchController,
        onChanged: onQueryChanged,
        decoration: InputDecoration(
          hintText: searchHint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    searchController.clear();
                    onQueryChanged('');
                  },
                ),
        ),
      ),
    );
    if (widget.onOpenCategories != null) {
      // PHONE: NO persistent category strip at the top. The "Categories"
      // button showing the active selection (opens the collapsible sheet)
      // is one row; search is a separate full-width row -> title and search
      // no longer squeeze together. The "Categories" button is PINNED: it
      // sticks to the top as the hero/grid scroll, so changing category is one tap away.
      slivers.add(SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedHeaderDelegate(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _CategoriesButton(
              activeLabel: title,
              count: filteredCount,
              fallbackLabel: widget.categoriesButtonLabel,
              hasActiveCategory: widget.hasActiveCategory,
              onTap: widget.onOpenCategories!,
            ),
          ),
        ),
      ));
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: searchField,
        ),
      ));
    } else {
      // WIDE (TV): title + 280px search on the right (sidebar provides the category).
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
          child: Row(
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  $filteredCount',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(width: 280, child: searchField),
            ],
          ),
        ),
      ));
    }
    if (trailingHeader != null && trailingHeader!.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(children: trailingHeader!),
        ),
      ));
    }
    if (items.isEmpty) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            noResultsLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ));
    } else if (groupByCountry) {
      slivers.addAll(_buildGroupedSlivers(context, items));
    } else {
      slivers.add(SliverPadding(
        padding: const EdgeInsets.all(24),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: itemMaxExtent,
            childAspectRatio: itemAspectRatio,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => itemBuilder(context, items[i]),
            childCount: items.length,
          ),
        ),
      ));
    }
    return CustomScrollView(
      // Pre-fetch - ~1 screen of buffer; more than that kicks off TMDB
      // lookups in parallel with the scroll gesture and causes jitter.
      cacheExtent: 800,
      slivers: slivers,
    );
  }

  List<Widget> _buildGroupedSlivers(
      BuildContext context, List<MediaItem> visible) {
    final m = <String, List<MediaItem>>{};
    final firstSeen = <String, int>{};
    for (var idx = 0; idx < visible.length; idx++) {
      final i = visible[idx];
      final name = i.categoryName;
      final country = name == null
          ? 'OTHER'
          : (widget.countryOf(name) ?? 'OTHER');
      firstSeen.putIfAbsent(country, () => idx);
      m.putIfAbsent(country, () => []).add(i);
    }
    final keys = m.keys.toList()
      ..sort((a, b) {
        if (a == 'OTHER' && b != 'OTHER') return 1;
        if (b == 'OTHER' && a != 'OTHER') return -1;
        return (firstSeen[a] ?? 1 << 30)
            .compareTo(firstSeen[b] ?? 1 << 30);
      });
    final out = <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
    ];
    for (final k in keys) {
      out.add(SliverStickyHeader(
        header: _GroupHeader(country: k, count: m[k]!.length),
        sliver: SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: widget.itemMaxExtent,
              childAspectRatio: widget.itemAspectRatio,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => widget.itemBuilder(context, m[k]![i]),
              childCount: m[k]!.length,
            ),
          ),
        ),
      ));
    }
    return out;
  }
}

class _GroupHeader extends ConsumerWidget {
  final String country;
  final int count;
  const _GroupHeader({required this.country, required this.count});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).value?.code ?? 'tr';
    final label = country == 'OTHER'
        ? ref.tr('common.other').toUpperCase()
        : CountryNames.labelWithCode(country, locale: locale);
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· $count',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
