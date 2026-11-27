
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../sources/domain/media_item.dart';

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
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final w = MediaQuery.sizeOf(context).width;
    final mobile = !PlatformInfo.isTv && w < 768;

    final cardWidth = mobile
        ? (w * 0.64).clamp(170.0, 280.0).toDouble()
        : 320.0;

    final cardHeight = cardWidth * 9 / 16;
    final padding = mobile ? 16.0 : 24.0;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding, 0, padding, 6,
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 19,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: mobile ? 16 : 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: cardHeight + 18,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: 9,
              ),
              clipBehavior: Clip.none,
              cacheExtent: mobile ? 300 : 600,
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final item = items[i];

                return _BackdropTile(
                  item: item,
                  width: cardWidth,
                  onTap: () => onTap(item),
                );
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
  final double width;
  final VoidCallback onTap;

  const _BackdropTile({
    required this.item,
    required this.width,
    required this.onTap,
  });

  @override
  ConsumerState<_BackdropTile> createState() =>
      _BackdropTileState();
}

class _BackdropTileState
    extends ConsumerState<_BackdropTile> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final tmdb = ref.watch(
      tmdbDetailProvider(
        TmdbLookupArgs.fromItem(widget.item),
      ),
    ).value;

    String? image;

    for (final url in [
      tmdb?.backdropUrl,
      widget.item.backdropUrl,
      tmdb?.posterUrl,
      widget.item.logoUrl,
    ]) {
      if (url != null && url.trim().isNotEmpty) {
        image = url;
        break;
      }
    }

    final title = widget.item.displayName
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final rating = widget.item.rating;
    final year = widget.item.year;
    final active = _hover || _focus;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (value) =>
            setState(() => _focus = value),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey ==
                      LogicalKeyboardKey.select ||
                  event.logicalKey ==
                      LogicalKeyboardKey.enter ||
                  event.logicalKey ==
                      LogicalKeyboardKey.gameButtonA)) {
            widget.onTap();
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: active ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: SizedBox(
              width: widget.width,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(
                      color: AppColors.surfaceElevated,
                    ),

                    if (image != null)
                      CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        memCacheWidth: 640,
                        maxWidthDiskCache: 640,
                        placeholder: (_, _) =>
                            const SizedBox.shrink(),
                        errorWidget: (_, _, _) =>
                            const _ImageFallback(),
                      )
                    else
                      const _ImageFallback(),

                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xEE000000),
                            Color(0x00000000),
                          ],
                          stops: [0.0, 0.75],
                        ),
                      ),
                    ),

                    if (rating != null &&
                        rating > 0 &&
                        rating <= 10)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius:
                                BorderRadius.circular(5),
                          ),
                          child: Text(
                            '★ ${rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (year != null)
                            Text(
                              '$year',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_focus)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.accent,
                                width: 3,
                              ),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.movie_outlined,
        color: AppColors.accent,
        size: 36,
      ),
    );
  }
}
