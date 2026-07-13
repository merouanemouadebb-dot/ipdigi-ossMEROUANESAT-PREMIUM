import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/metadata/tmdb_overrides_provider.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/metadata/tmdb_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../shared/widgets/certification_badge.dart';
import '../../../shared/widgets/fading_hero.dart';
import '../../../shared/widgets/gallery_strip.dart';
import '../../../shared/widgets/reviews_strip.dart';
import '../../../shared/widgets/row_carousel.dart';
import '../../../shared/widgets/trailer_strip.dart';
import '../../library/presentation/add_to_watchlist_sheet.dart';
import '../../library/presentation/rate_content_sheet.dart';
import '../../library/providers/library_provider.dart';
import '../../library/providers/ratings_provider.dart';
import '../../player/presentation/player_page.dart';
import '../../recommendations/related_provider.dart';
import '../../recommendations/tmdb_picker_sheet.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';
import '../providers/movie_detail_provider.dart';

/// Extracts the year from variants like "2023-04-15", "2023-04", "2023".
/// Returns null for invalid / non-4-digit inputs. The parenthesized year
/// label and the "Production year" row share this helper.
int? _yearFromDate(String? raw) {
  if (raw == null || raw.length < 4) return null;
  final y = int.tryParse(raw.substring(0, 4));
  if (y == null || y < 1800 || y > 2100) return null;
  return y;
}

