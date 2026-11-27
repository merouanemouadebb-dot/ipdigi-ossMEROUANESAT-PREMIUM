
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/platform_info.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/providers/adult_filter_provider.dart';
import '../../features/sources/domain/media_item.dart';

class PosterCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final double? width;
  final double aspectRatio;

  const PosterCard({
    super.key,
    required this.item,
    this.onTap,
    this.onRemove,
    this.width,
    this.aspectRatio = 2 / 3,
  });

  @override
  ConsumerState<PosterCard> createState() =>
      _PosterCardState();
}

class _PosterCardState extends ConsumerState<PosterCard> {
  bool _hover = false;
  bool _focus = false;

  bool get _active => _hover || _focus;

  bool _hasText(String? s) =>
      s != null && s.trim().isNotEmpty;

  bool _isTmdbCdn(String? u) =>
      u != null &&
      u.toLowerCase().contains('image.tmdb.org');

  String? get _bestArtwork {
    final isAdultItem = isAdult(widget.item);

    String? pick(String? url) {
      if (!_hasText(url)) return null;
      if (isAdultItem && _isTmdbCdn(url)) return null;
      return url;
    }

    return pick(widget.item.logoUrl) ??
        pick(widget.item.backdropUrl);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _active ? 1.05 : 1.0;

    final card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) =>
            setState(() => _focus = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey ==
                      LogicalKeyboardKey.select ||
                  event.logicalKey ==
                      LogicalKeyboardKey.enter ||
                  event.logicalKey ==
                      LogicalKeyboardKey.gameButtonA)) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(
              milliseconds: 160,
            ),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 160,
              ),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(10),
                border: (_focus && PlatformInfo.isTv)
                    ? Border.all(
                        color: AppColors.accent,
                        width: 3,
                      )
                    : null,
                boxShadow: _active
                    ? [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.45),
                          blurRadius: 20,
                          spreadRadius: -2,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(),
                    if (_active)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(
                                  alpha: 0.85,
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.7],
                            ),
                          ),
                        ),
                      ),
                    if (_active)
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 8,
                        child: Text(
                          widget.item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (_active && widget.onRemove != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withValues(
                            alpha: 0.65,
                          ),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder:
                                const CircleBorder(),
                            onTap: widget.onRemove,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
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

    if (widget.width != null) {
      return SizedBox(
        width: widget.width,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildImage() {
    final url = _bestArtwork;

    if (url == null || url.isEmpty) {
      return _placeholder();
    }

    return CachedNetworkImage(
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      maxWidthDiskCache: 600,
      placeholder: (_, __) => Container(
        color: AppColors.surfaceElevated,
      ),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (constraints.maxHeight >= 90) ...[
                const Icon(
                  Icons.movie_outlined,
                  size: 28,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: Text(
                  widget.item.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
