import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../shared/widgets/error_dialog.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';
import '../providers/watchlists_provider.dart';
import 'watchlists_page.dart';

/// Shows the contents of a single watchlist as a grid. Rows without a
/// catalog match (e.g. orphans whose source was deleted) are hidden so as
/// not to clutter the user with items that no longer resolve.
class WatchlistDetailPage extends ConsumerWidget {
  final String watchlistId;
  const WatchlistDetailPage({super.key, required this.watchlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(watchlistsProvider);
    Watchlist? list;
    final lists = listsAsync.value;
    if (lists != null) {
      for (final l in lists) {
        if (l.id == watchlistId) {
          list = l;
          break;
        }
      }
    }
    final itemsAsync =
        ref.watch(watchlistItemsProvider(WatchlistItemsArgs(watchlistId)));
    final catalogAsync = ref.watch(
      libraryItemsProvider(const LibraryItemsArgs()),
    );
    final catalog = {
      for (final i in (catalogAsync.value ?? const <MediaItem>[])) i.id: i,
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(list?.name.isNotEmpty == true
            ? list!.name
            : ref.tr('watchlists.title')),
        actions: [
          if (list != null)
            IconButton(
              tooltip: ref.tr('watchlists.edit'),
              onPressed: () =>
                  WatchlistEditorSheet.show(context, ref, existing: list!),
              icon: const Icon(Icons.edit_rounded),
            ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (entries) {
          final resolved = <MediaItem>[];
          for (final e in entries) {
            final it = catalog[e.contentId];
            if (it == null) continue;
            if (isAdult(it)) continue;
            resolved.add(it);
          }
          if (resolved.isEmpty) {
            return EmptyStateView(
              icon: Icons.playlist_play_rounded,
              title: ref.tr('watchlists.noItems'),
              message: list?.description ?? ref.tr('watchlists.emptyMsg'),
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
                  childAspectRatio: 2 / 3.7,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
                itemCount: resolved.length,
                itemBuilder: (context, i) {
                  final item = resolved[i];
                  return GestureDetector(
                    onLongPress: () => _confirmRemove(context, ref, item),
                    child: PosterCard(
                      item: item,
                      onTap: () {
                        if (item.kind == MediaKind.series) {
                          context.pushOnce(
                            '/series/${item.sourceId}/${item.streamId}',
                          );
                        } else {
                          context.pushOnce(
                            '/movie/${item.sourceId}/${item.streamId}',
                          );
                        }
                      },
                      onRemove: () => _confirmRemove(context, ref, item),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(ref.tr('common.delete')),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx, rootNavigator: true).pop(false),
            child: Text(ref.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () =>
                Navigator.of(dialogCtx, rootNavigator: true).pop(true),
            child: Text(ref.tr('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(watchlistsProvider.notifier).removeItem(
            watchlistId: watchlistId,
            contentId: item.id,
            sourceId: item.sourceId,
          );
    } catch (e, st) {
      // ignore: avoid_print
      print('[Watchlist] removeItem hata: $e\n$st');
      if (!context.mounted) return;
      await showErrorDialog(
        context,
        source: 'Watchlist removeItem',
        error: e,
        stack: st,
      );
    }
  }
}

