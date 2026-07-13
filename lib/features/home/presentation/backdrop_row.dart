import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../sources/domain/media_item.dart';

/// Horizontal 16:9 backdrop carousel that sits between the poster rows on
/// the home page. Breaks up the uniform poster flow - uses the TMDB
/// backdrop as a cover, with the title and rating shown in the bottom
/// corner. When there is no backdrop it falls back to the poster cover.
class BackdropRow extends ConsumerWidget {
  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;
  const BackdropRow({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final m = items[i];
                return _BackdropTile(item: m, onTap: () => onTap(m));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropTile extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _BackdropTile({required this.item, required this.onTap});

  @override
  ConsumerState<_BackdropTile> createState() => _BackdropTileState();
}

class _BackdropTileState extends ConsumerState<_BackdropTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tmdb = ref
        .watch(tmdbDetailProvider(TmdbLookupArgs.fromItem(widget.item)))
        .value;
    final backdrop = (tmdb?.backdropUrl?.isNotEmpty ?? false)
        ? tmdb!.backdropUrl
        : (widget.item.backdropUrl?.isNotEmpty ?? false)
        ? widget.item.backdropUrl
        : tmdb?.posterUrl ?? widget.item.logoUrl;
    final cleanTitle = widget.item.displayName
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final ratingLabel =
        (widget.item.rating != null &&
            widget.item.rating! > 0 &&
            widget.item.rating! < 10)
        ? '★ ${widget.item.rating!.toStringAsFixed(1)}'
        : null;
    final year = widget.item.year?.toString();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // Border color doesn't change on hover - scale + neutral shadow.
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.surfaceElevated),
                  if (backdrop != null && backdrop.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: backdrop,
                      fit: BoxFit.cover,
                      // Tile is 320dp wide; 640px is enough for 2x retina.
                      // Without cacheWidth the original TMDB backdrop (>1280px)
                      // got decoded, causing scroll jank/memory pressure on TV.
                      memCacheWidth: 640,
                      maxWidthDiskCache: 640,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  // Bottom gradient - contrast for the title
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.92),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                        stops: const [0, 0.6],
                      ),
                    ),
                  ),
                  // Rating in the top-right
                  if (ratingLabel != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ratingLabel,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  // Bottom-left: title + year
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (year != null) ...[
                          Text(
                            year,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          cleanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
