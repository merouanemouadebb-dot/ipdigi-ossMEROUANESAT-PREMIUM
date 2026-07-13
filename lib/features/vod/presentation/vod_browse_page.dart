import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/nav_throttle.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/category_browse_layout.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/source_selector_bar.dart';
import '../../library/providers/library_provider.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/selected_source_provider.dart';
import '../../sources/providers/sources_provider.dart';
import 'movie_category_hero.dart';

enum VodKind { movie, series }

/// Extract the release year from the panel `year` field, or otherwise from
/// the `(YYYY)` pattern at the end of the movie name. Many IPTV panels
/// leave the year field empty for Turkish movies, but the year in
/// parentheses is usually present in the movie name.
int? _extractYear(MediaItem item) {
  if (item.year != null) return item.year;
  final m = RegExp(r'\((\d{4})\)').firstMatch(item.name);
  if (m == null) return null;
  final y = int.tryParse(m.group(1)!);
  if (y == null) return null;
  if (y < 1900 || y > 2100) return null;
  return y;
}

class VodBrowsePage extends ConsumerStatefulWidget {
  final VodKind kind;
  const VodBrowsePage({super.key, required this.kind});

  @override
  ConsumerState<VodBrowsePage> createState() => _VodBrowsePageState();
}

class _VodBrowsePageState extends ConsumerState<VodBrowsePage> {
  String _sort = 'package';

  MediaKind get _mediaKind =>
      widget.kind == VodKind.movie ? MediaKind.movie : MediaKind.series;
  String _title(WidgetRef ref) => widget.kind == VodKind.movie
      ? ref.tr('nav.movies')
      : ref.tr('nav.series');

