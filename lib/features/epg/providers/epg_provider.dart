import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../sources/domain/source.dart';
import '../../sources/providers/sources_provider.dart';
import '../data/xmltv_parser.dart';
import '../domain/epg_program.dart';

/// EPG indices keyed by sourceId, then channelId. Lookups are cheap so
/// the live-tv tile can re-resolve "now playing" on every minute tick
/// without going back to disk.
typedef EpgIndex = Map<String, List<EpgProgram>>;

class EpgSnapshot {
  /// `sourceId → channelId → ordered programs`. Programs inside each
  /// list are sorted ascending by start time so binary search and
  /// "next program" lookups stay simple.
  final Map<String, EpgIndex> bySource;
  final DateTime fetchedAt;
  const EpgSnapshot({required this.bySource, required this.fetchedAt});

  static final empty = EpgSnapshot(
    bySource: const <String, EpgIndex>{},
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Find the program covering [now] for [sourceId]/[channelId], or
  /// null if either the channel has no schedule or there is a gap in
  /// the EPG around the current moment.
  EpgProgram? nowPlaying(String sourceId, String channelId, DateTime now) {
    final list = bySource[sourceId]?[channelId];
    if (list == null || list.isEmpty) return null;
    for (final p in list) {
      if (p.start.isAfter(now)) break;
      if (p.isLiveAt(now)) return p;
    }
    return null;
  }

  EpgProgram? nextProgram(String sourceId, String channelId, DateTime now) {
    final list = bySource[sourceId]?[channelId];
    if (list == null) return null;
    for (final p in list) {
      if (p.start.isAfter(now)) return p;
    }
    return null;
  }

  /// Programmes for one channel whose start time falls in the [from,
  /// to) window. Used by the live info panel to render "today's
  /// schedule" without dragging the whole catalogue into memory.
  List<EpgProgram> rangeFor({
    required String sourceId,
    required String channelId,
    required DateTime from,
    required DateTime to,
  }) {
    final list = bySource[sourceId]?[channelId];
    if (list == null || list.isEmpty) return const [];
    return list
        .where((p) => p.stop.isAfter(from) && p.start.isBefore(to))
        .toList();
  }

  /// Find every programme whose title (or description) contains
  /// [query] (case-insensitive) and whose stop time is still in the
  /// future relative to [now]. Used by global search so the user can
  /// type "Galatasaray" and discover the match without knowing the
  /// channel up front.
  List<EpgSearchHit> search(String query, DateTime now, {int limit = 40}) {
    final needle = query.trim().toLowerCase();
    if (needle.length < 2) return const [];
    final hits = <EpgSearchHit>[];
    for (final entry in bySource.entries) {
      for (final channelEntry in entry.value.entries) {
        for (final p in channelEntry.value) {
          if (!p.stop.isAfter(now)) continue;
          final t = p.title.toLowerCase();
          final d = p.description?.toLowerCase() ?? '';
          if (t.contains(needle) || d.contains(needle)) {
            hits.add(
              EpgSearchHit(
                sourceId: entry.key,
                channelId: channelEntry.key,
                program: p,
              ),
            );
            if (hits.length >= limit * 4) break;
          }
        }
      }
    }
    hits.sort((a, b) => a.program.start.compareTo(b.program.start));
    return hits.take(limit).toList();
  }

  /// All channels whose currently-running programme matches the given
  /// XMLTV category. Powers the "Now: sports / news / movies" smart rows
  /// on the Live TV page.
  Set<String> channelIdsWithCategoryNow({
    required String sourceId,
    required DateTime now,
    required bool Function(String category) match,
  }) {
    final index = bySource[sourceId];
    if (index == null) return const {};
    final out = <String>{};
    for (final entry in index.entries) {
      final list = entry.value;
      for (final p in list) {
        if (p.start.isAfter(now)) break;
        if (!p.isLiveAt(now)) continue;
        for (final c in p.categories) {
          if (match(c)) {
            out.add(entry.key);
            break;
          }
        }
        break;
      }
    }
    return out;
  }
}

class EpgSearchHit {
  final String sourceId;
  final String channelId;
  final EpgProgram program;
  const EpgSearchHit({
    required this.sourceId,
    required this.channelId,
    required this.program,
  });
}

class EpgService {
  final Dio _dio;
  final AppDatabase _db;
  EpgService(this._dio, this._db);

  /// Resolves the XMLTV endpoint for a configured source. Xtream panels
  /// expose `/xmltv.php` next to `/player_api.php`; M3U sources rely on
  /// the user-supplied [M3uSource.epgUrl]. Returns null when the source
  /// has no EPG feed we can call.
  String? endpointFor(IptvSource src) {
    switch (src) {
      case XtreamSource(:final url, :final username, :final password):
        final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
        return '$base/xmltv.php?username=${Uri.encodeQueryComponent(username)}'
            '&password=${Uri.encodeQueryComponent(password)}';
      case M3uSource(:final epgUrl):
        return (epgUrl == null || epgUrl.trim().isEmpty) ? null : epgUrl.trim();
      case DirectUrlSource():
        return null;
    }
  }

