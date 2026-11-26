import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../shared/widgets/row_carousel.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/source_selector_bar.dart';
import '../../epg/providers/epg_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../player/presentation/player_page.dart';
import '../../recommendations/personalized_recommender.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/selected_source_provider.dart';
import '../../sources/providers/sources_provider.dart';
import 'backdrop_row.dart';
import 'hero_carousel.dart';
import 'live_channels_row.dart';
import 'new_episodes_row.dart';

/// Pool of home page rows. The top sections (the "fixed-top" layer)
/// don't belong to this enum - they always appear in the same order,
/// shown when there is content. Of the seven here, a different 5 are
/// picked each day and placed after the personal rows; the order depends
/// on `daySeed` and is stable within the day.
enum _RotatedRow {
  newMovies,
  newSeries,
  topMovies,
  topSeries,
  classics,
  // latestYears was removed from the rotation - it's shown in a fixed
  // position (above My Favorites) per user request. newEpisodes became a
  // separate SeriesDetail lazy-load row, outside the rotation.
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// Candidate list picked once for the hero carousel (5 items). Stays
  /// fixed for the session - if the user saw a movie in the hero, they
  /// still find the same carousel when they come back.
  List<MediaItem>? _heroCandidates;

  // Memoize cache: no recomputation as long as the source references +
  // daily seed stay the same.
  List<MediaItem>? _safeMoviesCache;
  List<MediaItem>? _safeMoviesRef;
  List<MediaItem>? _safeSeriesCache;
  List<MediaItem>? _safeSeriesRef;
  List<MediaItem>? _safeLiveCache;
  List<MediaItem>? _safeLiveRef;

  /// `_dayKey()` is computed on every launch; the rotation refreshes when
  /// the day changes. Only dayOfYear + year so it stays stable within the day.
  int _dayKey() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    return now.year * 1000 + dayOfYear;
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(sourcesProvider);
    // Global source selection: null = All Sources. Once a selection is
    // made, all of the home page's rows (hero, newest, continue,
    // favorites...) derive from that source's content. The dedicated pages
    // that see all sources (/library, /history, /continue) aren't affected.
    final selectedSource = ref.watch(selectedSourceProvider).value;
    final moviesAsync = ref.watch(
      libraryItemsProvider(
        LibraryItemsArgs(kind: MediaKind.movie, sourceId: selectedSource),
      ),
    );
    final seriesAsync = ref.watch(
      libraryItemsProvider(
        LibraryItemsArgs(kind: MediaKind.series, sourceId: selectedSource),
      ),
    );
    final liveAsync = ref.watch(
      libraryItemsProvider(
        LibraryItemsArgs(kind: MediaKind.live, sourceId: selectedSource),
      ),
    );
    final historyAsync = ref.watch(historyProvider);
    final favoritesAsync = ref.watch(favoritesProvider);