  @override
  Widget build(BuildContext context) {
    // Global source selection: null = All Sources (everything combined),
    // set = only that source's content. The selector is shown below the hero.
    final selectedSource = ref.watch(selectedSourceProvider).value;
    final itemsAsync = ref.watch(
      libraryItemsProvider(
        LibraryItemsArgs(kind: _mediaKind, sourceId: selectedSource),
      ),
    );
    final favorites = ref.watch(favoritesProvider).value ?? const <String>{};
    final showAdult = ref.watch(adultFilterProvider).value?.showAdult ?? false;

    return Scaffold(
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateView(
              icon: widget.kind == VodKind.movie
                  ? Icons.movie_rounded
                  : Icons.tv_rounded,
              title: ref.tr('movies.noContent'),
              message: ref.tr('movies.noContentMsg'),
              action: ElevatedButton(
                onPressed: () => context.go('/sources/add'),
                child: Text(ref.tr('sources.add')),
              ),
            );
          }
          // When the adult filter is OFF, hide XXX categories entirely:
          // drop the adult items from items, and since the sidebar's
          // `_byCategory` map is built from items, the adult category
          // entries are cleaned up automatically. When ON, filter nothing.
          final safeItems = showAdult
              ? List<MediaItem>.of(items)
              : items.where((i) => !isAdult(i)).toList();
          // The "Top rated" smart category must be INDEPENDENT of the adult
          // filter state - even if the user explicitly enables XXX, they
          // don't want to see porn in the "Top Rated" list.
          // Always use an adult-free pool.
          final adultFreeItems = showAdult
              ? items.where((i) => !isAdult(i)).toList()
              : safeItems;
          final sorted = List<MediaItem>.of(safeItems);
          switch (_sort) {
            case 'package':
              break;
            case 'year':
              sorted.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
              break;
            case 'rating':
              sorted.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
              break;
            case 'name':
              sorted.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
              break;
          }
          final smart = <SmartCategoryDef>[
            SmartCategoryDef(
              id: 'favs',
              label: ref.tr('nav.favorites'),
              icon: Icons.favorite_rounded,
              selector: (all) =>
                  all.where((i) => favorites.contains(i.id)).toList(),
            ),
            SmartCategoryDef(
              id: 'top',
              label: ref.tr('vod.topRated'),
              icon: Icons.star_border_rounded,
              selector: (_) {
                // Even if the adult filter is on, don't show XXX in the
                // top rated - user request. adultFreeItems is always an
                // adult-free snapshot.
                // Exclude the panel default values 0 and 10 - just like
                // in the hero pool, show the real ratings here too and
                // nothing else.
                final list = adultFreeItems.where((i) {
                  final r = i.rating ?? 0;
                  return r >= 7 && r < 10;
                }).toList();
                list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
                return list;
              },
            ),
            SmartCategoryDef(
              id: 'newest',
              label: ref.tr('vod.newest'),
              icon: Icons.calendar_today_rounded,
              selector: (_) {
                // "Newest" - by release year. The panel `releaseyear`
                // comes null for most Turkish movies, so we also catch the
                // "(YYYY)" pattern at the end of the movie/series name
                // ("Accused (2026) Multi" -> 2026). There is NO addedAt
                // fallback; otherwise it clashed with "Recently added".
                // Items dated later than the current year (e.g. "2027") are
                // excluded - user request: a movie not yet released
                // shouldn't appear in "newest".
                final now = DateTime.now();
                final thisYear = now.year;
                final pairs = <MapEntry<MediaItem, int>>[];
                for (final i in safeItems) {
                  final y = _extractYear(i);
                  if (y == null || y > thisYear) continue;
                  // If addedAt is in the future it's a panel bug - ignore it.
                  if (i.addedAt != null && i.addedAt!.isAfter(now)) {
                    continue;
                  }
                  pairs.add(MapEntry(i, y));
                }
                pairs.sort((a, b) {
                  final cmp = b.value.compareTo(a.value);
                  if (cmp != 0) return cmp;
                  // Same year: tiebreak by the added date.
                  final aA = a.key.addedAt;
                  final bA = b.key.addedAt;
                  if (aA != null && bA != null) return bA.compareTo(aA);
                  if (aA != null) return -1;
                  if (bA != null) return 1;
                  return 0;
                });
                return pairs.map((e) => e.key).take(120).toList();
              },
            ),
            SmartCategoryDef(
              id: 'new',
              label: ref.tr('vod.recentlyAdded'),
              icon: Icons.fiber_new_rounded,
              selector: (_) {
                // "Recently added" - by the panel add date (Xtream
                // `added`). Year fallback if there's no addedAt. Don't
                // include it if addedAt or year is in the future - panel bug.
                final now = DateTime.now();
                final thisYear = now.year;
                final list = safeItems.where((i) {
                  final hasAdded = i.addedAt != null;
                  final hasYear = i.year != null;
                  if (!hasAdded && !hasYear) return false;
                  if (hasAdded && i.addedAt!.isAfter(now)) return false;
                  if (i.year != null && i.year! > thisYear) return false;
                  return true;
                }).toList();
                list.sort((a, b) {
                  final aAdded = a.addedAt;
                  final bAdded = b.addedAt;
                  if (aAdded != null && bAdded != null) {
                    final cmp = bAdded.compareTo(aAdded);
                    if (cmp != 0) return cmp;
                    return (b.year ?? 0).compareTo(a.year ?? 0);
                  }
                  if (aAdded != null) return -1;
                  if (bAdded != null) return 1;
                  return (b.year ?? 0).compareTo(a.year ?? 0);
                });
                return list.take(80).toList();
              },
            ),
          ];
          // The "Continue" smart category is intentionally absent here -
          // the delete / bulk-delete flow is consolidated in one place on
          // the /continue page. Showing it here only opened cards without
          // giving the user a way to delete.

          return CategoryBrowseLayout(
            title: _title(ref),
            items: sorted,
            smartCategories: smart,
            // Sort dropdown removed - user request. The hero and sidebar
            // smart categories already offer the "newest / most
            // frequent / top rated" orderings; an extra dropdown was
            // just noise.
            // Hero category-themed banner. It scrolls up when scrolling
            // (CategoryBrowseLayout now integrates the header slot as a
            // sliver via CustomScrollView).
            headerSlotBuilder: (context, selection) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHero(ref, selection),
                // Global source selector right below the hero (visible if
                // >1 source, hides itself otherwise).
                const SourceSelectorBar(),
              ],
            ),
            itemBuilder: (context, item) => PosterCard(
              item: item,
              onTap: () {
                if (widget.kind == VodKind.movie) {
                  context.pushOnce('/movie/${item.sourceId}/${item.streamId}');
                } else {
                  context.pushOnce('/series/${item.sourceId}/${item.streamId}');
                }
              },
            ),
          );
        },
      ),
    );
  }

  /// Don't hide the hero selection in the "All" view; on each category the
  /// selection hands the full list along with seedKey to the hero. Adult is
  /// always removed from [selection.items] - no extra filter here.
  Widget _buildHero(WidgetRef ref, CategorySelection selection) {
    if (selection.smartId != null) {
      // We don't make a separate hero for smart categories (favorites /
      // top / new) - collection logic isn't like the category theme logic.
      return const SizedBox.shrink();
    }
    if (selection.fullName == null && selection.country == null) {
      // "All" view: a neutral "Featured" hero.
      return MovieCategoryHero(
        seedKey: 'all',
        categoryName: null,
        title: ref.tr('vod.featured'),
        categoryItems: selection.items,
        kind: widget.kind,
      );
    }
    final seed =
        selection.fullName ??
        selection.country ??
        selection.subCategory ??
        'all';
    final title = selection.subCategory ?? selection.country ?? '';
    return MovieCategoryHero(
      seedKey: seed,
      categoryName: selection.fullName ?? selection.country,
      title: title.isEmpty
          ? ref.tr(widget.kind == VodKind.movie ? 'nav.movies' : 'nav.series')
          : title,
      categoryItems: selection.items,
      kind: widget.kind,
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final WidgetRef ref;
  const _SortDropdown({
    required this.value,
    required this.onChanged,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.sort_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          items: [
            DropdownMenuItem(
              value: 'package',
              child: Text(ref.tr('common.sortByPackage')),
            ),
            DropdownMenuItem(
              value: 'name',
              child: Text(ref.tr('common.sortByName')),
            ),
            DropdownMenuItem(
              value: 'year',
              child: Text(ref.tr('common.sortByYear')),
            ),
            DropdownMenuItem(
              value: 'rating',
              child: Text(ref.tr('common.sortByRating')),
            ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
