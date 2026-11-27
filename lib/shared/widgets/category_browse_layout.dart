
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

class CategorySelection {
  final String? smartId;
  final String? country;
  final String? subCategory;
  final String? fullName;
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

class _CategoryBrowseLayoutState
    extends ConsumerState<CategoryBrowseLayout> {
  String? _selectedSubCategory;
  String? _selectedCountry;
  SmartCategoryDef? _selectedSmart;
  String _query = '';
  final _searchCtrl = TextEditingController();

  List<MediaItem>? _itemsRef;
  Map<String, List<MediaItem>>? _byCategoryCache;
  List<_CountryBucket>? _bucketsCache;

  CategoryDecomposer? _decomposerCache;

  CategoryDecomposer get _decomposer {
    if (_decomposerCache != null &&
        identical(_itemsRef, widget.items)) {
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

  Map<String, List<MediaItem>> get _byCategory {
    if (identical(_itemsRef, widget.items) &&
        _byCategoryCache != null) {
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

  List<_CountryBucket> _buildCountryBuckets(
    Map<String, List<MediaItem>> byCat,
  ) {
    if (_bucketsCache != null &&
        identical(_itemsRef, widget.items)) {
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
      if (a.country.isEmpty && b.country.isNotEmpty) {
        return 1;
      }

      if (a.country.isNotEmpty && b.country.isEmpty) {
        return -1;
      }

      final ai = firstSeen[a.country] ?? (1 << 30);
      final bi = firstSeen[b.country] ?? (1 << 30);

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

    if (_selectedSubCategory != null) {
      return byCat[_selectedSubCategory!] ?? const [];
    }

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

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(
        RegExp(r'[._\-]+'),
        ' ',
      ).trim();

  bool _tokenMatches(
    String token,
    String normalizedName,
  ) {
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

    final tokens = q
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    return base.where((i) {
      final n = _normalize(i.name);

      return tokens.every(
        (t) => _tokenMatches(t, n),
      );
    }).toList();
  }

  String get _activeLabel {
    if (_selectedSmart != null) {
      return _selectedSmart!.label;
    }

    if (_selectedSubCategory != null) {
      return _parseCategory(
        _selectedSubCategory!,
      ).subCategory;
    }

    if (_selectedCountry != null) {
      return _selectedCountry!;
    }

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

  void _selectSub(
    String fullName,
    String country,
  ) => setState(() {
    _selectedSmart = null;
    _selectedSubCategory = fullName;
    _selectedCountry =
        country.isEmpty ? null : country;
  });

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
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
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

    final smartSnapshot = <String, List<MediaItem>>{
      for (final s in widget.smartCategories)
        s.id: s.selector(widget.items),
    };

    final filtered = _filtered(
      byCat,
      smartSnapshot,
    );

    final isWide = PlatformInfo.isTv ||
        MediaQuery.sizeOf(context).width >= 980;

    final sidebar = _Sidebar(
      smartCategories: widget.smartCategories,
      smartCounts: {
        for (final s in widget.smartCategories)
          s.id: smartSnapshot[s.id]!.length,
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

    final baseItems = _baseSelection(
      byCat,
      smartSnapshot,
    );

    Widget? headerSlot;

    if (widget.headerSlotBuilder != null) {
      final selection = CategorySelection(
        smartId: _selectedSmart?.id,
        country: _selectedCountry,
        subCategory: _selectedSubCategory == null
            ? null
            : _parseCategory(
                _selectedSubCategory!,
              ).subCategory,
        fullName: _selectedSubCategory,
        items: baseItems,
      );

      headerSlot = widget.headerSlotBuilder!(
        context,
        selection,
      );
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
      onQueryChanged: (v) =>
          setState(() => _query = v),
      groupByCountry: false,
      countryOf: (name) =>
          _parseCategory(name).country,
      onOpenCategories:
          isWide ? null : _openCategorySheet,
      categoriesButtonLabel:
          ref.tr('common.categories'),
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

    return SafeArea(
      top: true,
      bottom: false,
      child: mainContent,
    );
  }
}

class _CountryBucket {
  final String country;
  final List<_CategoryEntry> entries;

  _CountryBucket({
    required this.country,
    required this.entries,
  });
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
    final label =
        hasActiveCategory ? activeLabel : fallbackLabel;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: AppColors.accent,
              ),
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
                          fontFeatures: [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.expand_more_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.background,
        child: Center(child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(
    covariant _PinnedHeaderDelegate oldDelegate,
  ) => true;
}

class _CategorySheet extends ConsumerStatefulWidget {
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
  final void Function(String fullName, String country)
      onSelectSub;

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
  ConsumerState<_CategorySheet> createState() =>
      _CategorySheetState();
}

class _CategorySheetState
    extends ConsumerState<_CategorySheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(String value) {
    final normalized = value.toLowerCase();

    return _query.split(RegExp(r'\s+')).every(
      (word) => normalized.contains(word),
    );
  }

  Text _label(String value) => Text(
    value,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  Text _count(int count) => Text(
    '$count',
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontFeatures: [
        FontFeature.tabularFigures(),
      ],
    ),
  );

  Widget _entryTile(
    _CategoryEntry e,
    String country, {
    bool nested = false,
  }) {
    final selected =
        widget.selectedSub == e.fullName;

    return ListTile(
      contentPadding: nested
          ? const EdgeInsetsDirectional.only(
              start: 48,
              end: 16,
            )
          : null,
      leading: nested
          ? null
          : const Icon(
              Icons.folder_rounded,
              size: 20,
              color: AppColors.accent,
            ),
      title: _label(
        nested ? e.subLabel : e.fullName,
      ),
      trailing: _count(e.count),
      selected: selected,
      selectedTileColor:
          AppColors.accent.withValues(alpha: 0.10),
      onTap: () =>
          widget.onSelectSub(e.fullName, country),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale =
        ref.watch(localeProvider).value?.code ?? 'tr';

    final maxH =
        MediaQuery.sizeOf(context).height * 0.82;

    final noneSelected =
        widget.selectedSmartId == null &&
        widget.selectedCountry == null &&
        widget.selectedSub == null;

    final searching = _query.isNotEmpty;
    final rows = <Widget>[];

    for (final s in widget.smartCategories) {
      if (searching && !_matches(s.label)) continue;

      rows.add(
        ListTile(
          leading: Icon(
            s.icon,
            size: 20,
            color: widget.selectedSmartId == s.id
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
          title: _label(s.label),
          trailing: _count(
            widget.smartCounts[s.id] ?? 0,
          ),
          selected: widget.selectedSmartId == s.id,
          selectedTileColor:
              AppColors.accent.withValues(alpha: 0.10),
          onTap: () => widget.onSelectSmart(s),
        ),
      );
    }

    if (!searching && rows.isNotEmpty) {
      rows.add(const Divider(height: 1));
    }

    if (!searching || _matches(widget.allLabel)) {
      rows.add(
        ListTile(
          leading: Icon(
            Icons.apps_rounded,
            size: 20,
            color: noneSelected
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
          title: _label(widget.allLabel),
          trailing: _count(widget.totalCount),
          selected: noneSelected,
          selectedTileColor:
              AppColors.accent.withValues(alpha: 0.10),
          onTap: widget.onSelectAll,
        ),
      );
    }

    for (final b in widget.buckets) {
      if (!searching) {
        if (b.country.isEmpty) {
          for (final e in b.entries) {
            rows.add(_entryTile(e, b.country));
          }
        } else {
          rows.add(_countrySection(b, locale));
        }

        continue;
      }

      final countryLabel = b.country.isEmpty
          ? ''
          : CountryNames.labelWithCode(
              b.country,
              locale: locale,
            );

      final countryMatches =
          b.country.isNotEmpty &&
          _matches('$countryLabel ${b.country}');

      if (countryMatches) {
        final total = b.entries.fold(
          0,
          (sum, e) => sum + e.count,
        );

        rows.add(
          ListTile(
            leading: const Icon(
              Icons.public_rounded,
              size: 20,
              color: AppColors.accent,
            ),
            title: _label(
              '$countryLabel · ${widget.allLabel}',
            ),
            trailing: _count(total),
            selected:
                widget.selectedCountry == b.country &&
                widget.selectedSub == null,
            selectedTileColor:
                AppColors.accent.withValues(alpha: 0.10),
            onTap: () =>
                widget.onSelectCountry(b.country),
          ),
        );
      }

      for (final e in b.entries) {
        if (countryMatches ||
            _matches(
              '${e.fullName} ${e.subLabel} '
              '$countryLabel ${b.country}',
            )) {
          rows.add(_entryTile(e, b.country));
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxH,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(
                  16, 0, 8, 2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                      color: AppColors.textSecondary,
                      tooltip: ref.tr('common.close'),
                      onPressed: () =>
                          Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 10,
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) => setState(() {
                    _query = value.trim().toLowerCase();
                  }),
                  onSubmitted: (_) =>
                      FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText:
                        ref.tr('common.searchInList'),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.accent,
                    ),
                    suffixIcon:
                        _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListTileTheme(
                  data: const ListTileThemeData(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    minLeadingWidth: 24,
                    horizontalTitleGap: 12,
                  ),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior
                            .onDrag,
                    padding: const EdgeInsets.only(
                      bottom: 16,
                    ),
                    children: rows.isEmpty
                        ? [
                            Padding(
                              padding:
                                  const EdgeInsets.all(24),
                              child: Text(
                                ref.tr('common.noResults'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color:
                                      AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ]
                        : rows,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countrySection(
    _CountryBucket b,
    String locale,
  ) {
    final countryLabel = CountryNames.labelWithCode(
      b.country,
      locale: locale,
    );

    final total = b.entries.fold(
      0,
      (sum, e) => sum + e.count,
    );

    final countrySelected =
        widget.selectedCountry == b.country;

    return ExpansionTile(
      key: PageStorageKey<String>(
        'category-country-${b.country}',
      ),
      initiallyExpanded: countrySelected,
      tilePadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      childrenPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.public_rounded,
        size: 20,
        color: countrySelected
            ? AppColors.accent
            : AppColors.textSecondary,
      ),
      title: Row(
        children: [
          Expanded(child: _label(countryLabel)),
          const SizedBox(width: 8),
          _count(total),
        ],
      ),
      children: [
        ListTile(
          contentPadding:
              const EdgeInsetsDirectional.only(
            start: 48,
            end: 16,
          ),
          title: _label(widget.allLabel),
          trailing: _count(total),
          selected: countrySelected &&
              widget.selectedSub == null,
          selectedTileColor:
              AppColors.accent.withValues(alpha: 0.10),
          onTap: () =>
              widget.onSelectCountry(b.country),
        ),
        for (final e in b.entries)
          _entryTile(e, b.country, nested: true),
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
  final void Function(String fullName, String country)
      onSelectSub;
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
      slivers.add(
        SliverToBoxAdapter(
          child: _SectionHeading(
            text: collectionsLabel,
          ),
        ),
      );

      for (final s in smartCategories) {
        slivers.add(
          SliverToBoxAdapter(
            child: _SidebarEntry(
              label: s.label,
              icon: s.icon,
              count: smartCounts[s.id] ?? 0,
              selected: selectedSmartId == s.id,
              onTap: () => onSelectSmart(s),
            ),
          ),
        );
      }

      slivers.add(
        const SliverToBoxAdapter(
          child: Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
        ),
      );
    }

    slivers.add(
      SliverToBoxAdapter(
        child: _SectionHeading(
          text: categoriesLabel,
        ),
      ),
    );

    slivers.add(
      SliverToBoxAdapter(
        child: _SidebarEntry(
          label: allLabel,
          count: total,
          selected: selectedSmartId == null &&
              selectedCountry == null &&
              selectedSub == null,
          onTap: onSelectAll,
        ),
      ),
    );

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
              onTap: () =>
                  onSelectSub(e.fullName, b.country),
            );
          },
          childCount: b.entries.length,
        ),
      );

      if (b.country.isEmpty) {
        slivers.add(list);
      } else {
        slivers.add(
          SliverStickyHeader(
            header: _CountryHeader(
              country: b.country,
              count: b.entries.fold(
                0,
                (s, e) => s + e.count,
              ),
              selected:
                  selectedCountry == b.country &&
                  selectedSub == null,
              onTap: () =>
                  onSelectCountry(b.country),
            ),
            sliver: list,
          ),
        );
      }
    }

    slivers.add(
      const SliverToBoxAdapter(
        child: SizedBox(height: 16),
      ),
    );

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

  const _SectionHeading({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20, 16, 20, 8,
      ),
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
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final locale =
        ref.watch(localeProvider).value?.code ?? 'tr';

    final label = CountryNames.labelWithCode(
      country,
      locale: locale,
    );

    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.14)
          : AppColors.surfaceElevated,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 9,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                margin: const EdgeInsets.only(
                  right: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent
                      : AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? AppColors.accent
                      : AppColors.textSecondary,
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
  State<_SidebarEntry> createState() =>
      _SidebarEntryState();
}

class _SidebarEntryState
    extends State<_SidebarEntry> {
  bool _hover = false;
  bool _focus = false;

  bool get _highlighted => _hover || _focus;

  @override
  Widget build(BuildContext context) {
    final accent = widget.selected || _focus;

    final color = accent
        ? AppColors.accent
        : AppColors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) =>
            setState(() => _focus = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey ==
                      LogicalKeyboardKey.select ||
                  event.logicalKey ==
                      LogicalKeyboardKey.enter ||
                  event.logicalKey ==
                      LogicalKeyboardKey.gameButtonA)) {
            widget.onTap();
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 140,
            ),
            padding: EdgeInsets.fromLTRB(
              widget.indented ? 36 : 18,
              8,
              18,
              8,
            ),
            color: widget.selected
                ? AppColors.accent.withValues(alpha: 0.10)
                : (_highlighted
                    ? AppColors.accent.withValues(alpha: 0.16)
                    : Colors.transparent),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 16,
                    color: accent
                        ? AppColors.accent
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: accent
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
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
  final Widget Function(BuildContext, MediaItem)
      itemBuilder;
  final List<Widget>? trailingHeader;
  final Widget? headerSlot;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final bool groupByCountry;
  final String searchHint;
  final String noResultsLabel;
  final String? Function(String name) countryOf;
  final VoidCallback? onOpenCategories;
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
  State<_MainPanel> createState() =>
      _MainPanelState();
}

class _MainPanelState extends State<_MainPanel> {
  final FocusNode? _searchFocus =
      PlatformInfo.isTv
          ? FocusNode(skipTraversal: true)
          : null;

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

    final slivers = <Widget>[];

    if (headerSlot != null) {
      slivers.add(
        SliverToBoxAdapter(child: headerSlot),
      );
    }

    final searchField = DpadTextField(
      child: TextField(
        focusNode: _searchFocus,
        controller: searchController,
        onChanged: onQueryChanged,
        decoration: InputDecoration(
          hintText: searchHint,
          prefixIcon: const Icon(
            Icons.search_rounded,
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                  onPressed: () {
                    searchController.clear();
                    onQueryChanged('');
                  },
                ),
        ),
      ),
    );

    if (widget.onOpenCategories != null) {
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeaderDelegate(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16, 12, 16, 8,
              ),
              child: _CategoriesButton(
                activeLabel: title,
                count: filteredCount,
                fallbackLabel:
                    widget.categoriesButtonLabel,
                hasActiveCategory:
                    widget.hasActiveCategory,
                onTap: widget.onOpenCategories!,
              ),
            ),
          ),
        ),
      );

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16, 0, 16, 10,
            ),
            child: searchField,
          ),
        ),
      );
    } else {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24, 14, 24, 10,
            ),
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
                            fontFeatures: [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 280,
                  child: searchField,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (trailingHeader != null &&
        trailingHeader.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 4,
            ),
            child: Row(children: trailingHeader),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      slivers.add(
        SliverFillRemaining(
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
        ),
      );
    } else if (groupByCountry) {
      slivers.addAll(
        _buildGroupedSlivers(context, items),
      );
    } else {
      final width = MediaQuery.sizeOf(context).width;

      final compactVod =
          widget.onOpenCategories != null &&
          itemMaxExtent == 180 &&
          width >= 360 &&
          width < 600;

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.all(
            compactVod ? 16 : 24,
          ),
          sliver: SliverGrid(
            gridDelegate: compactVod
                ? SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: itemAspectRatio,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  )
                : SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: itemMaxExtent,
                    childAspectRatio: itemAspectRatio,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                  ),
            delegate: SliverChildBuilderDelegate(
              (context, i) =>
                  itemBuilder(context, items[i]),
              childCount: items.length,
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      cacheExtent: 800,
      slivers: slivers,
    );
  }

  List<Widget> _buildGroupedSlivers(
    BuildContext context,
    List<MediaItem> visible,
  ) {
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

        return (firstSeen[a] ?? (1 << 30)).compareTo(
          firstSeen[b] ?? (1 << 30),
        );
      });

    final out = <Widget>[
      const SliverToBoxAdapter(
        child: SizedBox(height: 12),
      ),
    ];

    for (final k in keys) {
      out.add(
        SliverStickyHeader(
          header: _GroupHeader(
            country: k,
            count: m[k]!.length,
          ),
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              24, 12, 24, 24,
            ),
            sliver: SliverGrid(
              gridDelegate:
                  SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: widget.itemMaxExtent,
                childAspectRatio: widget.itemAspectRatio,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    widget.itemBuilder(context, m[k]![i]),
                childCount: m[k]!.length,
              ),
            ),
          ),
        ),
      );
    }

    return out;
  }
}

class _GroupHeader extends ConsumerWidget {
  final String country;
  final int count;

  const _GroupHeader({
    required this.country,
    required this.count,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final locale =
        ref.watch(localeProvider).value?.code ?? 'tr';

    final label = country == 'OTHER'
        ? ref.tr('common.other').toUpperCase()
        : CountryNames.labelWithCode(
            country,
            locale: locale,
          );

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 10,
      ),
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
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
