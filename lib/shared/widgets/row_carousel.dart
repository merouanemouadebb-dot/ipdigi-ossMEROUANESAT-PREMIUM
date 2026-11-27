
import 'package:flutter/material.dart';

import '../../core/config/platform_info.dart';
import '../../core/theme/app_theme.dart';
import '../../features/sources/domain/media_item.dart';
import 'poster_card.dart';

class RowCarousel extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem item)? onTapItem;
  final void Function(MediaItem item)? onRemoveItem;
  final List<Widget>? trailingActions;
  final double itemWidth;
  final double aspectRatio;

  const RowCarousel({
    super.key,
    required this.title,
    required this.items,
    this.onTapItem,
    this.onRemoveItem,
    this.trailingActions,
    this.itemWidth = 160,
    this.aspectRatio = 2 / 3,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;

    final mobile =
        !PlatformInfo.isTv && width < 768;

    final cardWidth = mobile && itemWidth == 160
        ? ((width - 52) / 3)
            .clamp(75.0, 145.0)
            .toDouble()
        : itemWidth;

    final padding = mobile ? 16.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            padding, 12, padding, 6,
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
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailingActions != null)
                ...trailingActions!,
            ],
          ),
        ),
        SizedBox(
          height: cardWidth / aspectRatio +
              (mobile ? 18 : 36),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: mobile ? 9 : 12,
            ),
            clipBehavior: Clip.none,
            cacheExtent: mobile ? 300 : 600,
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: mobile ? 10 : 12),
            itemBuilder: (context, i) {
              final item = items[i];

              return PosterCard(
                item: item,
                width: cardWidth,
                aspectRatio: aspectRatio,
                onTap: () => onTapItem?.call(item),
                onRemove: onRemoveItem == null
                    ? null
                    : () => onRemoveItem!(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
