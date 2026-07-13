import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/providers/library_provider.dart';
import '../../features/sources/domain/media_item.dart';
import '../prefs/user_preferences.dart';
import '../config/app_config.dart';

/// Demo mode (App Store screenshots). When activated:
///   - `assets/demo/library.json` is loaded and 24 fake movies are
///     converted into MediaItems.
///   - A small HTTP server (`http://127.0.0.1:PORT/`) is started on
///     localhost; it serves the bundled posters in a URL scheme that
///     CachedNetworkImage understands. This way every existing poster
///     widget (CachedNetworkImage) works without any change.
///   - `libraryItemsProvider` + `cachedDetailsMapProvider` short-circuit
///     to return this fake catalog instead of real Xtream/M3U data.
///
/// State is persisted through `UserPreferences` under the `demo_mode_active` key.
/// Hidden toggle: tap the version label at the bottom of the side rail 7 times.
class DemoModeState {
  final bool active;
  final int serverPort;
  final List<MediaItem> items;
  final Map<String, MediaDetail> details;
  final List<HistoryEntry> history;
  final Set<String> favorites;
  const DemoModeState({
    required this.active,
    required this.serverPort,
    required this.items,
    required this.details,
    required this.history,
    required this.favorites,
  });

  static const empty = DemoModeState(
    active: false,
    serverPort: 0,
    items: [],
    details: {},
    history: [],
    favorites: {},
  );
}

class DemoModeNotifier extends AsyncNotifier<DemoModeState> {
  HttpServer? _server;
  static const _prefKey = 'demo_mode_active';

  /// Demo turns on automatically when built with `--dart-define=DEMO=1`.
  /// The screenshot pipeline sets this flag, so demo starts active even on
  /// a fresh simulator without the user doing the 7-tap.
  static const _autoEnable = bool.fromEnvironment('DEMO');

  @override
  Future<DemoModeState> build() async {
    // ignore: avoid_print
    print('[demo] build: kDebugMode=$kDebugMode autoEnable=$_autoEnable');
    // Demo mode is completely off in release builds: assets are not in the
    // bundle (not registered in pubspec), the UI hotspot is hidden, and any
    // persisted state is not loaded either. Active only in debug builds.
    if (!kDebugMode) return DemoModeState.empty;
    if (_autoEnable) {
      // ignore: avoid_print
      print('[demo] auto-enable via DEMO=true dart-define');
      return _activate();
    }
    final prefs = UserPreferences();
    final stored = await prefs.getString(_prefKey);
    final shouldBeActive = stored == '1';
    // ignore: avoid_print
    print('[demo] persisted state: $stored -> active=$shouldBeActive');
    if (!shouldBeActive) return DemoModeState.empty;
    return _activate();
  }