class MovieDetailPage extends ConsumerWidget {
  final String sourceId;
  final String movieId;
  const MovieDetailPage({
    super.key,
    required this.sourceId,
    required this.movieId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = MediaItem.makeId(sourceId, movieId);
    final itemAsync = ref.watch(mediaItemByIdProvider(id));
    final detailAsync = ref.watch(
      movieDetailProvider(
        MovieDetailArgs(sourceId: sourceId, movieId: movieId),
      ),
    );
    final relatedAsync = ref.watch(
      relatedItemsProvider(RelatedQuery(sourceId: sourceId, streamId: movieId)),
    );
    final favs = ref.watch(favoritesProvider).value ?? {};
    final isFav = favs.contains(id);
    final ratings = ref.watch(userRatingsProvider).value ?? const {};
    final userRating = ratings[id];
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final resumeEntry = history.firstWhereOrNull(
      (h) => h.contentId == id && h.sourceId == sourceId,
    );
    final canResume =
        resumeEntry != null &&
        resumeEntry.position.inSeconds > 10 &&
        resumeEntry.progress < 0.95;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (item) {
          if (item == null)
            return Center(child: Text(ref.tr('movies.noContent')));
          final xtreamDetail = detailAsync.value;
          final tmdb = ref
              .watch(tmdbDetailProvider(TmdbLookupArgs.fromItem(item)))
              .value;
          final hasOverride = ref
                  .watch(tmdbOverridesProvider)
                  .value
                  ?.containsKey(item.id) ??
              false;
          final detail = xtreamDetail == null && tmdb == null
              ? null
              : mergeWithTmdb(
                  xtreamDetail ?? const MediaDetail(),
                  tmdb,
                  preferTmdb: hasOverride,
                );
          ref.listen(
            movieDetailProvider(
              MovieDetailArgs(sourceId: sourceId, movieId: movieId),
            ),
            (_, __) {},
          );
          // Wake the side-effect provider so it writes the TMDB titles
          // to cached_details for the search index. The watch call's
          // result isn't used; it's only for triggering.
          ref.watch(
            persistTmdbTitlesProvider(
              MovieDetailArgs(sourceId: sourceId, movieId: movieId),
            ),
          );

          // Adult items: reject any image.tmdb.org URL the panel may
          // have cached as its own cover/backdrop. We don't make a TMDB
          // API call from app code either - but the panel's data often
          // points at TMDB's CDN, so without this filter the image
          // still loads from TMDB's servers. Plot and metadata live in
          // other widgets and are rendered exactly as the source ships.
          final isAdultItem = isAdult(item);
          bool _accept(String? u) {
            if (u == null || u.trim().isEmpty) return false;
            if (isAdultItem && u.toLowerCase().contains('image.tmdb.org')) {
              return false;
            }
            return true;
          }

          final backdrop = [
            detail?.backdropUrl,
            detail?.coverUrl,
            item.backdropUrl,
            item.logoUrl,
          ].firstWhere(_accept, orElse: () => null);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.background,
                expandedHeight: 520,
                collapsedHeight: kToolbarHeight,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    tooltip: ref.tr('tmdbPicker.wrongMatch'),
                    onPressed: () => TmdbPickerSheet.show(
                      context,
                      sourceId: item.sourceId,
                      contentId: item.id,
                      initialQuery: item.name,
                      isMovie: true,
                    ),
                    icon: const Icon(Icons.find_replace_rounded),
                  ),
                ],
                flexibleSpace: FadingFlexibleSpace(
                  expandedHeight: 520,
                  collapsedHeight: kToolbarHeight,
                  child: _Hero(
                    item: item,
                    detail: detail,
                    tmdb: tmdb,
                    backdropUrl: backdrop,
                    isFav: isFav,
                    userRating: userRating,
                    canResume: canResume,
                    resumePosition: resumeEntry?.position ?? Duration.zero,
                    onPlay: () {
                      // pushOnce: if the user taps the button again before
                      // the route has mounted, two player instances would
                      // open and the audio overlapped at the same time.
                      context.pushOnce(
                        '/player',
                        extra: PlayerArgs(
                          item: item,
                          isLive: false,
                          startAt: canResume
                              ? resumeEntry.position
                              : Duration.zero,
                        ),
                      );
                    },
                    onPlayFromStart: !canResume
                        ? null
                        : () {
                            context.pushOnce(
                              '/player',
                              extra: PlayerArgs(
                                item: item,
                                isLive: false,
                                startAt: Duration.zero,
                              ),
                            );
                          },
                    onToggleFav: () => ref
                        .read(favoritesProvider.notifier)
                        .toggle(item.sourceId, item.id),
                    onRate: () => RateContentSheet.show(
                      context,
                      sourceId: item.sourceId,
                      contentId: item.id,
                      contentName: (tmdb?.title?.trim().isNotEmpty ?? false)
                          ? tmdb!.title!
                          : item.name,
                      existing: userRating,
                      tmdbId: tmdb?.tmdbId,
                    ),
                    onAddToList: () => AddToWatchlistSheet.show(
                      context,
                      sourceId: item.sourceId,
                      contentId: item.id,
                      contentName: (tmdb?.title?.trim().isNotEmpty ?? false)
                          ? tmdb!.title!
                          : item.name,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Metadata(
                  item: item,
                  detail: detail,
                  loading: detailAsync.isLoading,
                  trailers: tmdb?.trailers ?? const [],
                  gallery: detail == null
                      ? const []
                      : (isAdultItem
                            ? detail.gallery
                                  .where(
                                    (u) => !u.toLowerCase().contains(
                                      'image.tmdb.org',
                                    ),
                                  )
                                  .toList()
                            : detail.gallery),
                ),
              ),
              if (tmdb != null && tmdb.reviews.isNotEmpty)
                SliverToBoxAdapter(
                  child: ReviewsStrip(reviews: tmdb.reviews),
                ),
              SliverToBoxAdapter(
                child: relatedAsync.when(
                  loading: () => const SizedBox(height: 0),
                  error: (_, __) => const SizedBox(height: 0),
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RowCarousel(
                            title: ref.tr('detail.similarContent'),
                            items: items,
                            onTapItem: (i) {
                              if (i.kind == MediaKind.series) {
                                context.pushOnce(
                                  '/series/${i.sourceId}/${i.streamId}',
                                );
                              } else if (i.kind == MediaKind.movie) {
                                context.pushOnce(
                                  '/movie/${i.sourceId}/${i.streamId}',
                                );
                              }
                            },
                          ),
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  final MediaItem item;
  final MediaDetail? detail;
  final TmdbDetail? tmdb;
  final String? backdropUrl;
  final bool isFav;
  final UserRating? userRating;
  final bool canResume;
  final Duration resumePosition;
  final VoidCallback onPlay;
  final VoidCallback? onPlayFromStart;
  final VoidCallback onToggleFav;
  final VoidCallback onRate;
  final VoidCallback onAddToList;
  const _Hero({
    required this.item,
    required this.detail,
    required this.tmdb,
    required this.backdropUrl,
    required this.isFav,
    required this.userRating,
    required this.canResume,
    required this.resumePosition,
    required this.onPlay,
    required this.onPlayFromStart,
    required this.onToggleFav,
    required this.onRate,
    required this.onAddToList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = detail?.rating ?? item.rating;
    final localized = (tmdb?.title?.trim().isNotEmpty ?? false)
        ? tmdb!.title!
        : item.name;
    final original = tmdb?.originalTitle?.trim();
    final showOriginal =
        original != null &&
        original.isNotEmpty &&
        original.toLowerCase() != localized.toLowerCase();
    // Single source for year: item.year > the start of detail.releaseDate.
    // A slightly faint (year) label is written next to the title.
    final year = item.year ?? _yearFromDate(detail?.releaseDate);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdropUrl != null)
          CachedNetworkImage(
            fadeInDuration: const Duration(milliseconds: 220),
            fadeOutDuration: const Duration(milliseconds: 80),
            imageUrl: backdropUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.surface),
            errorWidget: (_, __, ___) => Container(color: AppColors.surface),
          )
        else
          Container(color: AppColors.surface),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.background,
                Colors.transparent,
                AppColors.background,
              ],
              stops: [0, 0.5, 1],
            ),
          ),
        ),
        Positioned(
          left: 32,
          right: 32,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: localized,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                              height: 1.0,
                            ),
                          ),
                          if (year != null)
                            TextSpan(
                              text: '  ($year)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 26,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (showOriginal) ...[
                      const SizedBox(height: 6),
                      Text(
                        original,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (rating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  if (userRating != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            userRating!.score.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // The year is now shown as a faint (year) label next to
                  // the title; we don't show the same info in two places.
                  if (detail?.runtimeSeconds != null &&
                      detail!.runtimeSeconds! > 0)
                    Text(
                      formatDuration(
                        Duration(seconds: detail!.runtimeSeconds!),
                      ),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  if (detail?.country != null)
                    Text(
                      detail!.country!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  if (detail?.certification != null &&
                      detail!.certification!.isNotEmpty)
                    CertificationBadge(label: detail!.certification!),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded, size: 26),
                    label: Text(
                      canResume
                          ? '${ref.tr('common.resume')} • ${formatDuration(resumePosition)}'
                          : ref.tr('common.play'),
                    ),
                  ),
                  if (onPlayFromStart != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onPlayFromStart,
                      icon: const Icon(Icons.replay_rounded, size: 22),
                      label: Text(ref.tr('common.startOver')),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isFav
                          ? Colors.redAccent
                          : AppColors.surfaceElevated,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      minimumSize: const Size(52, 52),
                      shape: const CircleBorder(),
                    ),
                    onPressed: onToggleFav,
                    child: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 24,
                      color: isFav ? Colors.white : Colors.white,
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: userRating != null
                          ? AppColors.accentDeep
                          : AppColors.surfaceElevated,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: onRate,
                    icon: Icon(
                      userRating != null
                          ? Icons.rate_review_rounded
                          : Icons.star_outline_rounded,
                      size: 22,
                    ),
                    label: Text(
                      userRating != null
                          ? '${ref.tr('detail.yourRating')}: ${userRating!.score.toStringAsFixed(1)}'
                          : ref.tr('detail.rate'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: onAddToList,
                    icon: const Icon(
                      Icons.playlist_add_rounded,
                      size: 22,
                    ),
                    label: Text(
                      ref.tr('detail.addToList'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metadata extends ConsumerWidget {
  final MediaItem item;
  final MediaDetail? detail;
  final bool loading;

  /// Trailers - shown in the title language under Genres, in the same
  /// metadata block.
  final List<TmdbVideo> trailers;

  /// Gallery images - below the trailers, again in the same block.
  final List<String> gallery;
  const _Metadata({
    required this.item,
    required this.detail,
    required this.loading,
    this.trailers = const [],
    this.gallery = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plot = detail?.plot ?? item.plot;
    // Narrow screen (phone): single column, cast right below Genres, full
    // width. Wide screen (tablet/desktop): the existing 2-column (left:
    // plot/genres/trailers/gallery, right: cast/director/...).
    final isWide = MediaQuery.of(context).size.width >= 720;

    // Top info: plot + genres (at the top in both layouts).
    final infoChildren = <Widget>[
      if (plot != null && plot.isNotEmpty)
        Text(
          plot,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            height: 1.55,
          ),
        ),
      if (detail != null && detail!.genres.isNotEmpty) ...[
        const SizedBox(height: 18),
        _TagSection(
          label: ref.tr('detail.genres'),
          values: detail!.genres,
          tagType: 'genre',
          excludeId: item.id,
        ),
      ],
    ];

    // Cast + director + category + year + country (right column on wide
    // screen, below Genres on narrow screen).
    final metaChildren = <Widget>[
      if (loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      if (detail != null && detail!.cast.isNotEmpty)
        _TagSection(
          label: ref.tr('detail.cast'),
          values: detail!.cast,
          tagType: 'cast',
          excludeId: item.id,
        ),
      if (detail != null && detail!.directors.isNotEmpty) ...[
        const SizedBox(height: 14),
        _TagSection(
          label: ref.tr('detail.director'),
          values: detail!.directors,
          tagType: 'dir',
          excludeId: item.id,
        ),
      ],
      if (item.categoryName != null) ...[
        const SizedBox(height: 14),
        _TagSection(
          label: ref.tr('detail.category'),
          values: [item.categoryName!],
          tagType: 'cat',
          excludeId: item.id,
        ),
      ],
      if (detail?.releaseDate != null) ...[
        const SizedBox(height: 14),
        Builder(
          builder: (_) {
            final raw = detail!.releaseDate!;
            final y = _yearFromDate(raw) ?? raw;
            return Text(
              '${ref.tr('detail.releaseYear')}: $y',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            );
          },
        ),
      ],
      if (detail?.country != null) ...[
        const SizedBox(height: 14),
        Text(
          '${ref.tr('detail.country')}: ${detail!.country!}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    ];

    // Media: trailers + gallery (below the left column on wide screen, at
    // the very bottom on narrow screen).
    final mediaChildren = <Widget>[
      if (trailers.isNotEmpty) ...[
        const SizedBox(height: 22),
        TrailerStrip(
          title: ref.tr('detail.trailers'),
          trailers: trailers,
          inline: true,
        ),
      ],
      if (gallery.isNotEmpty) ...[
        const SizedBox(height: 18),
        GalleryStrip(
          title: ref.tr('detail.gallery'),
          images: gallery,
          downloadTitle: item.name,
          inline: true,
        ),
      ],
    ];

    final horizontalPad = isWide ? 32.0 : 20.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 18, horizontalPad, 12),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [...infoChildren, ...mediaChildren],
                  ),
                ),
                const SizedBox(width: 36),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: metaChildren,
                  ),
                ),
              ],
            )
          : Column(
              // Phone: single column, full width. Order: plot, genres,
              // cast/director/..., then trailers/gallery.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...infoChildren,
                if (metaChildren.isNotEmpty) const SizedBox(height: 18),
                ...metaChildren,
                ...mediaChildren,
              ],
            ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String label;
  final List<String> values;
  final String tagType;
  final String excludeId;
  const _TagSection({
    required this.label,
    required this.values,
    required this.tagType,
    required this.excludeId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (v) => _ClickableTag(
                  label: v,
                  tagType: tagType,
                  excludeId: excludeId,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ClickableTag extends ConsumerStatefulWidget {
  final String label;
  final String tagType;
  final String excludeId;
  const _ClickableTag({
    required this.label,
    required this.tagType,
    required this.excludeId,
  });

  @override
  ConsumerState<_ClickableTag> createState() => _ClickableTagState();
}

class _ClickableTagState extends ConsumerState<_ClickableTag> {
  bool _hover = false;
  bool _focus = false;
  bool get _active => _hover || _focus;

  void _activate(String displayLabel) {
    if (widget.tagType == 'cast') {
      context.pushOnce('/person/${Uri.encodeComponent(displayLabel)}');
    } else {
      context.pushOnce(
        '/tag/${widget.tagType}/${Uri.encodeComponent(widget.label)}?exclude=${widget.excludeId}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // For cast chips, if the name is CJK / non-Latin pull a Latin alias
    // from TMDB; other tag types (genre, director, category) are left
    // untouched because they are already localized labels.
    final displayLabel = widget.tagType == 'cast'
        ? (ref.watch(latinizedNameProvider(widget.label)).value ?? widget.label)
        : widget.label;
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
            _activate(displayLabel);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          // Cast tags open the actor profile (TMDB-driven); every other tag
          // type (genre, director, category) still goes to the catalog
          // filter view. If a Latin alias exists, route with it - the
          // person page search also matches better in Latin form.
          onTap: () => _activate(displayLabel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _active ? AppColors.accent : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: (_focus && PlatformInfo.isTv)
                  ? Border.all(color: AppColors.accent, width: 3)
                  : null,
            ),
            child: Text(
              displayLabel,
              style: TextStyle(
                color: _active ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
