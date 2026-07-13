import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/demo/demo_mode.dart';
import '../../../core/network/dio_client.dart';
import '../../library/providers/library_provider.dart';
import '../../recommendations/related_provider.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../data/source_repository.dart';
import '../domain/category_decomposer.dart';
import '../domain/media_item.dart';
import '../domain/source.dart';

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  return SourceRepository(
    db: ref.watch(databaseProvider),
    dio: ref.watch(dioProvider),
  );
});

class SourcesNotifier extends AsyncNotifier<List<IptvSource>> {
  /// Source ids whose refresh is currently in flight. Startup auto-refresh,
  /// the profile pull-to-refresh and the per-tile refresh button can all fire
  /// for the same source at once; without this guard each one re-downloads the
  /// full catalogue and they race on the cache wipe/reinsert, leaving a
  /// partially populated table. A concurrent refresh of the same id is skipped.
  final Set<String> _refreshing = <String>{};

  @override
  Future<List<IptvSource>> build() async {
    // Demo mode: returns a fake "Demo Library" source instead of the real
    // source list. The home page's `hasSources` check passes and the real
    // catalog loads instead of the welcome screen; libraryItemsProvider
    // already fills 24 fake movies via the demo override.
    final demo = ref.watch(demoModeProvider).value;
    if (demo != null && demo.active) {
      return [
        M3uSource(
          id: 'demo',
          name: 'Demo Library',
          createdAt: DateTime.now(),
          urlOrPath: 'demo://library',
          epgUrl: null,
        ),
      ];
    }
    return ref.read(sourceRepositoryProvider).listSources();
  }

  Future<void> addSource(IptvSource src, {bool autoLoad = true}) async {
    final repo = ref.read(sourceRepositoryProvider);
    await repo.upsertSource(src);
    if (autoLoad) {
      try {
        await repo.loadSource(src);
      } catch (_) {
        // surfaced separately via load provider
      }
    }
    ref.invalidateSelf();
    ref.invalidate(libraryItemsProvider);
  }

  Future<void> removeSource(String id) async {
    // ignore: avoid_print
    print('[${AppConfig.I.appName}] removeSource start id=$id');
    final current = state.value ?? const <IptvSource>[];
    state = AsyncData(current.where((s) => s.id != id).toList());
    try {
      await ref.read(sourceRepositoryProvider).deleteSource(id);
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] removeSource db delete ok');
    } catch (e, st) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] removeSource error: $e\n$st');
      state = AsyncData(current);
      Error.throwWithStackTrace(e, st);
    }
    ref.invalidate(libraryItemsProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(relatedIndexProvider);
    // ignore: avoid_print
    print('[${AppConfig.I.appName}] removeSource invalidations done');
  }

  Future<void> refreshSource(IptvSource src) async {
    // Skip if a refresh for this source is already running (see _refreshing).
    if (!_refreshing.add(src.id)) return;
    try {
      await ref.read(sourceRepositoryProvider).loadSource(src);
    } catch (e, st) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] refreshSource error: $e\n$st');
      rethrow;
    } finally {
      _refreshing.remove(src.id);
    }
    ref.invalidate(libraryItemsProvider);
    ref.invalidate(relatedIndexProvider);
    ref.invalidate(sourceLastUpdatedProvider(src.id));
    // _cacheItems also clears orphan rows from the side tables; refresh the
    // same providers so the user doesn't see ghost favorites/history.
    ref.invalidate(favoritesProvider);
    ref.invalidate(historyProvider);
  }

  /// Refreshes every configured source in sequence, swallowing per-source
  /// failures so a single broken provider does not stop the others from
  /// updating. Cache writes invalidate the library/related providers, so the
  /// home screen rebuilds with the new channel set as soon as each source
  /// finishes.
  ///
  /// When [staleOnly] is true, only sources whose cache is older than
  /// [_startupStaleThreshold] (or never loaded) are refreshed. The startup
  /// refresh uses this: with a fresh cache, re-downloading the whole catalog
  /// (tens of thousands of channels) and wipe-reinserting on every cold
  /// start made the user stare at a blank screen/spinner for a long time.
  /// If the cache is already populated it's shown instantly, download skipped.
  Future<void> refreshAll({bool staleOnly = false}) async {
    final list = state.value ?? await future;
    if (list.isEmpty) return;
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] refreshAll start count=${list.length} '
      'staleOnly=$staleOnly',
    );
    for (final src in list) {
      try {
        if (staleOnly && !await _isStale(src.id)) {
          // ignore: avoid_print
          print('[${AppConfig.I.appName}] refreshAll skip fresh ${src.name}');
          continue;
        }
        await refreshSource(src);
      } catch (_) {
        // already logged inside refreshSource
      }
    }
    // ignore: avoid_print
    print('[${AppConfig.I.appName}] refreshAll done');
  }

  /// Should a source's cache be refreshed? True if it was never loaded
  /// (null) or the last update is older than [_staleThreshold]. On a
  /// corrupt/unreadable timestamp it stays safe and treats it as stale (refresh).
  Future<bool> _isStale(String sourceId) async {
    try {
      final last =
          await ref.read(sourceRepositoryProvider).lastUpdatedAt(sourceId);
      if (last == null) return true;
      return DateTime.now().difference(last) > _startupStaleThreshold;
    } catch (_) {
      return true;
    }
  }
}

