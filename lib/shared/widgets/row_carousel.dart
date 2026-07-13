import 'package:flutter/material.dart';

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
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
          child: Row(
            children: [
              Expanded(
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
              if (trailingActions != null) ...trailingActions!,
            ],
          ),
        ),
        SizedBox(
          height: itemWidth / aspectRatio + 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            // Clip.none - the card scales to 1.05 on hover, and the ListView's
            // default hardEdge clip would cut off the edges.
            clipBehavior: Clip.none,
            cacheExtent: 600,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return PosterCard(
                item: item,
                width: itemWidth,
                aspectRatio: aspectRatio,
                onTap: () => onTapItem?.call(item),
                onRemove:
                    onRemoveItem == null ? null : () => onRemoveItem!(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
