
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../player/presentation/player_page.dart';
import '../../sources/domain/category_grouping.dart';
import '../../sources/domain/media_item.dart';
import 'vod_browse_page.dart' show VodKind;

class HeroTheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final IconData glyph;

  const HeroTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.glyph,
  });

  static const HeroTheme neutral = HeroTheme(
    primary: Color(0xFF2A2A33),
    secondary: Color(0xFF3A3A47),
    accent: Color(0xFFB3B3B3),
    glyph: Icons.movie_rounded,
  );
}

class HeroThemeResolver {
  static const _tokenMap = <_TokenRule>[
    _TokenRule(['korku', 'horror'], _kHorror),
    _TokenRule(['gerilim', 'thriller', 'suspense'], _kThriller),
    _TokenRule(['bilim kurgu', 'sci-fi', 'scifi', 'science fiction'], _kScifi),
    _TokenRule(['fantastik', 'fantasy', 'fantezi'], _kFantasy),
    _TokenRule(['aksiyon', 'action'], _kAction),
    _TokenRule(['macera', 'adventure'], _kAdventure),
    _TokenRule(['savaş', 'savas', 'war', 'tarih', 'history'], _kWar),
    _TokenRule(['romantik', 'romance', 'aşk', 'ask', 'love'], _kRomance),
    _TokenRule(['komedi', 'comedy'], _kComedy),
    _TokenRule(['drama'], _kDrama),
    _TokenRule(['gizem', 'mystery', 'polisiye', 'crime', 'suç', 'suc'], _kMystery),
    _TokenRule(['belgesel', 'documentary', 'doku'], _kDoc),
    _TokenRule(['çizgi', 'cizgi', 'çocuk', 'cocuk', 'kids', 'cartoon'], _kKids),
    _TokenRule(['animasyon', 'animation', 'anime'], _kAnim),
    _TokenRule(['müzikal', 'muzikal', 'musical'], _kMusical),
    _TokenRule(['müzik', 'muzik', 'music'], _kMusic),
    _TokenRule(['spor', 'sport'], _kSport),
    _TokenRule(['aile', 'family'], _kFamily),
    _TokenRule(['western', 'kovboy'], _kWestern),
    _TokenRule(['biyografi', 'biography', 'biopic'], _kBio),
  ];

  static HeroTheme resolve(String? categoryName) {
    if (categoryName == null || categoryName.trim().isEmpty) {
      return HeroTheme.neutral;
    }

    final parsed = CategoryGrouping.parse(categoryName);
    final lower = parsed.subCategory.toLowerCase();

    for (final rule in _tokenMap) {
      for (final t in rule.tokens) {
        if (lower.contains(t)) return rule.theme;
      }
    }

    final country = parsed.country?.toUpperCase();
    final byCountry = _countryFallback[country];

    if (byCountry != null) return byCountry;

    final hue = (categoryName.hashCode.abs() % 360).toDouble();

    return HeroTheme(
      primary: HSLColor.fromAHSL(1.0, hue, 0.45, 0.32).toColor(),
      secondary: HSLColor.fromAHSL(1.0, hue, 0.30, 0.42).toColor(),
      accent: HSLColor.fromAHSL(1.0, hue, 0.55, 0.55).toColor(),
      glyph: Icons.local_movies_rounded,
    );
  }

  static const _kHorror = HeroTheme(
    primary: Color(0xFF3A1F2E),
    secondary: Color(0xFF1E1018),
    accent: Color(0xFF8B2D4C),
    glyph: Icons.nights_stay_rounded,
  );

  static const _kThriller = HeroTheme(
    primary: Color(0xFF2F1F3A),
    secondary: Color(0xFF181020),
    accent: Color(0xFF7B4DA8),
    glyph: Icons.visibility_off_rounded,
  );

  static const _kScifi = HeroTheme(
    primary: Color(0xFF1F2D4A),
    secondary: Color(0xFF101830),
    accent: Color(0xFF4DA8C7),
    glyph: Icons.rocket_launch_rounded,
  );

  static const _kFantasy = HeroTheme(
    primary: Color(0xFF2D1F4A),
    secondary: Color(0xFF181028),
    accent: Color(0xFF9C6FE0),
    glyph: Icons.auto_awesome_rounded,
  );

