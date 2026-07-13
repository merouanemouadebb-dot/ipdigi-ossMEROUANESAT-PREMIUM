import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/i18n.dart';
import '../../core/metadata/tmdb_provider.dart';
import '../../core/metadata/tmdb_service.dart' show TmdbDetail;
import '../../core/theme/app_theme.dart';
import '../../features/sources/domain/media_item.dart';

/// The large featured band at the top of the home page. Backdrop + plot
/// are pulled via TMDB enrichment, with a perspective version of the
/// poster on the right and category + title + meta + CTAs on the left.
class HeroBanner extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback? onInfo;
  const HeroBanner({
    super.key,
    required this.item,
    required this.onPlay,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmdb = ref
        .watch(tmdbDetailProvider(TmdbLookupArgs.fromItem(item)))
        .value;
    final w = MediaQuery.sizeOf(context).width;
    final height = w >= 1200 ? 460.0 : (w >= 768 ? 420.0 : 380.0);
    final showPoster = w >= 760;

    final backdrop = (tmdb?.backdropUrl?.isNotEmpty ?? false)
        ? tmdb!.backdropUrl
        : (item.backdropUrl?.isNotEmpty ?? false)
        ? item.backdropUrl
        : null;
    final fallback = tmdb?.posterUrl ?? item.logoUrl;
    final hasBackdrop = backdrop != null;

    final cleanTitle = item.displayName.replaceAll(RegExp(r'\s+'), ' ').trim();
    final rawPlot = (item.plot?.trim().isNotEmpty ?? false)
        ? item.plot!
        : (tmdb?.overview ?? '');
    final cleanPlot = rawPlot.replaceAll(RegExp(r'\s+'), ' ').trim();
    final year = item.year?.toString();
    final ratingLabel =
        (item.rating != null && item.rating! > 0 && item.rating! < 10)
        ? '★ ${item.rating!.toStringAsFixed(1)}'
        : null;
    final meta = <String>[
      if (ratingLabel != null) ratingLabel,
      if (year != null) year,
    ].join('  ·  ');

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // If there's a backdrop, cover it with a light blur; otherwise
          // an ambient blur version of the poster as the background.
          if (hasBackdrop)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: CachedNetworkImage(
                imageUrl: backdrop,
                fit: BoxFit.cover,
                // The background is blurred (sigma 6) and shown full-width;
                // on TV even scaling a 1280px decode to 1920 is hidden by the
                // blur. Without cacheWidth the TMDB original (often >2000px)
                // got decoded and caused jank/GC on weak TV GPU/memory.
                memCacheWidth: 1280,
                maxWidthDiskCache: 1280,
                placeholder: (_, _) => Container(color: AppColors.surface),
                errorWidget: (_, _, _) => Container(color: AppColors.surface),
              ),
            )
          else if (fallback != null && fallback.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Transform.scale(
                scale: 1.1,
                child: CachedNetworkImage(
                  imageUrl: fallback,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  // Background under a heavy blur (sigma 24); a low-res
                  // decode is enough, the detail is lost anyway.
                  memCacheWidth: 640,
                  maxWidthDiskCache: 640,
                  placeholder: (_, _) => Container(color: AppColors.surface),
                  errorWidget: (_, _, _) => Container(color: AppColors.surface),
                ),
              ),
            )
          else
            Container(color: AppColors.surface),
          // Black gradient - high contrast for the left-side text.
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF2000000),
                  Color(0xB3000000),
                  Color(0x4D000000),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Bottom softening - eases the transition into the rest of the page.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.background,
                  AppColors.background.withValues(alpha: 0.0),
                ],
                stops: const [0, 0.35],
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              w >= 1200 ? 40 : 28,
              24,
              w >= 1200 ? 40 : 28,
              24,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (item.categoryName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            item.categoryName!.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Text(
                            cleanTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: w >= 1200 ? 44 : 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          meta,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                      if (cleanPlot.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 580),
                            child: Text(
                              cleanPlot,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: onPlay,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 24,
                            ),
                            label: Text(ref.tr('common.play')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (onInfo != null)
                            OutlinedButton.icon(
                              onPressed: onInfo,
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                              ),
                              label: Text(ref.tr('common.details')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showPoster) ...[
                  const SizedBox(width: 28),
                  _HeroPoster(item: item, tmdb: tmdb),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPoster extends StatelessWidget {
  final MediaItem item;
  final TmdbDetail? tmdb;
  const _HeroPoster({required this.item, required this.tmdb});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final posterW = w >= 1200 ? 200.0 : 160.0;
    final posterH = posterW * 1.5;
    final imageUrl = (tmdb?.posterUrl?.isNotEmpty ?? false)
        ? tmdb!.posterUrl
        : (item.logoUrl?.isNotEmpty ?? false)
        ? item.logoUrl
        : item.backdropUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(-0.14),
      child: Container(
        width: posterW,
        height: posterH,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(-10, 14),
            ),
          ],
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          // Poster shown sharp (~200dp); 400px is enough for 2x retina.
          memCacheWidth: 400,
          maxWidthDiskCache: 600,
          placeholder: (_, _) => Container(color: AppColors.surfaceElevated),
          errorWidget: (_, _, _) => Container(color: AppColors.surfaceElevated),
        ),
      ),
    );
  }
}
