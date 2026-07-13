import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/i18n.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/library/presentation/continue_watching_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/library/presentation/my_ratings_page.dart';
import '../../features/library/presentation/watch_history_page.dart';
import '../../features/library/presentation/watchlists_page.dart';
import '../../features/library/presentation/watchlist_detail_page.dart';
import '../../features/live_tv/presentation/live_tv_page.dart';
import '../../features/player/presentation/player_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/recommendations/person_detail_page.dart';
import '../../features/recommendations/tag_browse_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/series/presentation/series_detail_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/subtitle_style_page.dart';
import '../../features/sources/presentation/add_source_page.dart';
import '../../features/sources/presentation/sources_list_page.dart';
import '../../features/vod/presentation/movie_detail_page.dart';
import '../../features/vod/presentation/vod_browse_page.dart';
import '../../shared/widgets/app_shell.dart';

/// Fade-through transition used across the main shell pages. Outgoing
/// content fades out while incoming content fades in with a subtle
/// scale-up - closer to a tab switch than a route push, which matches a
/// sidebar-driven app much better than the default slide animation.
CustomTransitionPage<T> _fadeThrough<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.02, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) =>
                _fadeThrough(key: state.pageKey, child: const HomePage()),
          ),
          GoRoute(
            path: '/live',
            name: 'live',
            pageBuilder: (context, state) =>
                _fadeThrough(key: state.pageKey, child: const LiveTvPage()),
          ),
          GoRoute(
            path: '/movies',
            name: 'movies',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: const VodBrowsePage(kind: VodKind.movie),
            ),
          ),
          GoRoute(
            path: '/series',
            name: 'series',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: const VodBrowsePage(kind: VodKind.series),
            ),
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            pageBuilder: (context, state) =>
                _fadeThrough(key: state.pageKey, child: const LibraryPage()),
          ),
          GoRoute(
            path: '/continue',
            name: 'continue',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: const ContinueWatchingPage(),
            ),
          ),
          GoRoute(
            path: '/history',
            name: 'history',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: const WatchHistoryPage(),
            ),
          ),
          GoRoute(
            path: '/ratings',
            name: 'ratings',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: const MyRatingsPage(),
            ),
          ),
          GoRoute(
            path: '/watchlists',
            name: 'watchlists',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: const WatchlistsPage(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                name: 'watchlist-detail',
                pageBuilder: (context, state) => _fadeThrough(
                  key: state.pageKey,
                  child: WatchlistDetailPage(
                    watchlistId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/sources',
            name: 'sources',
            pageBuilder: (context, state) =>
                _fadeThrough(key: state.pageKey, child: const SourcesListPage()),
            routes: [
              GoRoute(
                path: 'add',
                name: 'sources-add',
                pageBuilder: (context, state) => _fadeThrough(
                  key: state.pageKey,
                  child: const AddSourcePage(),
                ),
              ),
              GoRoute(
                path: 'subtitle-style',
                name: 'subtitle-style',
                pageBuilder: (context, state) => _fadeThrough(
                  key: state.pageKey,
                  child: const SubtitleStylePage(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) =>
                _fadeThrough(key: state.pageKey, child: const SearchPage()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                _fadeThrough(key: state.pageKey, child: const SettingsPage()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) =>
                _fadeThrough(key: state.pageKey, child: const ProfilePage()),
          ),
          GoRoute(
            path: '/movie/:sourceId/:id',
            name: 'movie-detail',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: MovieDetailPage(
                sourceId: state.pathParameters['sourceId']!,
                movieId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/series/:sourceId/:id',
            name: 'series-detail',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: SeriesDetailPage(
                sourceId: state.pathParameters['sourceId']!,
                seriesId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/person/:name',
            name: 'person-detail',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              child: PersonDetailPage(
                name: state.pathParameters['name']!,
              ),
            ),
          ),
          GoRoute(
            path: '/tag/:tagType/:tag',
            name: 'tag-browse',
            pageBuilder: (context, state) => _fadeThrough(
              key: state.pageKey,
              // go_router already URL-decodes path parameters, so calling
              // Uri.decodeComponent again would either double-decode a value
              // or throw "Illegal percent encoding" on category names that
              // contain bare `%` glyphs.
              child: TagBrowsePage(
                tagType: state.pathParameters['tagType']!,
                tag: state.pathParameters['tag']!,
                excludeId: state.uri.queryParameters['exclude'],
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        pageBuilder: (context, state) {
          final extra = state.extra as PlayerArgs?;
          final child = extra == null
              ? Scaffold(
                  body: Center(
                    child: Consumer(
                      builder: (_, ref, __) =>
                          Text(ref.tr('player.noStream')),
                    ),
                  ),
                )
              : PlayerPage(args: extra);
          // Player gets a cinematic fade through black so the transition feels
          // like a curtain rising, not a route push.
          return CustomTransitionPage(
            key: state.pageKey,
            child: child,
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: (ctx, animation, secondaryAnimation, c) {
              final curved =
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
                  child: c,
                ),
              );
            },
          );
        },
      ),
    ],
  );
});
