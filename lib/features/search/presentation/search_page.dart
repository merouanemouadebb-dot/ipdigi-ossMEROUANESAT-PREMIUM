import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/utils/fuzzy.dart';
import '../../../core/widgets/dpad_text_field.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../core/metadata/tmdb_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../epg/providers/epg_provider.dart';
import '../../player/presentation/player_page.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  MediaKind? _kindFilter;
  int? _yearMin;
  int? _yearMax;
  double? _ratingMin;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      setState(() => _query = value);
    });
  }

  /// Treat scene-release punctuation as whitespace so "Mission Impossible"
  /// matches "Mission.Impossible.1.1996.REMASTERED". Without this the
  /// query "Mission Impossible" scored nearly zero against the dotted
  /// catalog name and the user saw an empty result the moment they typed
  /// a space - which read like "spaces are blocked".
  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[._\-]+'), ' ').trim();

  List<MediaItem> _filter(
    List<MediaItem> all,
    Map<String, ({String? originalTitle, String? localizedTitle})> altTitles,
    List<TmdbSearchHit> tmdbHits,
  ) {
    Iterable<MediaItem> result = all;
    if (_kindFilter != null) {
      result = result.where((i) => i.kind == _kindFilter);
    }
    if (_yearMin != null) {
      result = result.where((i) => (i.year ?? 0) >= _yearMin!);
    }
    if (_yearMax != null) {
      result = result.where((i) => (i.year ?? 9999) <= _yearMax!);
    }
    if (_ratingMin != null) {
      result = result.where((i) => (i.rating ?? 0) >= _ratingMin!);
    }
    final filtered = result.toList();
    final q = _normalize(_query);
    if (q.isEmpty) {
      filtered.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return filtered.take(120).toList();
    }
    // Token-based AND search with a fuzzy fallback per token so typos
    // ("Expandables" vs "Expendables") still hit. Short tokens still
    // need an exact substring to avoid noisy matches on common letters.
    bool tokenHit(String token, String normalizedName) {
      if (normalizedName.contains(token)) return true;
      if (token.length < 4) return false;
      for (final word in normalizedName.split(RegExp(r'\s+'))) {
        if (word.length < 4) continue;
        if (partialRatio(token, word) >= 85) return true;
      }
      return false;
    }

    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    // PERFORMANCE: on a 45K catalog the old code, on every keystroke,
    //   filtered.length × tmdbHits.length × titles × partialRatio
    // computed the above (≈720K fuzzy matches × ~150 ops = 100M+ ops =
    // main thread freeze). New approach: normalize the TMDB hit titles
    // ONCE into a set; per item only a substring check (16 contains per
    // item). Fuzzy is unnecessary because the localized TMDB title
    // already matches the panel name exactly.
    final tmdbAliases = <String>[];
    for (final hit in tmdbHits) {
      final t = hit.title.isEmpty ? '' : _normalize(hit.title);
      final o = hit.originalTitle.isEmpty ? '' : _normalize(hit.originalTitle);
      if (t.isNotEmpty && !tmdbAliases.contains(t)) tmdbAliases.add(t);
      if (o.isNotEmpty && !tmdbAliases.contains(o)) tmdbAliases.add(o);
    }

    // Searchable alias set for an item: panel name + persisted TMDB
    // altTitles + a query-time TMDB alias match per item. Normalizing
    // Item.name is expensive (regex), so we cache it.
    final normNameCache = <String, String>{};
    String normNameFor(MediaItem item) =>
        normNameCache[item.id] ??= _normalize(item.name);

    final aliasCache = <String, List<String>>{};
    List<String> aliasesFor(MediaItem item) {
      final cached = aliasCache[item.id];
      if (cached != null) return cached;
      final out = <String>[];
      final n0 = normNameFor(item);
      if (n0.isNotEmpty) out.add(n0);
      final alt = altTitles[item.id];
      if (alt != null) {
        for (final r in [alt.originalTitle, alt.localizedTitle]) {
          if (r == null) continue;
          final n = _normalize(r);
          if (n.isNotEmpty && !out.contains(n)) out.add(n);
        }
      }
      // TMDB query alias: substring match only (no fuzzy).
      // "Kara Kule" item.name + "kara kule" TMDB title → match.
      for (final t in tmdbAliases) {
        if (n0.contains(t) || t.contains(n0)) {
          if (!out.contains(t)) out.add(t);
        }
      }
      aliasCache[item.id] = out;
      return out;
    }

    final hits = filtered.where((item) {
      final names = aliasesFor(item);
      // At least one alternative must contain all the tokens (each
      // alternative is evaluated independently; "Dark Knight" catches all
      // the tokens on "The Dark Knight", so the item matches even if it
      // doesn't catch them on "Kara Sovalye").
      return names.any((n) => tokens.every((t) => tokenHit(t, n)));
    }).toList();

    final firstToken = tokens.first;
    final scoreCache = <String, ({int start, int pos})>{};
    ({int start, int pos}) scoreOf(MediaItem item) {
      final s = scoreCache[item.id];
      if (s != null) return s;
      var start = 1;
      var pos = 1 << 30;
      for (final n in aliasesFor(item)) {
        if (start == 1 && n.startsWith(q)) start = 0;
        final p = n.indexOf(firstToken);
        if (p >= 0 && p < pos) pos = p;
      }
      final v = (start: start, pos: pos);
      scoreCache[item.id] = v;
      return v;
    }

    // Performance: removed the fuzzy partialRatio from the sort
    // comparator - hits are already filtered by tokenHit, so position is
    // enough instead of an extra ranking ratio. partialRatio was the
    // most expensive operation (~3-4 ms per item); removing it dropped
    // the sort time on a large catalog from seconds to milliseconds.
    hits.sort((a, b) {
      final sa = scoreOf(a);
      final sb = scoreOf(b);
      if (sa.start != sb.start) return sa.start - sb.start;
      return sa.pos - sb.pos;
    });
    return hits.take(120).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Don't try to load anything on first entry to the page - on large
    // catalogs libraryItemsProvider queues hundreds of MB of posters. We
    // trigger the provider once the user types at least 2 characters;
    // until then we show a plain "Start searching" empty state
    // instead.
    final hasQuery = _query.trim().length >= 2;
    final all = hasQuery
        ? ref.watch(libraryItemsProvider(const LibraryItemsArgs()))
        : null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: DpadTextField(
                child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                autofocus: true,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: ref.tr('search.hint'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: ref.tr('search.filterAll'),
                      selected: _kindFilter == null,
                      onTap: () => setState(() => _kindFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: ref.tr('search.filterMovies'),
                      selected: _kindFilter == MediaKind.movie,
                      onTap: () =>
                          setState(() => _kindFilter = MediaKind.movie),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: ref.tr('search.filterSeries'),
                      selected: _kindFilter == MediaKind.series,
                      onTap: () =>
                          setState(() => _kindFilter = MediaKind.series),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: ref.tr('search.filterLive'),
                      selected: _kindFilter == MediaKind.live,
                      onTap: () => setState(() => _kindFilter = MediaKind.live),
                    ),
                    const SizedBox(width: 16),
                    _yearChip(),
                    const SizedBox(width: 8),
                    _ratingChip(),
                  ],
                ),
              ),
            ),
            Expanded(
              child: all == null
                  ? EmptyStateView(
                      icon: Icons.search_rounded,
                      title: ref.tr('search.start'),
                      message: ref.tr('search.hint'),
                    )
                  : all.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text('${ref.tr('common.error')}: $e')),
                      data: (items) {
                        // Original + localized titles persisted from TMDB;
                        // we pass them to the filter so search runs over
                        // both the panel name and the alternative titles. If
                        // not loaded yet, an empty map matches the panel name.
                        final altTitles =
                            ref.watch(alternateTitlesProvider).value ??
                            const {};
                        // Query-time TMDB search: match "Dark Tower" →
                        // "Kara Kule" even for items the user hasn't opened
                        // the detail page for yet. The provider returns
                        // empty before 3 characters.
                        final tmdbHits =
                            ref.watch(tmdbQuerySearchProvider(_query)).value ??
                            const <TmdbSearchHit>[];
                        final results = _filter(items, altTitles, tmdbHits);
                        // Programme-title search runs in parallel - the user
                        // can type "Galatasaray" and discover the match
                        // without knowing the channel name first.
                        final epgSnap = ref.watch(epgProvider).value;
                        final epgHits =
                            (_query.trim().length >= 2 && epgSnap != null)
                            ? epgSnap.search(_query, DateTime.now(), limit: 20)
                            : const <EpgSearchHit>[];

                        if (results.isEmpty && epgHits.isEmpty) {
                          return Center(
                            child: Text(
                              _query.isEmpty
                                  ? ref.tr('search.start')
                                  : ref.tr('search.noMatch'),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        final channelLookup = {for (final i in items) i.id: i};

                        return CustomScrollView(
                          cacheExtent: 800,
                          slivers: [
                            if (epgHits.isNotEmpty) ...[
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  6,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Text(
                                    ref.tr('search.programs').toUpperCase(),
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                      letterSpacing: 1.6,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                sliver: SliverList.separated(
                                  itemCount: epgHits.length,
                                  separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    color: AppColors.divider,
                                  ),
                                  itemBuilder: (context, i) {
                                    final hit = epgHits[i];
                                    final id = MediaItem.makeId(
                                      hit.sourceId,
                                      hit.channelId,
                                    );
                                    // EPG channelId is the XMLTV id; try the
                                    // composite first, fall back to scanning
                                    // the source's items for an
                                    // epgChannelId match.
                                    MediaItem? channel = channelLookup[id];
                                    channel ??= items.firstWhereOrNull(
                                      (m) =>
                                          m.sourceId == hit.sourceId &&
                                          (m.epgChannelId == hit.channelId ||
                                              m.streamId == hit.channelId),
                                    );
                                    return _EpgHitRow(
                                      hit: hit,
                                      channel: channel,
                                      onTap: channel == null
                                          ? null
                                          : () => context.pushOnce(
                                              '/player',
                                              extra: PlayerArgs(
                                                item: channel!,
                                                isLive: true,
                                                startAt: Duration.zero,
                                              ),
                                            ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            if (results.isNotEmpty) ...[
                              if (epgHits.isNotEmpty)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 22, 20, 6),
                                  sliver: SliverToBoxAdapter(
                                    child: Text(
                                      ref.tr('search.channelsAndContent'),
                                      style: const TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                        letterSpacing: 1.6,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              SliverPadding(
                                padding: const EdgeInsets.all(20),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 180,
                                        childAspectRatio: 2 / 3.4,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 18,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    i,
                                  ) {
                                    final item = results[i];
                                    return PosterCard(
                                      item: item,
                                      onTap: () {
                                        switch (item.kind) {
                                          case MediaKind.movie:
                                            context.pushOnce(
                                              '/movie/${item.sourceId}/${item.streamId}',
                                            );
                                            break;
                                          case MediaKind.series:
                                            context.pushOnce(
                                              '/series/${item.sourceId}/${item.streamId}',
                                            );
                                            break;
                                          case MediaKind.live:
                                            context.pushOnce(
                                              '/player',
                                              extra: PlayerArgs(
                                                item: item,
                                                isLive: true,
                                                startAt: Duration.zero,
                                              ),
                                            );
                                            break;
                                        }
                                      },
                                    );
                                  }, childCount: results.length),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _SearchChip(
      onTap: onTap,
      selected: selected,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _yearChip() {
    final hasFilter = _yearMin != null || _yearMax != null;
    return _SearchChip(
      selected: hasFilter,
      onTap: () async {
        final result = await showDialog<(int?, int?)>(
          context: context,
          useRootNavigator: true,
          builder: (_) =>
              _YearDialog(initialMin: _yearMin, initialMax: _yearMax),
        );
        if (result != null) {
          setState(() {
            _yearMin = result.$1;
            _yearMax = result.$2;
          });
        }
      },
      child: Text(
        hasFilter
            ? '${ref.tr('search.year')}: ${_yearMin ?? "..."} - ${_yearMax ?? "..."}'
            : ref.tr('search.year'),
        style: TextStyle(
          color: hasFilter ? Colors.white : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: hasFilter ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _ratingChip() {
    final hasFilter = _ratingMin != null;
    return _SearchChip(
      selected: hasFilter,
      onTap: () {
        setState(() {
          if (_ratingMin == null) {
            _ratingMin = 7.0;
          } else if (_ratingMin == 7.0) {
            _ratingMin = 8.0;
          } else if (_ratingMin == 8.0) {
            _ratingMin = 9.0;
          } else {
            _ratingMin = null;
          }
        });
      },
      child: Text(
        hasFilter
            ? '⭐ ${_ratingMin!.toStringAsFixed(1)}+'
            : ref.tr('search.rating'),
        style: TextStyle(
          color: hasFilter ? Colors.white : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: hasFilter ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Search filter chip. Focusable on the TV remote: navigated with the
/// D-pad, triggered with SELECT/OK; accent border when focused.
class _SearchChip extends StatefulWidget {
  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  const _SearchChip({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SearchChip> createState() => _SearchChipState();
}

class _SearchChipState extends State<_SearchChip> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.accent
                : (_focus
                    ? AppColors.accent.withValues(alpha: 0.16)
                    : AppColors.surface),
            borderRadius: BorderRadius.circular(20),
            border: (_focus && PlatformInfo.isTv)
                ? Border.all(color: AppColors.accent, width: 3)
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _YearDialog extends ConsumerStatefulWidget {
  final int? initialMin;
  final int? initialMax;
  const _YearDialog({this.initialMin, this.initialMax});

  @override
  ConsumerState<_YearDialog> createState() => _YearDialogState();
}

class _YearDialogState extends ConsumerState<_YearDialog> {
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    _min = TextEditingController(text: widget.initialMin?.toString() ?? '');
    _max = TextEditingController(text: widget.initialMax?.toString() ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(ref.tr('search.yearRange')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DpadTextField(
            child: TextField(
              controller: _min,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: ref.tr('search.minYear')),
            ),
          ),
          const SizedBox(height: 12),
          DpadTextField(
            child: TextField(
              controller: _max,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: ref.tr('search.maxYear')),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop((null, null)),
          child: Text(ref.tr('search.clear')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(ref.tr('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(
            context,
            rootNavigator: true,
          ).pop((int.tryParse(_min.text), int.tryParse(_max.text))),
          child: Text(ref.tr('search.apply')),
        ),
      ],
    );
  }
}

class _EpgHitRow extends ConsumerStatefulWidget {
  final EpgSearchHit hit;
  final MediaItem? channel;
  final VoidCallback? onTap;
  const _EpgHitRow({required this.hit, required this.channel, this.onTap});

  @override
  ConsumerState<_EpgHitRow> createState() => _EpgHitRowState();
}

class _EpgHitRowState extends ConsumerState<_EpgHitRow> {
  bool _focus = false;

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  String _whenLabel(WidgetRef ref, EpgSearchHit hit, DateTime now) {
    final start = hit.program.start.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final dayDelta = startDay.difference(today).inDays;
    final time = _hm(hit.program.start);
    if (dayDelta == 0) return '${ref.tr('common.today')} $time';
    if (dayDelta == 1) return '${ref.tr('common.tomorrow')} $time';
    final mm = start.month.toString().padLeft(2, '0');
    final dd = start.day.toString().padLeft(2, '0');
    return '$mm-$dd $time';
  }

  @override
  Widget build(BuildContext context) {
    final hit = widget.hit;
    final now = DateTime.now();
    final isLive = hit.program.isLiveAt(now);
    final ch = widget.channel;
    return Focus(
      onFocusChange: (v) => setState(() => _focus = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _focus
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: (_focus && PlatformInfo.isTv)
                ? Border.all(color: AppColors.accent, width: 3)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 92,
              child: isLive
                  ? Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ref.tr('live.badge'),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _whenLabel(ref, hit, now),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.program.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ch?.displayName ?? hit.channelId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isLive
                  ? Icons.play_circle_filled_rounded
                  : Icons.schedule_rounded,
              color: isLive ? AppColors.accent : AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