  Future<void> toggle() async {
    if (!kDebugMode) return; // no-op in release
    final current = state.value ?? DemoModeState.empty;
    if (current.active) {
      await _deactivate();
    } else {
      state = const AsyncValue.loading();
      try {
        final next = await _activate();
        state = AsyncValue.data(next);
        await UserPreferences().setString(_prefKey, '1');
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> _deactivate() async {
    await _server?.close(force: true);
    _server = null;
    state = const AsyncValue.data(DemoModeState.empty);
    await UserPreferences().setString(_prefKey, '0');
  }

  Future<DemoModeState> _activate() async {
    // Library JSON
    final raw = await rootBundle.loadString('assets/demo/library.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final rawItems = (json['items'] as List).cast<Map<String, dynamic>>();

    // Start the localhost server (random port) so CachedNetworkImage can
    // read the poster assets over HTTP.
    final port = await _startServer(rawItems);

    final items = <MediaItem>[];
    final details = <String, MediaDetail>{};
    for (final m in rawItems) {
      final id = m['id'] as String;
      final composite = MediaItem.makeId('demo', id);
      final posterPath = m['posterPath'] as String;
      final logoUrl = 'http://127.0.0.1:$port/posters/$posterPath';
      final genres = (m['genres'] as List?)?.cast<String>() ?? const [];
      final cast = (m['cast'] as List?)?.cast<String>() ?? const [];

      items.add(MediaItem(
        id: composite,
        sourceId: 'demo',
        streamId: id,
        name: m['title'] as String,
        // streamUrl empty, no playback in demo mode (a fake url could be
        // put here; if player_page opens it just shows an error).
        streamUrl: '',
        kind: MediaKind.movie,
        logoUrl: logoUrl,
        backdropUrl: logoUrl,
        categoryId: genres.isNotEmpty ? genres.first : null,
        categoryName: genres.isNotEmpty ? genres.first : null,
        plot: (m['logline'] as String?) ?? (m['synopsis'] as String?),
        year: (m['year'] as num?)?.toInt(),
        rating: (m['rating'] as num?)?.toDouble(),
      ));

      details[composite] = MediaDetail(
        cast: cast,
        directors: [if (m['director'] != null) m['director'] as String],
        genres: genres,
        runtimeSeconds: ((m['runtime'] as num?)?.toInt() ?? 0) * 60,
        country: m['country'] as String?,
        rating: (m['rating'] as num?)?.toDouble(),
        plot: (m['synopsis'] as String?) ?? (m['logline'] as String?),
        coverUrl: logoUrl,
        backdropUrl: logoUrl,
        originalTitle: m['title'] as String?,
        localizedTitle: m['title'] as String?,
      );
    }

    // Fake history: fill the "Continue Watching" + "Watch History" rows.
    // A realistic mix with varied progress percentages.
    final now = DateTime.now();
    final history = <HistoryEntry>[];
    final historyPicks = <(int, int, int)>[
      // (item-index, progress%, daysAgo)
      (5, 35, 1), // Ascendant
      (6, 72, 2), // Cold Harbor
      (8, 88, 3), // Lakeside Cabin
      (9, 22, 4), // Lighthouse Keeper
      (13, 55, 5), // Inside Job
      (14, 67, 7), // Sentinel Nine
      (3, 95, 9), // Set the Date
      (2, 41, 11), // The Vacancy
    ];
    for (final pick in historyPicks) {
      if (pick.$1 >= items.length) continue;
      final m = items[pick.$1];
      final runtimeSec = (details[m.id]?.runtimeSeconds ?? 6300);
      final duration = Duration(seconds: runtimeSec);
      final position = Duration(
          seconds: (runtimeSec * pick.$2 ~/ 100).clamp(60, runtimeSec - 60));
      history.add(HistoryEntry(
        contentId: m.id,
        sourceId: m.sourceId,
        position: position,
        duration: duration,
        lastWatchedAt: now.subtract(Duration(days: pick.$3)),
        actualWatch: position,
        categoryName: m.categoryName,
      ));
    }

    // Fake favorites: pick 6 movies from different genres
    final favorites = <String>{
      for (final idx in const [0, 4, 7, 11, 15, 17])
        if (idx < items.length) items[idx].id,
    };

    return DemoModeState(
      active: true,
      serverPort: port,
      items: items,
      details: details,
      history: history,
      favorites: favorites,
    );
  }

  Future<int> _startServer(List<Map<String, dynamic>> items) async {
    await _server?.close(force: true);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    // ignore: avoid_print
    print(
        '[${AppConfig.I.appName}] demo HTTP server listening on 127.0.0.1:${server.port}');
    // Prepare the lookup table up front so we don't scan the file system
    // on every HTTP request.
    final allowed = <String>{
      for (final m in items) '/posters/${m['posterPath']}',
    };

    server.listen((HttpRequest req) async {
      try {
        final path = req.uri.path;
        if (!allowed.contains(path)) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }
        // Read from the assets/demo/posters/<file> bundled asset.
        final assetKey = 'assets/demo${path}';
        final data = await rootBundle.load(assetKey);
        req.response.headers
          ..contentType = ContentType('image', 'jpeg')
          ..add('Cache-Control', 'public, max-age=31536000');
        req.response.add(data.buffer.asUint8List());
        await req.response.close();
      } catch (e) {
        // ignore: avoid_print
        print('[${AppConfig.I.appName}] demo server error: $e');
        try {
          req.response.statusCode = HttpStatus.internalServerError;
          await req.response.close();
        } catch (_) {}
      }
    });
    return server.port;
  }
}

final demoModeProvider =
    AsyncNotifierProvider<DemoModeNotifier, DemoModeState>(
        DemoModeNotifier.new);

/// Is demo mode currently active? (sync, simple boolean - can be read
/// comfortably in widgets via `ref.watch(isDemoActiveProvider)`).
final isDemoActiveProvider = Provider<bool>((ref) {
  return ref.watch(demoModeProvider).value?.active ?? false;
});