  Future<EpgIndex> fetchFor(IptvSource src) async {
    final endpoint = endpointFor(src);
    if (endpoint == null) return const {};
    final res = await _dio.get<String>(
      endpoint,
      options: Options(
        responseType: ResponseType.plain,
        // EPG XMLTV files run from a few hundred kB up to ~30 MB on
        // large panels. Without a bumped timeout we lose the slow
        // ones halfway through the download.
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final body = res.data ?? '';
    if (body.isEmpty) return const {};
    final programs = XmltvParser.parse(body);
    final byChannel = _groupByChannel(programs);
    // Persist so the next cold start serves instantly. Replaces the
    // source's entire EPG block atomically - partial leftovers from a
    // failed half-write would look like phantom programmes in the UI.
    await _replaceForSource(src.id, programs);
    return byChannel;
  }

  /// Boot-time read of every persisted programme grouped by source and
  /// channel id. Used as the initial snapshot so the live tile / info
  /// panel light up immediately on app start while the background
  /// refresh is still in flight.
  Future<Map<String, EpgIndex>> loadCached() async {
    final rows = await _db.select(_db.epgPrograms).get();
    final bySource = <String, EpgIndex>{};
    for (final r in rows) {
      final list = bySource
          .putIfAbsent(r.sourceId, () => <String, List<EpgProgram>>{})
          .putIfAbsent(r.channelId, () => <EpgProgram>[]);
      list.add(
        EpgProgram(
          channelId: r.channelId,
          title: r.title,
          description: r.description,
          start: r.start,
          stop: r.stop,
          categories: (r.categoriesCsv == null || r.categoriesCsv!.isEmpty)
              ? const []
              : r.categoriesCsv!.split('|'),
        ),
      );
    }
    for (final src in bySource.values) {
      for (final list in src.values) {
        list.sort((a, b) => a.start.compareTo(b.start));
      }
    }
    return bySource;
  }

  EpgIndex _groupByChannel(List<EpgProgram> programs) {
    final byChannel = <String, List<EpgProgram>>{};
    for (final p in programs) {
      byChannel.putIfAbsent(p.channelId, () => <EpgProgram>[]).add(p);
    }
    for (final list in byChannel.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return byChannel;
  }

  Future<void> _replaceForSource(
    String sourceId,
    List<EpgProgram> programs,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.epgPrograms,
      )..where((t) => t.sourceId.equals(sourceId))).go();
      await _db.batch((batch) {
        for (final p in programs) {
          batch.insert(
            _db.epgPrograms,
            EpgProgramsCompanion(
              sourceId: Value(sourceId),
              channelId: Value(p.channelId),
              start: Value(p.start),
              stop: Value(p.stop),
              title: Value(p.title),
              description: Value(p.description),
              categoriesCsv: Value(
                p.categories.isEmpty ? null : p.categories.join('|'),
              ),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
    // ignore: avoid_print
    print(
      '[${AppConfig.I.appName}] EPG persisted source=$sourceId '
      'programs=${programs.length}',
    );
  }
}

final epgServiceProvider = Provider<EpgService>((ref) {
  return EpgService(ref.watch(dioProvider), ref.watch(databaseProvider));
});

class EpgNotifier extends AsyncNotifier<EpgSnapshot> {
  @override
  Future<EpgSnapshot> build() async {
    final service = ref.read(epgServiceProvider);
    // Cold start: hydrate from persisted programmes first so the UI
    // has data within milliseconds. The remote XMLTV refresh runs in
    // the background and replaces this snapshot once it lands.
    final cached = await service.loadCached();
    final initial = cached.isEmpty
        ? EpgSnapshot.empty
        : EpgSnapshot(bySource: cached, fetchedAt: DateTime.now());

    // Wait for the source list - without sources there's nothing to
    // refresh against.
    final sources = await ref.watch(sourcesProvider.future);
    if (sources.isEmpty) return initial;
    // Kick the network refresh off without blocking the build so the
    // cached snapshot lands first. Once the refresh finishes it
    // overwrites `state` via `_apply`.
    unawaited(_refreshAndApply(sources));
    return initial;
  }

  Future<EpgSnapshot> _refresh(List<IptvSource> sources) async {
    final service = ref.read(epgServiceProvider);
    final bySource = <String, EpgIndex>{};
    for (final s in sources) {
      try {
        final idx = await service.fetchFor(s);
        if (idx.isNotEmpty) bySource[s.id] = idx;
        // ignore: avoid_print
        print(
          '[${AppConfig.I.appName}] EPG fetched '
          'source=${s.name} channels=${idx.length}',
        );
      } catch (e) {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] EPG fetch failed for ${s.name}: $e');
      }
    }
    // If every source failed (offline / panel down) keep the cached
    // snapshot we already loaded instead of wiping it.
    if (bySource.isEmpty) {
      return state.value ?? EpgSnapshot.empty;
    }
    return EpgSnapshot(bySource: bySource, fetchedAt: DateTime.now());
  }

  Future<void> _refreshAndApply(List<IptvSource> sources) async {
    state = await AsyncValue.guard(() => _refresh(sources));
  }

  /// Force a re-pull. Used by the manual "refresh" button (when we add
  /// one) and by the periodic timer in [epgAutoRefreshProvider]. The
  /// previous snapshot stays visible until the new one is ready so
  /// channel tiles don't blink to "no info" mid-day.
  Future<void> refreshNow() async {
    final sources = ref.read(sourcesProvider).value ?? const <IptvSource>[];
    await _refreshAndApply(sources);
  }
}

final epgProvider = AsyncNotifierProvider<EpgNotifier, EpgSnapshot>(
  EpgNotifier.new,
);

/// Six-hour cadence - EPG data is large (multi-MB XMLTV) and slow-moving;
/// programmes for a given day rarely change once published. Six hours
/// keeps the "now playing" line fresh without hammering the panel.
const _epgRefreshInterval = Duration(hours: 6);

/// Watch this once from the root widget (mirrors [sourceAutoRefreshProvider])
/// to keep the EPG snapshot warm. First pull happens through the
/// AsyncNotifier's `build()`; the timer takes over for the rest of the
/// app's lifetime.
final epgAutoRefreshProvider = Provider<void>((ref) {
  final timer = Timer.periodic(_epgRefreshInterval, (_) {
    unawaited(ref.read(epgProvider.notifier).refreshNow());
  });
  ref.onDispose(timer.cancel);
});
