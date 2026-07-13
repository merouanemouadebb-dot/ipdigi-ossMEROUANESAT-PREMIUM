import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/hero_banner.dart';
import '../../sources/domain/media_item.dart';

/// Carousel that wraps HeroBanner in a PageView at the top of the home
/// page. Manual slide across 3-5 featured movies/shows; pure horizontal
/// swipe + peek dots + left/right arrow buttons. No auto-rotate - it's
/// jarring if the page slides before the user finishes reading the plot.
class HeroCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem) onPlay;
  final void Function(MediaItem) onInfo;
  const HeroCarousel({
    super.key,
    required this.items,
    required this.onPlay,
    required this.onInfo,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _pageCtrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _shift(int dir) {
    if (widget.items.length < 2 || !_pageCtrl.hasClients) return;
    final next = (_index + dir) % widget.items.length;
    final target = next < 0 ? next + widget.items.length : next;
    _pageCtrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    // Landscape (TV / desktop): make the hero a fraction of the viewport
    // HEIGHT so the content row below ("Latest releases") peeks and the
    // hero does NOT fill the screen. It used to be a fixed dp (420) based
    // on width; on a 1080p TV (960x540dp) that was ~78% of the height =
    // almost full screen. Portrait (phone): still based on width as before.
    final double height;
    if (size.width > size.height) {
      height = (size.height * 0.58).clamp(300.0, 460.0);
    } else {
      height = w >= 768 ? 420.0 : 380.0;
    }
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.items.length,
            itemBuilder: (_, i) {
              final item = widget.items[i];
              return HeroBanner(
                item: item,
                onPlay: () => widget.onPlay(item),
                onInfo: () => widget.onInfo(item),
              );
            },
          ),
        ),
        if (widget.items.length > 1)
          // Peek dots sit in a separate strip BELOW the banner - no
          // clash with the CTA buttons. Right-aligned, 12px top spacing.
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: _PeekDots(
                count: widget.items.length,
                index: _index,
                onPrev: () => _shift(-1),
                onNext: () => _shift(1),
              ),
            ),
          ),
      ],
    );
  }
}

class _PeekDots extends StatelessWidget {
  final int count;
  final int index;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PeekDots({
    required this.count,
    required this.index,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
        const SizedBox(width: 12),
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 26 : 8,
            height: 5,
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        const SizedBox(width: 12),
        _ArrowButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _ArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _hover = false;
  bool _focus = false;
  bool get _active => _hover || _focus;

  @override
  Widget build(BuildContext context) {
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
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _active
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.12),
              border: (_focus && PlatformInfo.isTv)
                  ? Border.all(color: AppColors.accent, width: 3)
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
