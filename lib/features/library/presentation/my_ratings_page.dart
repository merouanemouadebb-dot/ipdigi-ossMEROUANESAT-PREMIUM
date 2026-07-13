import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';
import '../providers/ratings_provider.dart';
import 'rate_content_sheet.dart';

/// All movies / series the user has rated. The newest rating is on top
/// (ratedAt desc). Each card shows a rating badge plus a short preview of
/// the comment if there is one. Tapping the card opens the detail page;
/// tapping the top-right icon opens the rating sheet (edit / delete).
class MyRatingsPage extends ConsumerWidget {
  const MyRatingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingsAsync = ref.watch(userRatingsProvider);
    final allItems = ref
            .watch(libraryItemsProvider(const LibraryItemsArgs()))
            .value ??
        const <MediaItem>[];
    final catalog = {for (final i in allItems) i.id: i};
    final ratings = ratingsAsync.value ?? const <String, UserRating>{};
    // Watched unconditionally (FutureProvider is cached, so the dependency
    // graph stays consistent - avoids the conditional-watch anti-pattern).
    final tmdbByContent =
        ref.watch(contentTmdbIdMapProvider).value ?? const <String, int>{};
    // The cross-panel matching index is built only WHEN NEEDED: when a
    // rating carries a tmdbId but isn't in the catalog (orphan). Otherwise
    // the whole catalog (tens of thousands) is scanned needlessly per build.
    final needsTmdbIndex = ratings.values.any(
      (r) => r.tmdbId != null && !catalog.containsKey(r.contentId),
    );
    Map<int, MediaItem> byTmdb = const {};
    if (needsTmdbIndex) {
      final m = <int, MediaItem>{};
      for (final i in allItems) {
        final t = tmdbByContent[i.id];
        if (t != null) m.putIfAbsent(t, () => i);
      }
      byTmdb = m;
    }
    final rows = <_RatingRow>[];
    for (final r in ratings.values) {
      // Direct identity first (same panel), else cross-panel via tmdbId.
      final item =
          catalog[r.contentId] ?? (r.tmdbId != null ? byTmdb[r.tmdbId] : null);
      if (item != null && isAdult(item)) continue;
      rows.add(_RatingRow(rating: r, item: item));
    }
    rows.sort((a, b) => b.rating.ratedAt.compareTo(a.rating.ratedAt));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ref.tr('myRatings.title')),
      ),
      body: ratingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (_) {
          if (rows.isEmpty) {
            return EmptyStateView(
              icon: Icons.star_rounded,
              title: ref.tr('myRatings.empty'),
              message: ref.tr('myRatings.emptyMsg'),
              action: ElevatedButton(
                onPressed: () => context.go('/movies'),
                child: Text(ref.tr('library.discover')),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxExtent =
                  constraints.maxWidth < 600 ? 150.0 : 180.0;
              return GridView.builder(
                padding: const EdgeInsets.all(20),
                cacheExtent: 800,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  childAspectRatio: 2 / 4.0,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  return _RatingTile(
                    row: row,
                    onTap: () => _openContent(context, row),
                    onEdit: () => _openEditor(context, ref, row),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openContent(BuildContext context, _RatingRow row) {
    final item = row.item;
    if (item == null) return;
    if (item.kind == MediaKind.series) {
      context.pushOnce('/series/${item.sourceId}/${item.streamId}');
    } else {
      context.pushOnce('/movie/${item.sourceId}/${item.streamId}');
    }
  }

  void _openEditor(BuildContext context, WidgetRef ref, _RatingRow row) {
    final item = row.item;
    // Even when item is null (content removed from the source / permanently
    // deleted) the sheet still opens so the user CAN edit or delete the
    // orphan rating. The sheet's delete button only needs (sourceId,
    // contentId); it doesn't require the catalog.
    RateContentSheet.show(
      context,
      sourceId: row.rating.sourceId,
      contentId: row.rating.contentId,
      contentName: item?.name ?? ref.tr('myRatings.deletedContent'),
      existing: row.rating,
    );
  }
}

class _RatingRow {
  final UserRating rating;
  final MediaItem? item;
  const _RatingRow({required this.rating, required this.item});
}

class _RatingTile extends ConsumerWidget {
  final _RatingRow row;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _RatingTile({
    required this.row,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = row.item;
    final rating = row.rating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item != null)
                PosterCard(item: item, onTap: onTap)
              else
                _OrphanCard(onTap: onTap),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating.score.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEdit,
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.edit_rounded,
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
        const SizedBox(height: 8),
        Text(
          item?.displayName ?? ref.tr('myRatings.deletedContent'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(ref, rating.ratedAt),
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
        if (rating.comment != null && rating.comment!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            rating.comment!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(WidgetRef ref, DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return ref.tr('profile.justNow');
    if (diff.inMinutes < 60) {
      return ref.tr('profile.minutesAgo', {'n': diff.inMinutes.toString()});
    }
    if (diff.inHours < 24) {
      return ref.tr('profile.hoursAgo', {'n': diff.inHours.toString()});
    }
    if (diff.inDays == 1) return ref.tr('profile.yesterday');
    if (diff.inDays < 7) {
      return ref.tr('profile.daysAgo', {'n': diff.inDays.toString()});
    }
    return '${d.year}-${_2(d.month)}-${_2(d.day)}';
  }

  String _2(int v) => v.toString().padLeft(2, '0');
}

/// Card that replaces PosterCard for an orphan rating/history record whose
/// content is gone from the source. Focusable on TV like PosterCard:
/// navigated with the D-pad, opened with SELECT/OK, accent border on focus.
class _OrphanCard extends StatefulWidget {
  final VoidCallback onTap;
  const _OrphanCard({required this.onTap});

  @override
  State<_OrphanCard> createState() => _OrphanCardState();
}

class _OrphanCardState extends State<_OrphanCard> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
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
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: (_focus && PlatformInfo.isTv)
              ? const BorderSide(color: AppColors.accent, width: 3)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: const Center(
            child: Icon(
              Icons.movie_outlined,
              size: 32,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