    // If the source list hasn't loaded yet, don't flash the "add source"
    // empty state - show a spinner instead. Otherwise on every cold start
    // the user sees a wrong empty state first, then a blank scaffold, then
    // the real content.
    if (sourcesAsync.isLoading && sourcesAsync.value == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

      if (!hasSources) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.live_tv_rounded,
                  size: 100,
                  color: Color(0xFFD4AF37),
                ),
                const SizedBox(height: 24),
                const Text(
                  'MEROUANESAT\nPREMIUM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Premium Streaming Experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 18,
                    ),
                  ),
                  onPressed: () => context.go('/sources/add'),
                  icon: const Icon(Icons.login),
                  label: const Text('LOGIN'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final movies = moviesAsync.value ?? const <MediaItem>[];
    final series = seriesAsync.value ?? const <MediaItem>[];
    final live = liveAsync.value ?? const <MediaItem>[];

    // If none of the content providers are ready (cold start, all the
    // libraryItemsProvider family calls are still fetching) show a spinner
    // instead of a black screen made of empty slivers.
    final allContentEmpty = movies.isEmpty && series.isEmpty && live.isEmpty;
    final stillLoadingContent = moviesAsync.isLoading ||
        seriesAsync.isLoading ||
        liveAsync.isLoading;
    if (allContentEmpty && stillLoadingContent) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final history = historyAsync.value ?? const <HistoryEntry>[];
    final favorites = favoritesAsync.value ?? const <String>{};

    final safeMovies = _safeMovies(movies);
    final safeSeries = _safeSeries(series);
    final safeLive = _safeLive(live);
    final dayKey = _dayKey();

    final slivers = <Widget>[
      SliverToBoxAdapter(child: _buildHero(context, safeMovies, safeSeries)),
      // Global source selector right below the hero (if >1 source).
      // Padding 24: the row titles/grid below are also aligned at 24.
      const SliverToBoxAdapter(
        child: SourceSelectorBar(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 6),
        ),
      ),
    ];

    // ── Layer A & B: fixed top + personal rows (keep order) ──
    final continueRow = _continueRow(context, ref, history, movies, series);
    if (continueRow != null)
      slivers.add(SliverToBoxAdapter(child: continueRow));

    final forYouRow = _forYouRow(context, ref, history, safeMovies, safeSeries);
    if (forYouRow != null) slivers.add(SliverToBoxAdapter(child: forYouRow));

    // Personal recommendation engine - scores TMDB-enriched candidates
    // with a profile derived from ratings + keywords + history + favorite +
    // watchlist signals. On a cold start (no signals) it returns an empty
    // list; the row isn't added then.
    final personalizedAsync = ref.watch(personalizedRecommendationsProvider);
    final personalizedItems = personalizedAsync.value ?? const [];
    if (personalizedItems.isNotEmpty) {
      final items = personalizedItems.take(20).map((r) => r.item).toList();
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RowCarousel(
              title: ref.tr('home.personalized'),
              items: items,
              onTapItem: (i) {
                if (i.kind == MediaKind.series) {
                  context.pushOnce('/series/${i.sourceId}/${i.streamId}');
                } else {
                  context.pushOnce('/movie/${i.sourceId}/${i.streamId}');
                }
              },
            ),
          ),
        ),
      );
    }

    // "Newest movies" in a fixed position - before My Favorites (user
    // request). 16:9 backdrop variant.
    final latestRow = _backdropFor(
      context,
      ref.tr('home.latestYears'),
      _latestYears(safeMovies),
    );
    if (latestRow != null) slivers.add(SliverToBoxAdapter(child: latestRow));

    // "Newly added series episodes" - the single MOST RECENTLY added
    // episode from each series that passes the last-90-days addedAt +
    // recent year filter (SeriesDetail provider lazy fetch). No more than
    // one episode from the same series.
    final recentSeries = _sortByAddedAt(
      safeSeries,
      requireRecentYear: true,
    ).take(30).toList();
    if (recentSeries.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(child: NewEpisodesRow(recentSeries: recentSeries)),
      );
    }

    // Live TV - BEFORE My Favorites. Smart selection: among the channels
    // currently on air in the EPG, in favorite -> history -> popular order.
    // "On now" title.
    final liveSelection = _smartLiveChannels(ref, safeLive, favorites, history);
    if (liveSelection.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: LiveChannelsRow(
            channels: liveSelection,
            title: ref.tr('home.liveNow'),
            onTap: (i) => context.pushOnce(
              '/player',
              extra: PlayerArgs(item: i, isLive: true, startAt: Duration.zero),
            ),
          ),
        ),
      );
    }

    final favRow = _favoritesRow(
      context,
      ref,
      favorites,
      safeMovies,
      safeSeries,
      safeLive,
    );
    if (favRow != null) slivers.add(SliverToBoxAdapter(child: favRow));

    final halfRow = _halfFinishedRow(
      context,
      ref,
      history,
      safeMovies,
      safeSeries,
    );
    if (halfRow != null) slivers.add(SliverToBoxAdapter(child: halfRow));

    // ── Layer C: rotated pool (5 rows, daySeed) ──
    // Spotlight band removed (user request) - instead of a single hero,
    // each row already shows several posters side by side.
    final rotated = _shuffleSeeded(
      _RotatedRow.values.toList(),
      dayKey,
    ).take(5).toList();
    for (var i = 0; i < rotated.length; i++) {
      final w = _buildRotatedRow(
        context,
        ref,
        rotated[i],
        history,
        safeMovies,
        safeSeries,
      );
      if (w != null) slivers.add(SliverToBoxAdapter(child: w));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 30)));

    return Scaffold(body: CustomScrollView(slivers: slivers));
  }

  // ── Helpers ────────────────────────────────────────────────────

  List<MediaItem> _safeMovies(List<MediaItem> items) {
    if (identical(_safeMoviesRef, items) && _safeMoviesCache != null) {
      return _safeMoviesCache!;
    }
    _safeMoviesRef = items;
    _safeMoviesCache = items.where((i) => !isAdult(i)).toList();
    return _safeMoviesCache!;
  }

  List<MediaItem> _safeSeries(List<MediaItem> items) {
    if (identical(_safeSeriesRef, items) && _safeSeriesCache != null) {
      return _safeSeriesCache!;
    }
    _safeSeriesRef = items;
    _safeSeriesCache = items.where((i) => !isAdult(i)).toList();
    return _safeSeriesCache!;
  }

  List<MediaItem> _safeLive(List<MediaItem> items) {
    if (identical(_safeLiveRef, items) && _safeLiveCache != null) {
      return _safeLiveCache!;
    }
    _safeLiveRef = items;
    _safeLiveCache = items.where((i) => !isAdult(i)).toList();
    return _safeLiveCache!;
  }

  /// Fisher-Yates seeded shuffle - same seed always gives the same order.
  List<T> _shuffleSeeded<T>(List<T> list, int seed) {
    final out = List<T>.of(list);
    final r = math.Random(seed);
    for (var i = out.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  /// Panel year + the "(YYYY)" pattern in the movie name - same logic as
  /// vod_browse_page but independent.
  int? _extractYear(MediaItem item) {
    if (item.year != null) return item.year;
    final m = RegExp(r'\((\d{4})\)').firstMatch(item.name);
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    if (y == null || y < 1900 || y > 2100) return null;
    return y;
  }

  bool _ratingOk(double? r) {
    if (r == null) return false;
    return r > 0.0 && r < 10.0;
  }

  /// The same movie/series gets added to the panel under several
  /// categories with the same name (e.g. three copies of "Esaretin Bedeli"
  /// under "Klasikler", "Yerli", "Onur Klasikleri"). Since the list arrives
  /// sorted, keep the first copy and drop the rest. Key: displayName + year
  /// - different years with the same name (e.g. "Bir Tat" 2022/2024) stay separate.
  List<MediaItem> _dedupByName(List<MediaItem> items) {
    final seen = <String>{};
    final out = <MediaItem>[];
    for (final i in items) {
      final key =
          '${i.displayName.toLowerCase().trim()}|'
          '${_extractYear(i) ?? ''}';
      if (!seen.add(key)) continue;
      out.add(i);
    }
    return out;
  }

  // ── Hero ───────────────────────────────────────────────────────

  Widget _buildHero(
    BuildContext context,
    List<MediaItem> movies,
    List<MediaItem> series,
  ) {
    if (_heroCandidates == null) {
      // Candidate pool: rating >= 7 (drops panel defaults), year >= 2010,
      // image available. Movies + series mixed. Session random instead of
      // day-seed - we don't want the hero card to keep changing while the
      // user browses the page, but they should see a fresh hero in a new session.
      final pool = <MediaItem>[];
      for (final i in [...movies, ...series]) {
        if (!_ratingOk(i.rating) || i.rating! < 7) continue;
        final y = _extractYear(i);
        if (y == null || y < 2010) continue;
        if ((i.backdropUrl == null || i.backdropUrl!.isEmpty) &&
            (i.logoUrl == null || i.logoUrl!.isEmpty)) {
          continue;
        }
        pool.add(i);
      }
      final deduped = _dedupByName(pool);
      if (deduped.isEmpty) {
        return const SizedBox(height: 460);
      }
      deduped.shuffle(math.Random());
      _heroCandidates = deduped.take(5).toList();
    }
    final items = _heroCandidates!;
    if (items.isEmpty) return const SizedBox(height: 460);
    return HeroCarousel(
      items: items,
      onPlay: (item) {
        if (item.kind == MediaKind.series) {
          context.pushOnce('/series/${item.sourceId}/${item.streamId}');
        } else {
          context.pushOnce(
            '/player',
            extra: PlayerArgs(
              item: item,
              isLive: false,
              startAt: Duration.zero,
            ),
          );
        }
      },
      onInfo: (item) {
        if (item.kind == MediaKind.series) {
          context.pushOnce('/series/${item.sourceId}/${item.streamId}');
        } else {
          context.pushOnce('/movie/${item.sourceId}/${item.streamId}');
        }
      },
    );
  }

  // ── Fixed-top rows ─────────────────────────────────────────────

  Widget? _continueRow(
    BuildContext context,
    WidgetRef ref,
    List<HistoryEntry> history,
    List<MediaItem> movies,
    List<MediaItem> series,
  ) {
    if (history.isEmpty) return null;
    final lookup = {
      for (final m in [...movies, ...series]) m.id: m,
    };
    final items = <MediaItem>[];
    final seen = <String>{};
    for (final h in history) {
      if (h.duration.inMilliseconds == 0) continue;
      if (h.progress < 0.02 || h.progress > 0.97) continue;
      final key = h.parentId ?? h.contentId;
      if (!seen.add(key)) continue;
      final item = lookup[key];
      if (item == null) continue;
      if (isAdult(item)) continue;
      if (item.kind == MediaKind.movie || item.kind == MediaKind.series) {
        items.add(item);
      }
      if (items.length >= 18) break;
    }
    if (items.length < 3) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: RowCarousel(
        title: ref.tr('home.continueWatching'),
        items: items,
        onTapItem: (i) {
          if (i.kind == MediaKind.series) {
            context.pushOnce('/series/${i.sourceId}/${i.streamId}');
          } else {
            context.pushOnce('/movie/${i.sourceId}/${i.streamId}');
          }
        },
        // "Manage" CTA removed (user request). The delete flow stays
        // accessible from the /continue page.
      ),
    );
  }

  /// "For you" - find the top 2 tokens from the history category
  /// frequency, then recommend high-rated movies/series from those genres.
  /// Offers fresh discovery in the genre the user likes. Skip if history is thin.
  Widget? _forYouRow(
    BuildContext context,
    WidgetRef ref,
    List<HistoryEntry> history,
    List<MediaItem> movies,
    List<MediaItem> series,
  ) {
    if (history.length < 5) return null;
    final allById = {
      for (final m in [...movies, ...series]) m.id: m,
    };
    // Count the movie/series categories in the history.
    final freq = <String, int>{};
    for (final h in history) {
      final base = allById[h.parentId ?? h.contentId];
      if (base == null) continue;
      final tokens = _categoryTokens(base.categoryName);
      for (final t in tokens) {
        freq.update(t, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    if (freq.isEmpty) return null;
    final topTokens =
        (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(2)
            .map((e) => e.key)
            .toSet();

    // Don't show contentIds that already appear in the history.
    final excluded = history.map((h) => h.parentId ?? h.contentId).toSet();
    final pool = <MediaItem>[];
    for (final i in [...movies, ...series]) {
      if (excluded.contains(i.id)) continue;
      if (!_ratingOk(i.rating) || i.rating! < 7) continue;
      final t = _categoryTokens(i.categoryName);
      if (t.intersection(topTokens).isEmpty) continue;
      pool.add(i);
    }
    if (pool.length < 6) return null;
    pool.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: RowCarousel(
        title: ref.tr('home.forYou'),
        items: pool.take(20).toList(),
        onTapItem: (i) {
          if (i.kind == MediaKind.series) {
            context.pushOnce('/series/${i.sourceId}/${i.streamId}');
          } else {
            context.pushOnce('/movie/${i.sourceId}/${i.streamId}');
          }
        },
      ),
    );
  }

  Widget? _favoritesRow(
    BuildContext context,
    WidgetRef ref,
    Set<String> favs,
    List<MediaItem> movies,
    List<MediaItem> series,
    List<MediaItem> live,
  ) {
    if (favs.isEmpty) return null;
    final all = [...movies, ...series, ...live];
    final byId = {for (final m in all) m.id: m};
    final items = favs.map((k) => byId[k]).whereType<MediaItem>().toList();
    if (items.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: RowCarousel(
        title: ref.tr('home.favorites'),
        items: items,
        onTapItem: (i) {
          if (i.kind == MediaKind.series) {
            context.pushOnce('/series/${i.sourceId}/${i.streamId}');
          } else if (i.kind == MediaKind.movie) {
            context.pushOnce('/movie/${i.sourceId}/${i.streamId}');
          } else {
            context.pushOnce(
              '/player',
              extra: PlayerArgs(item: i, isLive: true, startAt: Duration.zero),
            );
          }
        },
      ),
    );
  }

  /// "Half-finished" - progress between 15-70%, a narrower version of
  /// Continue Watching (2-97%). This is the "I gave up but maybe" segment.
  Widget? _halfFinishedRow(
    BuildContext context,
    WidgetRef ref,
    List<HistoryEntry> history,
    List<MediaItem> movies,
    List<MediaItem> series,
  ) {
    if (history.length < 4) return null;
    final lookup = {
      for (final m in [...movies, ...series]) m.id: m,
    };
    final items = <MediaItem>[];
    final seen = <String>{};
    for (final h in history) {
      if (h.duration.inMilliseconds == 0) continue;
      if (h.progress < 0.15 || h.progress > 0.70) continue;
      final key = h.parentId ?? h.contentId;
      if (!seen.add(key)) continue;
      final item = lookup[key];
      if (item == null) continue;
      if (isAdult(item)) continue;
      items.add(item);
      if (items.length >= 16) break;
    }
    if (items.length < 4) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: RowCarousel(
        title: ref.tr('home.halfFinished'),
        items: items,
        onTapItem: (i) {
          if (i.kind == MediaKind.series) {
            context.pushOnce('/series/${i.sourceId}/${i.streamId}');
          } else {
            context.pushOnce('/movie/${i.sourceId}/${i.streamId}');
          }
        },
      ),
    );
  }

  // ── Rotated rows ───────────────────────────────────────────────

  Widget? _buildRotatedRow(
    BuildContext context,
    WidgetRef ref,
    _RotatedRow kind,
    List<HistoryEntry> history,
    List<MediaItem> movies,
    List<MediaItem> series,
  ) {
    // Some rows use a 16:9 backdrop card variant - to break up the page's
    // poster flow. The rest keep the existing 2:3 poster.
    switch (kind) {
      case _RotatedRow.newMovies:
        return _backdropFor(
          context,
          ref.tr('home.newMovies'),
          _sortByAddedAt(movies),
        );
      case _RotatedRow.newSeries:
        return _carouselFor(
          context,
          ref,
          ref.tr('home.newSeries'),
          _sortByAddedAt(series, requireRecentYear: true),
          MediaKind.series,
        );
      case _RotatedRow.topMovies:
        return _backdropFor(
          context,
          ref.tr('home.topMovies'),
          _topRated(movies),
        );
      case _RotatedRow.topSeries:
        return _carouselFor(
          context,
          ref,
          ref.tr('home.topSeries'),
          _topRated(series),
          MediaKind.series,
        );
      case _RotatedRow.classics:
        return _carouselFor(
          context,
          ref,
          ref.tr('home.classics'),
          _classics(movies),
          MediaKind.movie,
        );
    }
  }

  Widget? _backdropFor(
    BuildContext context,
    String title,
    List<MediaItem> items,
  ) {
    if (items.length < 6) return null;
    // No landscape backdrop in demo mode (only 2:3 posters generated). Use
    // a portrait carousel instead of a backdrop row; every row at the same
    // aspect ratio, so App Store screenshots look consistent.
    final isDemo = items.first.sourceId == 'demo';
    if (isDemo) {
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: RowCarousel(
          title: title,
          items: items.take(20).toList(),
          onTapItem: (i) {
            if (i.kind == MediaKind.series) {
              context.pushOnce('/series/${i.sourceId}/${i.streamId}');
            } else {
              context.pushOnce('/movie/${i.sourceId}/${i.streamId}');
            }
          },
        ),
      );
    }
    return BackdropRow(
      title: title,
      items: items.take(20).toList(),
      onTap: (i) {
        if (i.kind == MediaKind.series) {
          context.pushOnce('/series/${i.sourceId}/${i.streamId}');
        } else {
          context.pushOnce('/movie/${i.sourceId}/${i.streamId}');
        }
      },
    );
  }

  Widget? _carouselFor(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<MediaItem> items,
    MediaKind kind,
  ) {
    if (items.length < 6) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: RowCarousel(
        title: title,
        items: items.take(20).toList(),
        onTapItem: (i) {
          if (i.kind == MediaKind.series) {
            context.pushOnce('/series/${i.sourceId}/${i.streamId}');
          } else {
            context.pushOnce('/movie/${i.sourceId}/${i.streamId}');
          }
        },
      ),
    );
  }

  // ── Rotation selectors ─────────────────────────────────────────

  /// "Newly added" means: panel `addedAt` within the LAST 90 DAYS. For
  /// series, `requireRecentYear` additionally requires the production year
  /// to be within the last 2 years - so that if a panel rebuild restores a
  /// 1985 series with "addedAt = today" it doesn't show up in the "New"
  /// list.
  List<MediaItem> _sortByAddedAt(
    List<MediaItem> items, {
    bool requireRecentYear = false,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));
    final yearMin = now.year - 1;
    final thisYear = now.year;
    final list = items.where((i) {
      // Some panels write addedAt into the future in a buggy way; the
      // "newly added" row shouldn't show items dated later than today.
      if (i.addedAt == null ||
          !i.addedAt!.isAfter(cutoff) ||
          i.addedAt!.isAfter(now)) {
        return false;
      }
      final y = _extractYear(i);
      // If the production year is later than today, it's not in the list.
      if (y != null && y > thisYear) return false;
      if (requireRecentYear) {
        if (y == null || y < yearMin) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) => b.addedAt!.compareTo(a.addedAt!));
    return _dedupByName(list);
  }

  /// So the "Top rated" row isn't shown in the same order every time:
  /// keep the top 60 by rating, take 20 of them with a day-seeded shuffle.
  /// The order is stable within the day, fresh the next day.
  List<MediaItem> _topRated(List<MediaItem> items) {
    final list = items.where((i) {
      final r = i.rating ?? 0;
      return r >= 7 && r < 10;
    }).toList();
    list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final deduped = _dedupByName(list);
    if (deduped.length <= 20) return deduped;
    final top = deduped.take(60).toList();
    return _shuffleSeeded(top, _dayKey() ^ items.hashCode);
  }

  /// "Newest movies" - per user request, FIRST the most recently added to
  /// the panel, then the production-year recency criterion. NO randomize;
  /// the same list starts from the most recently added on launch.
  List<MediaItem> _latestYears(List<MediaItem> items) {
    final now = DateTime.now();
    final thisYear = now.year;
    final yearCutoff = thisYear - 3;
    final list = items.where((i) {
      final y = _extractYear(i);
      // If the production year is later than today, keep it out of "Newest".
      if (y == null || y < yearCutoff || y > thisYear) return false;
      // Don't include it if addedAt is in the future - panel bug.
      if (i.addedAt != null && i.addedAt!.isAfter(now)) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      // Primary: most recently added first.
      final aA = a.addedAt;
      final bA = b.addedAt;
      if (aA != null && bA != null) {
        final cmp = bA.compareTo(aA);
        if (cmp != 0) return cmp;
      } else if (aA != null) {
        return -1;
      } else if (bA != null) {
        return 1;
      }
      // Secondary: production year desc (when there's no added date).
      final ay = _extractYear(a) ?? 0;
      final by = _extractYear(b) ?? 0;
      return by.compareTo(ay);
    });
    return _dedupByName(list.take(40).toList());
  }

  List<MediaItem> _classics(List<MediaItem> items) {
    final list = <MapEntry<MediaItem, int>>[];
    for (final i in items) {
      final y = _extractYear(i);
      if (y == null || y > 2000) continue;
      if (!_ratingOk(i.rating) || i.rating! < 7.5) continue;
      list.add(MapEntry(i, y));
    }
    // For classics "how highly rated" matters more, year is the tiebreak.
    list.sort((a, b) {
      final r = (b.key.rating ?? 0).compareTo(a.key.rating ?? 0);
      if (r != 0) return r;
      return b.value.compareTo(a.value);
    });
    final deduped = _dedupByName(list.map((e) => e.key).toList());
    // Daily rotation for classics too - shuffle 20 of the top 30.
    if (deduped.length <= 20) return deduped;
    return _shuffleSeeded(deduped.take(30).toList(), _dayKey() ^ 0xC1A5);
  }

  /// Channel selection for the home page's "On now" row. Random or panel
  /// order is NOT USED - among the channels that currently have a program
  /// in the EPG, in priority order:
  ///   1) Favorite channel + has EPG
  ///   2) Channel watched in history + has EPG
  ///   3) Popular TR channels (allowlist) + has EPG
  ///   4) Remaining channels with EPG
  /// With no EPG at all, same order as fallback but the EPG check is skipped.
  List<MediaItem> _smartLiveChannels(
    WidgetRef ref,
    List<MediaItem> channels,
    Set<String> favorites,
    List<HistoryEntry> history,
  ) {
    if (channels.isEmpty) return const [];
    final epg = ref.watch(epgProvider).value;
    final now = DateTime.now();
    final historyIds = history.map((h) => h.contentId).toSet();
    final freq = <String, int>{};
    for (final h in history) {
      freq.update(h.contentId, (v) => v + 1, ifAbsent: () => 1);
    }

    bool hasEpg(MediaItem c) {
      if (epg == null) return false;
      final cid = c.epgChannelId ?? c.streamId;
      return epg.nowPlaying(c.sourceId, cid, now) != null;
    }

    final live = <MediaItem>[];
    final seen = <String>{};
    void add(MediaItem c) {
      if (!seen.add(c.id)) return;
      live.add(c);
    }

    // 1) Favorite + EPG
    for (final c in channels) {
      if (live.length >= 15) break;
      if (!favorites.contains(c.id)) continue;
      if (!hasEpg(c)) continue;
      add(c);
    }
    // 2) History + EPG (most-watched first)
    final byFreqDesc =
        channels.where((c) => historyIds.contains(c.id) && hasEpg(c)).toList()
          ..sort((a, b) => (freq[b.id] ?? 0).compareTo(freq[a.id] ?? 0));
    for (final c in byFreqDesc) {
      if (live.length >= 15) break;
      add(c);
    }
    // 3) Popular TR + EPG
    for (final c in channels) {
      if (live.length >= 15) break;
      if (!_isPopularTr(c)) continue;
      if (!hasEpg(c)) continue;
      add(c);
    }
    // 4) Remaining with EPG
    for (final c in channels) {
      if (live.length >= 15) break;
      if (!hasEpg(c)) continue;
      add(c);
    }
    // If there's no EPG at all, same priority but EPG-check-free fallback
    if (live.isEmpty) {
      for (final c in channels) {
        if (live.length >= 15) break;
        if (favorites.contains(c.id) ||
            historyIds.contains(c.id) ||
            _isPopularTr(c)) {
          add(c);
        }
      }
      for (final c in channels) {
        if (live.length >= 15) break;
        add(c);
      }
    }
    return live;
  }

  bool _isPopularTr(MediaItem c) {
    final low = c.name.toLowerCase();
    const allow = [
      'trt 1',
      'trt1',
      'atv',
      'show tv',
      'star tv',
      'fox',
      'kanal d',
      'tv8',
      'ntv',
      'cnn türk',
      'cnnturk',
      'beyaz tv',
      'now tv',
    ];
    if (allow.any(low.contains)) return true;
    final cat = c.categoryName?.toLowerCase() ?? '';
    return cat.startsWith('tr') || cat.contains('türk') || cat.contains('turk');
  }
}

