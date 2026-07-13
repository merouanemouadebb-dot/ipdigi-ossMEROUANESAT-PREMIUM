import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/i18n.dart';
import '../../core/metadata/tmdb_service.dart';
import '../../core/theme/app_theme.dart';

/// Shows TMDB reviews in a horizontal card strip. Each card has the author
/// + optional rating + a content excerpt (clamped); when the user taps, the
/// detail sheet shows the full content.
class ReviewsStrip extends ConsumerWidget {
  final List<TmdbReview> reviews;
  const ReviewsStrip({super.key, required this.reviews});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 18, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 32, bottom: 10),
            child: Text(
              ref.tr('detail.reviews'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 32),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final r = reviews[i];
                return _ReviewCard(
                  review: r,
                  onTap: () => _showFull(context, ref, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFull(BuildContext context, WidgetRef ref, TmdbReview r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Avatar(url: r.avatarUrl, name: r.author),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.author,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (r.createdAt != null && r.createdAt!.isNotEmpty)
                          Text(
                            r.createdAt!.substring(
                              0,
                              r.createdAt!.length < 10
                                  ? r.createdAt!.length
                                  : 10,
                            ),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (r.rating != null) _RatingBadge(rating: r.rating!),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtl,
                  child: Text(
                    r.content,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.55,
                    ),
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

class _ReviewCard extends StatelessWidget {
  final TmdbReview review;
  final VoidCallback onTap;
  const _ReviewCard({required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(url: review.avatarUrl, name: review.author),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        review.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (review.rating != null) ...[
                      const SizedBox(width: 6),
                      _RatingBadge(rating: review.rating!),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    review.content,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
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

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: 32,
        height: 32,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Fallback(initial: initial),
                errorWidget: (_, __, ___) => _Fallback(initial: initial),
              )
            : _Fallback(initial: initial),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String initial;
  const _Fallback({required this.initial});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accent.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;
  const _RatingBadge({required this.rating});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
