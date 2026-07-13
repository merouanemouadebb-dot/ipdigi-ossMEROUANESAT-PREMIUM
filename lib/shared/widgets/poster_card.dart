import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/platform_info.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/providers/adult_filter_provider.dart';
import '../../features/sources/domain/media_item.dart';

/// Library tile used in carousels and grids.
///
/// Important rule: this widget **does not do a TMDB lookup**, because it
/// is rendered on every row inside a list/grid. We used to watch
/// `tmdbDetailProvider` for each card - entering a grid of 200 items
/// triggered 200 parallel TMDB requests, and the posters arrived minutes
/// late due to the Dio queue and the TMDB rate limit. We take the list
/// poster from the panel's own URL - if the panel gives a low-quality
/// one, TMDB kicks in when the detail page opens and the hero/poster
/// appears there in high quality.
class PosterCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  /// When set, the card wraps itself with a SizedBox + AspectRatio so it can
  /// live in horizontal carousels. In a GridView leave [width] null so the
  /// grid slot decides the size and we avoid double-sizing artifacts.
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
  ConsumerState<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends ConsumerState<PosterCard> {
  bool _hover = false;
  bool _focus = false;

  bool get _active => _hover || _focus;

  bool _hasText(String? s) => s != null && s.trim().isNotEmpty;

  bool _isTmdbCdn(String? u) =>
      u != null && u.toLowerCase().contains('image.tmdb.org');

  /// The best artwork URL the panel provides. The adult filter drops
  /// TMDB CDN links - the panel ships image.tmdb.org links for its XXX
  /// records and these pull images from TMDB servers even without making
  /// a TMDB API call.
  String? get _bestArtwork {
    final isAdultItem = isAdult(widget.item);
    String? pick(String? url) {
      if (!_hasText(url)) return null;
      if (isAdultItem && _isTmdbCdn(url)) return null;
      return url;
    }

    return pick(widget.item.logoUrl) ?? pick(widget.item.backdropUrl);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _active ? 1.05 : 1.0;
    final card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _focus = v),
        // TV remote: open the card with OK/SELECT/Enter while it is
        // focused. GestureDetector only detects taps; unless we separately
        // catch the D-pad SELECT, cards cannot be opened with the remote.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                // On TV (remote) the focus must be clearly visible: a thick
                // accent border on focus. No border on phone/mouse hover
                // (user request), just scale + shadow.
                border: (_focus && PlatformInfo.isTv)
                    ? Border.all(color: AppColors.accent, width: 3)
                    : null,
                boxShadow: _active
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 20,
                          spreadRadius: -2,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
                                Colors.black.withValues(alpha: 0.85),
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
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: widget.onRemove,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded,
                                  color: Colors.white, size: 16),
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
      // Zero fade so cache hits paint instantly. The 220 ms fade made
      // every off-screen-then-on-screen scroll look like the poster was
      // reloading even when the bitmap was already on disk.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      imageUrl: url,
      fit: BoxFit.cover,
      // Limit memory pressure: no need to decode above 400px (the card at
      // its widest is ~200dp, retina 2x = 400px). Otherwise high-resolution
      // panel/TMDB posters (1500px) bloat the memory cache, and scrolling
      // loads late even on the same page twice.
      memCacheWidth: 400,
      maxWidthDiskCache: 600,
      placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          widget.item.displayName,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}
