
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/hero_banner.dart';
import '../../sources/domain/media_item.dart';

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
  State<HeroCarousel> createState() =>
      _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _pageCtrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_index >= widget.items.length) {
      _index = 0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(0);
        }
      });
    }
  }

  void _shift(int dir) {
    if (widget.items.length < 2 ||
        !_pageCtrl.hasClients) return;

    final target =
        (_index + dir + widget.items.length) %
            widget.items.length;

    _pageCtrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final mobile = !PlatformInfo.isTv &&
        size.width < 768 &&
        size.width < size.height;

    final textScale =
        MediaQuery.textScalerOf(context).scale(14) / 14;

    final extraHeight = ((textScale - 1) * 140)
        .clamp(0.0, 180.0)
        .toDouble();

    final height = mobile
        ? 270.0 + extraHeight
        : size.width > size.height
            ? (size.height * 0.58)
                .clamp(300.0, 460.0)
                .toDouble()
            : 420.0;

    return Column(
      children: [
        if (mobile) const _PremiumHeader(),

        if (widget.items.isNotEmpty)
          Padding(
            padding: mobile
                ? const EdgeInsets.symmetric(horizontal: 16)
                : EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                mobile ? 16 : 0,
              ),
              child: SizedBox(
                height: height,
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) =>
                      setState(() => _index = i),
                  itemCount: widget.items.length,
                  itemBuilder: (_, i) {
                    final item = widget.items[i];

                    if (mobile) {
                      return _PremiumBanner(
                        item: item,
                        onPlay: () => widget.onPlay(item),
                        onInfo: () => widget.onInfo(item),
                      );
                    }

                    return HeroBanner(
                      item: item,
                      onPlay: () => widget.onPlay(item),
                      onInfo: () => widget.onInfo(item),
                    );
                  },
                ),
              ),
            ),
          ),

        if (widget.items.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16, 8, 16, 4,
            ),
            child: Align(
              alignment: mobile
                  ? Alignment.center
                  : Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _shift(-1),
                  ),
                  const SizedBox(width: 10),
                  for (var i = 0;
                      i < widget.items.length;
                      i++)
                    AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 200,
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      width: i == _index ? 24 : 7,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppColors.accent
                            : AppColors.textTertiary,
                        borderRadius:
                            BorderRadius.circular(4),
                      ),
                    ),
                  const SizedBox(width: 10),
                  _ArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _shift(1),
                  ),
                ],
              ),
            ),
          ),

        if (mobile) const _QuickAccess(),
      ],
    );
  }
}

class _PremiumHeader extends ConsumerWidget {
  const _PremiumHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16, 8, 12, 14,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'MEROUANESAT',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    'P R E M I U M',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: ref.tr('nav.search'),
              onPressed: () => context.go('/search'),
              icon: const Icon(
                Icons.search_rounded,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBanner extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  const _PremiumBanner({
    required this.item,
    required this.onPlay,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmdb = ref.watch(
      tmdbDetailProvider(
        TmdbLookupArgs.fromItem(item),
      ),
    ).value;

    String? image;

    for (final url in [
      tmdb?.backdropUrl,
      item.backdropUrl,
      tmdb?.posterUrl,
      item.logoUrl,
    ]) {
      if (url != null && url.trim().isNotEmpty) {
        image = url;
        break;
      }
    }

    final rating = item.rating;

    final title = item.displayName
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const fallback = Center(
      child: Icon(
        Icons.movie_outlined,
        color: AppColors.accent,
        size: 52,
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(
          color: AppColors.surfaceElevated,
        ),

        if (image != null)
          CachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            memCacheWidth: 1000,
            maxWidthDiskCache: 1280,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          )
        else
          fallback,

        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x11000000),
                Color(0x66000000),
                Color(0xF5000000),
              ],
              stops: [0.0, 0.38, 1.0],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (item.categoryName?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: AppColors.accent,
                    ),
                  ),
                  child: Text(
                    item.categoryName!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              Flexible(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                [
                  if (rating != null &&
                      rating > 0 &&
                      rating <= 10)
                    '★ ${rating.toStringAsFixed(1)}',
                  if (item.year != null)
                    '${item.year}',
                ].join('  ·  '),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onPlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(9),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              item.kind == MediaKind.series
                                  ? ref.tr('common.watch')
                                  : ref.tr('common.play'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onInfo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black38,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.all(8),
                        side: const BorderSide(
                          color: Colors.white54,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 5),
                            Text(ref.tr('common.details')),
                          ],
                        ),
                      ),
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

class _QuickAccess extends ConsumerWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16, 6, 16, 8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.live_tv_rounded,
                  label: ref.tr('nav.live'),
                  onTap: () => context.go('/live'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickTile(
                  icon: Icons.movie_rounded,
                  label: ref.tr('nav.movies'),
                  onTap: () => context.go('/movies'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickTile(
                  icon: Icons.tv_rounded,
                  label: ref.tr('nav.series'),
                  onTap: () => context.go('/series'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/continue'),
              icon: const Icon(Icons.history_rounded),
              label: Text(
                ref.tr('home.continueWatching'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(
                  color: AppColors.divider,
                ),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accent, size: 25),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
            widget.onTap();
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(
                alpha: _hover || _focus ? 0.22 : 0.08,
              ),
              border: _focus
                  ? Border.all(
                      color: AppColors.accent,
                      width: 2,
                    )
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