  static const _kAction = HeroTheme(
    primary: Color(0xFF4A201F),
    secondary: Color(0xFF281010),
    accent: Color(0xFFE07A4D),
    glyph: Icons.local_fire_department_rounded,
  );

  static const _kAdventure = HeroTheme(
    primary: Color(0xFF1F4A3A),
    secondary: Color(0xFF10281F),
    accent: Color(0xFF52C99B),
    glyph: Icons.explore_rounded,
  );

  static const _kWar = HeroTheme(
    primary: Color(0xFF3D3A1F),
    secondary: Color(0xFF1E1C10),
    accent: Color(0xFFB89E50),
    glyph: Icons.military_tech_rounded,
  );

  static const _kRomance = HeroTheme(
    primary: Color(0xFF4A1F38),
    secondary: Color(0xFF26101C),
    accent: Color(0xFFE85A98),
    glyph: Icons.favorite_rounded,
  );

  static const _kComedy = HeroTheme(
    primary: Color(0xFF4A3F1F),
    secondary: Color(0xFF26201C),
    accent: Color(0xFFE0C04A),
    glyph: Icons.emoji_emotions_rounded,
  );

  static const _kDrama = HeroTheme(
    primary: Color(0xFF1F2A4A),
    secondary: Color(0xFF101428),
    accent: Color(0xFF6A8FCC),
    glyph: Icons.theater_comedy_rounded,
  );

  static const _kMystery = HeroTheme(
    primary: Color(0xFF1F2A3D),
    secondary: Color(0xFF10141F),
    accent: Color(0xFF7596C7),
    glyph: Icons.search_rounded,
  );

  static const _kDoc = HeroTheme(
    primary: Color(0xFF3D331F),
    secondary: Color(0xFF1E1810),
    accent: Color(0xFFB8924D),
    glyph: Icons.public_rounded,
  );

  static const _kKids = HeroTheme(
    primary: Color(0xFF1F4A4A),
    secondary: Color(0xFF102626),
    accent: Color(0xFF52D6D6),
    glyph: Icons.toys_rounded,
  );

  static const _kAnim = HeroTheme(
    primary: Color(0xFF4A2F3A),
    secondary: Color(0xFF26181E),
    accent: Color(0xFFE07591),
    glyph: Icons.brush_rounded,
  );

  static const _kMusical = HeroTheme(
    primary: Color(0xFF3F1F4A),
    secondary: Color(0xFF1E1026),
    accent: Color(0xFFC76FD6),
    glyph: Icons.music_note_rounded,
  );

  static const _kMusic = HeroTheme(
    primary: Color(0xFF2F1F4A),
    secondary: Color(0xFF181028),
    accent: Color(0xFF9C6FE0),
    glyph: Icons.library_music_rounded,
  );

  static const _kSport = HeroTheme(
    primary: Color(0xFF1F3F4A),
    secondary: Color(0xFF102026),
    accent: Color(0xFF52B8D6),
    glyph: Icons.sports_soccer_rounded,
  );

  static const _kFamily = HeroTheme(
    primary: Color(0xFF4A3320),
    secondary: Color(0xFF261A10),
    accent: Color(0xFFD6A55C),
    glyph: Icons.family_restroom_rounded,
  );

  static const _kWestern = HeroTheme(
    primary: Color(0xFF4A2F1F),
    secondary: Color(0xFF261810),
    accent: Color(0xFFC78B4D),
    glyph: Icons.terrain_rounded,
  );

  static const _kBio = HeroTheme(
    primary: Color(0xFF2A3D4A),
    secondary: Color(0xFF141E26),
    accent: Color(0xFF7DA8C7),
    glyph: Icons.person_outline_rounded,
  );

  static const _countryFallback = <String, HeroTheme>{
    'TR': HeroTheme(
      primary: Color(0xFF4A1F1F),
      secondary: Color(0xFF261010),
      accent: Color(0xFFD64A52),
      glyph: Icons.movie_rounded,
    ),
    'US': _kAction,
    'GB': _kDrama,
    'FR': _kRomance,
    'IT': _kRomance,
    'DE': _kThriller,
    'JP': _kAnim,
    'KR': _kRomance,
    'IN': _kMusical,
    'RU': _kDrama,
    'ES': _kRomance,
  };
}