final sourcesProvider =
    AsyncNotifierProvider<SourcesNotifier, List<IptvSource>>(
      SourcesNotifier.new,
    );

/// How often the auto-refresh provider re-pulls every configured source in
/// the background. IPTV catalogues change throughout the day, so we keep a
/// fairly tight 15-minute cadence so the home screen stays close to live
/// without forcing the user to hit the refresh button.
const _autoRefreshInterval = Duration(minutes: 15);

/// During the startup auto-refresh a source is not re-downloaded if its
/// cache is newer than this. Even though IPTV catalogs change during the
/// day, re-downloading tens of thousands of channels and wipe-reinserting
/// on every cold start (a long spinner) is unnecessary; a 6-hour window
/// balances a fast launch against reasonable freshness. The periodic
/// refresh (15 min) keeps running independently of this.
const _startupStaleThreshold = Duration(hours: 6);

/// Side-effecting provider that keeps cached channel lists in sync with the
/// upstream sources. On the first non-empty load of [sourcesProvider] it
/// kicks off a one-shot refresh (so each app launch picks up overnight
/// changes), and then a periodic timer re-runs the same refresh every hour
/// for as long as the provider is alive. Watch it once (e.g. from the root
/// widget) to activate; the provider itself returns nothing.
final sourceAutoRefreshProvider = Provider<void>((ref) {
  var didInitialRefresh = false;

  Future<void> refresh(String reason, {bool staleOnly = false}) async {
    final list = ref.read(sourcesProvider).value ?? const <IptvSource>[];
    if (list.isEmpty) return;
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] auto-refresh ($reason) sources=${list.length}',
    );
    try {
      await ref.read(sourcesProvider.notifier).refreshAll(staleOnly: staleOnly);
    } catch (e, st) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] auto-refresh ($reason) error: $e\n$st');
    }
  }

  ref.listen<AsyncValue<List<IptvSource>>>(sourcesProvider, (_, next) {
    if (didInitialRefresh) return;
    final list = next.value;
    if (list == null || list.isEmpty) return;
    didInitialRefresh = true;
    // Fire-and-forget so we never block the listener callback.
    // staleOnly: don't re-download on launch when the cache is fresh; the
    // populated catalog is shown instantly and a long launch spinner avoided.
    unawaited(refresh('startup', staleOnly: true));
  }, fireImmediately: true);

  final timer = Timer.periodic(_autoRefreshInterval, (_) {
    unawaited(refresh('periodic'));
  });
  ref.onDispose(timer.cancel);
});

class LibraryItemsArgs {
  final MediaKind? kind;
  final String? sourceId;
  const LibraryItemsArgs({this.kind, this.sourceId});

  @override
  bool operator ==(Object other) =>
      other is LibraryItemsArgs &&
      other.kind == kind &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(kind, sourceId);
}

/// The entire cached_details table, as a single shared Map<id, detail>.
/// Previously libraryItemsProvider (3 separate calls for movie/series/live)
/// + related_provider + the recommender all called allDetailsById()
/// independently - 5+ parallel full-table SELECTs on cold start. With this
/// provider it's read once and shared; when the provider is invalidated
/// they all refresh from a single point.
final cachedDetailsMapProvider =
    FutureProvider<Map<String, MediaDetail>>((ref) async {
  // Demo mode: skip real DB scan, return the fake detail map embedded in
  // the demo catalog. Posters/genres/cast/director are all in
  // `library.json`, no real TMDB enrichment needed.
  final demo = ref.watch(demoModeProvider).value;
  if (demo != null && demo.active) {
    return demo.details;
  }
  final repo = ref.watch(sourceRepositoryProvider);
  return repo.allDetailsById();
});

/// content_id → tmdbId map (only content whose tmdbId is resolved).
/// Reading screens like my_ratings use this map to link a rating whose
/// source has been deleted to content with the same tmdbId in the current
/// catalog. It fills as details are written (cached_details); it's loosely
/// tied to libraryItems so it refreshes when that is invalidated.
final contentTmdbIdMapProvider =
    FutureProvider<Map<String, int>>((ref) async {
  ref.watch(libraryItemsProvider(const LibraryItemsArgs()));
  return ref.read(sourceRepositoryProvider).allTmdbIdsByContentId();
});