/// M3U `group-title` based genre-token extraction - consistent with
/// discover_tab.
Set<String> _categoryTokens(String? name) {
  if (name == null) return const <String>{};
  final low = name.toLowerCase();
  final out = <String>{};
  if (low.contains('spor') || low.contains('sport')) out.add('spor');
  if (low.contains('haber') || low.contains('news')) out.add('haber');
  if (low.contains('film') || low.contains('movie') || low.contains('cinema')) {
    out.add('film');
  }
  if (low.contains('belgesel') || low.contains('document')) out.add('belgesel');
  if (low.contains('çocuk') ||
      low.contains('cocuk') ||
      low.contains('kids') ||
      low.contains('cartoon')) {
    out.add('cocuk');
  }
  if (low.contains('müzik') || low.contains('muzik') || low.contains('music')) {
    out.add('muzik');
  }
  if (low.contains('dizi') || low.contains('series') || low.contains('drama')) {
    out.add('dizi');
  }
  if (low.contains('aksiyon') || low.contains('action')) out.add('aksiyon');
  if (low.contains('komedi') || low.contains('comedy')) out.add('komedi');
  if (low.contains('romantik') ||
      low.contains('romance') ||
      low.contains('aşk') ||
      low.contains('ask')) {
    out.add('romantik');
  }
  if (low.contains('korku') || low.contains('horror')) out.add('korku');
  if (low.contains('animasyon') ||
      low.contains('animation') ||
      low.contains('anime')) {
    out.add('animasyon');
  }
  return out;
}
