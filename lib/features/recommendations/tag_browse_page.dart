import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/i18n.dart';
import '../../core/utils/nav_throttle.dart';
import '../../shared/widgets/poster_card.dart';
import '../player/presentation/player_page.dart';
import '../sources/domain/media_item.dart';
import 'detail_backfill_provider.dart';
import 'related_provider.dart';

class TagBrowsePage extends ConsumerWidget {
  final String tag;
  final String tagType; // genre | cast | dir | cat
  final String? excludeId;

  const TagBrowsePage({
    super.key,
    required this.tag,
    required this.tagType,
    this.excludeId,
  });

  String _title(WidgetRef ref) {
    switch (tagType) {
      case 'genre':
        return '${ref.tr('detail.genres')}: $tag';
      case 'cast':
        return '${ref.tr('detail.cast')}: $tag';
      case 'dir':
        return '${ref.tr('detail.director')}: $tag';
      case 'cat':
        return tag;
      default:
        return tag;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = TagBrowseQuery(
      tag: tag,
      tagType: tagType,
      excludeId: excludeId,
    );
    final itemsAsync = ref.watch(tagBrowseProvider(query));
    if (tagType == 'genre' || tagType == 'cast' || tagType == 'dir') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(detailBackfillProvider.notifier).trigger();
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(_title(ref))),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                ref.tr('common.noResults'),
                style: const TextStyle(fontSize: 14),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            cacheExtent: 800,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              childAspectRatio: 2 / 3.4,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return PosterCard(
                item: item,
                onTap: () {
                  switch (item.kind) {
                    case MediaKind.movie:
                      context.pushOnce(
                        '/movie/${item.sourceId}/${item.streamId}',
                      );
                      break;
                    case MediaKind.series:
                      context.pushOnce(
                        '/series/${item.sourceId}/${item.streamId}',
                      );
                      break;
                    case MediaKind.live:
                      context.pushOnce(
                        '/player',
                        extra: PlayerArgs(
                          item: item,
                          isLive: true,
                          startAt: Duration.zero,
                        ),
                      );
                      break;
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