class _TokenRule {
  final List<String> tokens;
  final HeroTheme theme;

  const _TokenRule(this.tokens, this.theme);
}

class FeaturedPicker {
  static bool _ratingOk(double? r) {
    if (r == null) return true;
    return r > 0.0 && r < 10.0;
  }

  static List<MediaItem> pick(
    List<MediaItem> categoryItems,
    String seedKey,
  ) {
    if (categoryItems.isEmpty) return const [];

    final pool = <MediaItem>[];

    for (final i in categoryItems) {
      if (i.rating != null &&
          _ratingOk(i.rating) &&
          i.rating! >= 7 &&
          i.year != null) {
        pool.add(i);
      }
    }

    if (pool.length < 5) {
      pool.clear();

      for (final i in categoryItems) {
        if (i.rating != null &&
            _ratingOk(i.rating) &&
            i.rating! >= 6 &&
            i.year != null) {
          pool.add(i);
        }
      }
    }

    if (pool.length < 5) {
      pool.clear();

      for (final i in categoryItems) {
        if (!_ratingOk(i.rating)) continue;

        if (i.logoUrl != null || i.backdropUrl != null) {
          pool.add(i);
        }
      }
    }

    if (pool.isEmpty) return const [];

    int score(MediaItem i) {
      var s = ((i.rating ?? 0) * 10).round();

      if (i.year != null) {
        s += (i.year! - 2000).clamp(0, 25);
      }

      if (i.backdropUrl != null) s += 8;

      if (i.plot != null && i.plot!.trim().isNotEmpty) {
        s += 35;
      }

      if (i.addedAt != null &&
          DateTime.now().difference(i.addedAt!).inDays < 30) {
        s += 5;
      }

      return s;
    }

    pool.sort((a, b) => score(b).compareTo(score(a)));

    final top = pool.take(15).toList();

    if (top.length <= 5) return top;

    final seed =
        seedKey.hashCode ^ _weekOfYear(DateTime.now());

    final rng = math.Random(seed);

    top.shuffle(rng);

    return top.take(5).toList();
  }

  static int _weekOfYear(DateTime t) {
    final thursday = t.add(
      Duration(days: 4 - t.weekday),
    );

    final firstThursday = DateTime(
      thursday.year, 1, 4,
    );

    final week =
        (thursday.difference(firstThursday).inDays / 7)
                .floor() +
            1;

    return week + thursday.year * 100;
  }
}

class MovieCategoryHero extends StatefulWidget {
  final String seedKey;
  final String? categoryName;
  final String title;
  final List<MediaItem> categoryItems;
  final VodKind kind;

  const MovieCategoryHero({
    super.key,
    required this.seedKey,
    required this.categoryName,
    required this.title,
    required this.categoryItems,
    this.kind = VodKind.movie,
  });

  @override
  State<MovieCategoryHero> createState() =>
      _MovieCategoryHeroState();
}

