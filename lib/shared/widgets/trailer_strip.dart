import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/i18n.dart';
import '../../core/metadata/tmdb_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/trailer/trailer_server.dart';

/// Horizontal-scrolling row of TMDB trailer thumbnails (gallery-shaped).
/// Tapping a card opens an inline modal player that loads the trailer via
/// a localhost HTTP shim (`TrailerServer`) so YouTube's embed gate gets
/// a trusted http:// origin instead of refusing a `data:` URI with
/// error 152.
class TrailerStrip extends StatelessWidget {
  final String title;
  final List<TmdbVideo> trailers;
  /// Zeroes the outer padding when used inside the detail metadata block.
  final bool inline;
  const TrailerStrip({
    super.key,
    required this.title,
    required this.trailers,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (trailers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: inline
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trailers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final v = trailers[i];
                return _TrailerCard(
                  video: v,
                  onTap: () => _openPlayer(context, v),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openPlayer(BuildContext context, TmdbVideo video) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => _TrailerPlayerDialog(video: video),
    );
  }
}

class _TrailerCard extends StatefulWidget {
  final TmdbVideo video;
  final VoidCallback onTap;
  const _TrailerCard({required this.video, required this.onTap});

  @override
  State<_TrailerCard> createState() => _TrailerCardState();
}

class _TrailerCardState extends State<_TrailerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: SizedBox(
            width: 270,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      SizedBox(
                        width: 270,
                        height: 152,
                        child: CachedNetworkImage(
                          imageUrl: v.thumbnailUrl,
                          fit: BoxFit.cover,
                          fadeInDuration:
                              const Duration(milliseconds: 220),
                          fadeOutDuration:
                              const Duration(milliseconds: 80),
                          placeholder: (_, __) =>
                              Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.surface),
                        ),
                      ),
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black54,
                              ],
                              stops: [0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          color: _hover
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.transparent,
                          alignment: Alignment.center,
                          child: AnimatedScale(
                            scale: _hover ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 160),
                            child: Icon(
                              Icons.play_circle_filled_rounded,
                              size: 56,
                              color: _hover
                                  ? AppColors.accent
                                  : Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            v.type.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  v.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrailerPlayerDialog extends ConsumerWidget {
  final TmdbVideo video;
  const _TrailerPlayerDialog({required this.video});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.85).clamp(600.0, 1280.0);
    final height = width * 9 / 16;
    final server = TrailerServer.instance;
    final canPlay = server.isRunning;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: width,
              height: height,
              child: canPlay
                  ? InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(server.urlFor(video.key)),
                      ),
                      initialSettings: InAppWebViewSettings(
                        transparentBackground: false,
                        mediaPlaybackRequiresUserGesture: false,
                        disableContextMenu: true,
                        userAgent:
                            'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
                      ),
                    )
                  : Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Text(
                        ref.tr('trailer.playerUnavailable'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.black,
              shape: const CircleBorder(
                  side: BorderSide(color: Colors.white24, width: 1)),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