final libraryItemsProvider =
    FutureProvider.family<List<MediaItem>, LibraryItemsArgs>((ref, args) async {
      // Demo mode: short-circuit. Only fill the movie category, return an
      // empty list for live/series (the demo catalog has no such content).
      final demo = ref.watch(demoModeProvider).value;
      if (demo != null && demo.active) {
        final all = demo.items;
        if (args.kind == null || args.kind == MediaKind.movie) {
          return all;
        }
        return const <MediaItem>[];
      }
      final repo = ref.watch(sourceRepositoryProvider);
      final all = await repo.cachedItems(
        sourceId: args.sourceId,
        kind: args.kind,
      );
      final filter = ref.watch(adultFilterProvider).value;
      final showAdult = filter?.showAdult ?? false;
      // Only the parental filter is enforced here. Hiding rows just because
      // they lack a poster URL turned out to be far too aggressive - many
      // valid streams in big catalogs ship without artwork and the user
      // still wants to be able to find and play them.
      final filtered = showAdult
          ? all
          : all.where((i) => !isAdult(i)).toList();
      // The panel's logoUrl is often low quality and goes stale after a
      // TMDB override. We read cached_details once and layer the TMDB
      // coverUrls onto the items - home, continue row, lists, history,
      // favorites all feed from this provider and get enriched in one
      // place. The shared cachedDetailsMapProvider is used: on home cold
      // start 3 separate libraryItemsProvider calls share the same DB
      // scan.
      final details = await ref.watch(cachedDetailsMapProvider.future);
      if (details.isEmpty) return filtered;
      return filtered.map((item) {
        final d = details[item.id];
        if (d == null) return item;
        final cover = d.coverUrl;
        final backdrop = d.backdropUrl;
        if ((cover == null || cover.isEmpty) &&
            (backdrop == null || backdrop.isEmpty)) {
          return item;
        }
        // The TMDB poster is higher quality than the panel's; prefer TMDB
        // even when the panel has one - otherwise we'd keep showing the old
        // poster after an override.
        return item.copyWith(
          logoUrl: (cover != null && cover.isNotEmpty)
              ? cover
              : item.logoUrl,
          backdropUrl: (backdrop != null && backdrop.isNotEmpty)
              ? backdrop
              : item.backdropUrl,
        );
      }).toList();
    });

final mediaItemByIdProvider = FutureProvider.family<MediaItem?, String>((
  ref,
  id,
) async {
  return ref.watch(sourceRepositoryProvider).cachedItem(id);
});

final sourceByIdProvider = FutureProvider.family<IptvSource?, String>((
  ref,
  id,
) async {
  final list = await ref.watch(sourcesProvider.future);
  for (final s in list) {
    if (s.id == id) return s;
  }
  return null;
});

/// Latest `cached_at` recorded for any channel belonging to [sourceId]. We
/// derive it from the cache rather than tracking a separate column so the
/// timestamp reflects the most recent *successful* refresh - failed pulls
/// don't overwrite anything, so the user keeps seeing the last good time.
/// Returns null if the source has never been loaded.
final sourceLastUpdatedProvider = FutureProvider.family<DateTime?, String>((
  ref,
  sourceId,
) async {
  return ref.watch(sourceRepositoryProvider).lastUpdatedAt(sourceId);
});

/// id → (originalTitle, localizedTitle) dictionary. Carries the
/// alternative titles persisted from TMDB in cached_details. Search also
/// indexes original + localized titles through this dictionary.
final alternateTitlesProvider =
    FutureProvider<
      Map<String, ({String? originalTitle, String? localizedTitle})>
    >((ref) async {
      // We loosely tie to libraryItemsProvider so it triggers whenever
      // library invalidations clear the side tables.
      ref.watch(libraryItemsProvider(const LibraryItemsArgs()));
      return ref.read(sourceRepositoryProvider).allAlternateTitlesById();
    });

/// Analyzes the category names for the given kind and returns a
/// [CategoryDecomposer]. `libraryItemsProvider(kind)` is invalidated after
/// every refresh, so the decomposer refreshes automatically too. The
/// sidebar watches this and gets its category-splitting regex from here.
///
/// When there are multiple sources, all of their category names are
/// combined; the separator must be consistent across the whole catalog.
/// Since most users have a single Xtream panel this isn't a problem in
/// practice; in a mixed case the most common separator wins.
final categoryDecomposerProvider =
    FutureProvider.family<CategoryDecomposer, MediaKind>((ref, kind) async {
  final items = await ref.watch(
    libraryItemsProvider(LibraryItemsArgs(kind: kind)).future,
  );
  final names = <String>{};
  for (final i in items) {
    final n = i.categoryName;
    if (n != null && n.isNotEmpty) names.add(n);
  }
  return CategoryDecomposer.analyze(names);
});