class _MovieCategoryHeroState
    extends State<MovieCategoryHero> {
  late List<MediaItem> _picks;
  late PageController _pageCtrl;

  int _index = 0;

  @override
  void initState() {
    super.initState();

    _picks = FeaturedPicker.pick(
      widget.categoryItems,
      widget.seedKey,
    );

    _pageCtrl = PageController(
      viewportFraction: 1.0,
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(
    covariant MovieCategoryHero old,
  ) {
    super.didUpdateWidget(old);

    if (old.seedKey != widget.seedKey ||
        !identical(
          old.categoryItems,
          widget.categoryItems,
        )) {
      _picks = FeaturedPicker.pick(
        widget.categoryItems,
        widget.seedKey,
      );

      _index = 0;

      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(0);
      }
    }
  }

  void _shift(int dir) {
    if (_picks.length < 2 || !_pageCtrl.hasClients) {
      return;
    }

    final next = (_index + dir) % _picks.length;

    final target =
        next < 0 ? next + _picks.length : next;

    _pageCtrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = HeroThemeResolver.resolve(
      widget.categoryName,
    );

    if (_picks.isEmpty) {
      return const SizedBox.shrink();
    }

    final w = MediaQuery.sizeOf(context).width;

    final textScale =
        MediaQuery.textScalerOf(context).scale(14) / 14;

    final extraHeight = w < 768
        ? ((textScale - 1) * 100)
            .clamp(0.0, 140.0)
            .toDouble()
        : 0.0;

    final height = w >= 1200
        ? 420.0
        : (w >= 768 ? 360.0 : 300.0 + extraHeight);

    final showPoster = w >= 760;

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      tween: ColorTween(end: theme.primary),
      builder: (context, primary, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            24, 18, 24, 0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: primary ?? theme.primary,
                  ),
                  Positioned(
                    right: -24,
                    top: -16,
                    child: Opacity(
                      opacity: 0.07,
                      child: Transform.rotate(
                        angle: -0.18,
                        child: Icon(
                          theme.glyph,
                          size: 280,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) =>
                        setState(() => _index = i),
                    itemCount: _picks.length,
                    itemBuilder: (_, i) =>
                        _BackgroundLayer(
                      item: _picks[i],
                      tint: (primary ?? theme.primary)
                          .withValues(alpha: 0.42),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xEE000000),
                            Color(0xB3000000),
                            Color(0x4D000000),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      w >= 1200 ? 36 : 24,
                      20,
                      w >= 1200 ? 36 : 24,
                      _picks.length > 1 ? 42 : 20,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _HeroText(
                            item: _picks[_index],
                            theme: theme,
                            category: widget.title,
                            kind: widget.kind,
                          ),
                        ),
                        if (showPoster) ...[
                          const SizedBox(width: 24),
                          _HeroPoster(
                            item: _picks[_index],
                            theme: theme,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_picks.length > 1)
                    Positioned(
                      left: w >= 1200 ? 36 : 24,
                      bottom: 16,
                      child: _PeekDots(
                        count: _picks.length,
                        index: _index,
                        accent: theme.accent,
                        onPrev: () => _shift(-1),
                        onNext: () => _shift(1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BackgroundLayer extends ConsumerWidget {
  final MediaItem item;
  final Color tint;

  const _BackgroundLayer({
    required this.item,
    required this.tint,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final tmdbAsync = ref.watch(
      tmdbDetailProvider(
        TmdbLookupArgs.fromItem(item),
      ),
    );

    final tmdbBackdrop = tmdbAsync.value?.backdropUrl;

    final String? backdrop =
        (tmdbBackdrop != null &&
                tmdbBackdrop.isNotEmpty)
            ? tmdbBackdrop
            : (item.backdropUrl != null &&
                    item.backdropUrl!.isNotEmpty)
                ? item.backdropUrl
                : null;

    final hasBackdrop = backdrop != null;

    final fallbackPoster =
        tmdbAsync.value?.posterUrl ?? item.logoUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasBackdrop)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 0.8, sigmaY: 0.8,
            ),
            child: CachedNetworkImage(
              imageUrl: backdrop,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  const SizedBox.shrink(),
              errorWidget: (_, _, _) =>
                  const SizedBox.shrink(),
            ),
          )
        else if (fallbackPoster != null &&
            fallbackPoster.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 2.0, sigmaY: 2.0,
            ),
            child: Transform.scale(
              scale: 1.06,
              child: CachedNetworkImage(
                imageUrl: fallbackPoster,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                placeholder: (_, _) =>
                    const SizedBox.shrink(),
                errorWidget: (_, _, _) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroText extends ConsumerWidget {
  final MediaItem item;
  final HeroTheme theme;
  final String category;
  final VodKind kind;

  const _HeroText({
    required this.item,
    required this.theme,
    required this.category,
    required this.kind,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final tmdb = ref
        .watch(
          tmdbDetailProvider(
            TmdbLookupArgs.fromItem(item),
          ),
        )
        .value;

    final ratingLabel = item.rating == null
        ? null
        : '★ ${item.rating!.toStringAsFixed(1)}';

    final year = item.year?.toString();

    final meta = <String>[
      if (ratingLabel != null) ratingLabel,
      if (year != null) year,
    ].join('  ·  ');

    final cleanName = item.name
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final rawPlot =
        (item.plot?.trim().isNotEmpty ?? false)
            ? item.plot!
            : (tmdb?.overview ?? '');

    final cleanPlot = rawPlot
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 768;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      mainAxisAlignment:
          MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: theme.accent.withValues(
              alpha: 0.22,
            ),
            borderRadius:
                BorderRadius.circular(4),
            border: Border.all(
              color: theme.accent.withValues(
                alpha: 0.45,
              ),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                theme.glyph,
                size: 12,
                color: theme.accent,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  category.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: Text(
            cleanName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: compact
                  ? 20
                  : (width >= 1200 ? 32 : 26),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.05,
            ),
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            meta,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            cleanPlot.isNotEmpty
                ? cleanPlot
                : ref.tr('vod.noPlotFallback'),
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cleanPlot.isNotEmpty
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
              fontSize: 13,
              height: 1.4,
              fontStyle: cleanPlot.isNotEmpty
                  ? FontStyle.normal
                  : FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ElevatedButton.icon(
              onPressed: () => _primary(context),
              icon: const Icon(
                Icons.play_arrow_rounded,
                size: 22,
              ),
              label: Text(
                kind == VodKind.series
                    ? ref.tr('common.watch')
                    : ref.tr('common.play'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 22,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _detail(context),
              icon: const Icon(
                Icons.info_outline_rounded,
                size: 18,
              ),
              label: Text(
                ref.tr('common.details'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    AppColors.textPrimary,
                side: BorderSide(
                  color: theme.accent,
                  width: 1.2,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 18,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _primary(BuildContext context) {
    if (kind == VodKind.series) {
      GoRouter.of(context).pushOnce(
        '/series/${item.sourceId}/${item.streamId}',
      );

      return;
    }

    GoRouter.of(context).pushOnce(
      '/player',
      extra: PlayerArgs(
        item: item,
        isLive: false,
        startAt: Duration.zero,
      ),
    );
  }

  void _detail(BuildContext context) {
    final route =
        kind == VodKind.series ? 'series' : 'movie';

    GoRouter.of(context).pushOnce(
      '/$route/${item.sourceId}/${item.streamId}',
    );
  }
}

class _HeroPoster extends StatelessWidget {
  final MediaItem item;
  final HeroTheme theme;

  const _HeroPoster({
    required this.item,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    final posterWidth = w >= 1200 ? 180.0 : 150.0;
    final posterHeight = posterWidth * 1.5;

    final hasImage =
        item.logoUrl != null ||
        item.backdropUrl != null;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(-0.14),
      child: Container(
        width: posterWidth,
        height: posterHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.55,
              ),
              blurRadius: 28,
              offset: const Offset(-8, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl:
                    (item.logoUrl ?? item.backdropUrl)!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: theme.secondary,
                ),
                errorWidget: (_, _, _) =>
                    _PosterFallback(
                  theme: theme,
                  name: item.name,
                ),
              )
            : _PosterFallback(
                theme: theme,
                name: item.name,
              ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final HeroTheme theme;
  final String name;

  const _PosterFallback({
    required this.theme,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim()[0].toUpperCase();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primary,
            theme.secondary,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 88,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PeekDots extends StatelessWidget {
  final int count;
  final int index;
  final Color accent;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PeekDots({
    required this.count,
    required this.index,
    required this.accent,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          onTap: onPrev,
        ),
        const SizedBox(width: 10),
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(
              milliseconds: 200,
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: 3,
            ),
            width: i == index ? 22 : 7,
            height: 4,
            decoration: BoxDecoration(
              color: i == index
                  ? accent
                  : Colors.white.withValues(
                      alpha: 0.3,
                    ),
              borderRadius:
                  BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 10),
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ArrowButton> createState() =>
      _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) =>
          setState(() => _hover = true),
      onExit: (_) =>
          setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover
                ? Colors.white.withValues(
                    alpha: 0.2,
                  )
                : Colors.white.withValues(
                    alpha: 0.1,
                  ),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
