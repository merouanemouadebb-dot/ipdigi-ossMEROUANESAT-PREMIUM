import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'image_viewer.dart';

/// Horizontal-scrolling row of stills/backdrops used on movie & series
/// detail pages. Hands off layout to [ListView.separated] so wide rows
/// virtualize cleanly; cards are a fixed 16:9 aspect.
class GalleryStrip extends StatelessWidget {
  final String title;
  final List<String> images;
  /// Which item the download files are named after (e.g. the film name).
  /// The download path goes to the Documents/<appSlug>/Photos/<itemTitle>
  /// folder. If null, a generic "image-<i>.jpg" file name is used.
  final String? downloadTitle;
  /// Zeroes the outer padding when used inside the detail metadata block.
  /// Otherwise, as a standalone Sliver, it gets fromLTRB(32,...) padding.
  final bool inline;
  const GalleryStrip({
    super.key,
    required this.title,
    required this.images,
    this.downloadTitle,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
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
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => ImageViewer.show(
                      context,
                      images: images,
                      initialIndex: i,
                      downloadTitle: downloadTitle,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        fadeInDuration: const Duration(milliseconds: 220),
                        fadeOutDuration: const Duration(milliseconds: 80),
                        imageUrl: images[i],
                        width: 270,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(width: 270, color: AppColors.surface),
                        errorWidget: (_, _, _) =>
                            Container(width: 270, color: AppColors.surface),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
