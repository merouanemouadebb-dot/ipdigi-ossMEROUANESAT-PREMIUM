import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../shared/widgets/error_dialog.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';
import '../providers/library_provider.dart';

/// Watch history - poster grid + name, series episode (if any),
/// category and a "skimmed / completed" badge under each card. The
/// difference from ContinueWatching: completed and skimmed rows also
/// appear; they can be deleted individually or all at once.
class WatchHistoryPage extends ConsumerWidget {
  const WatchHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final allItemsAsync = ref.watch(
      libraryItemsProvider(const LibraryItemsArgs()),
    );
    final catalog = {
      for (final i in (allItemsAsync.value ?? const <MediaItem>[])) i.id: i,
    };
    final entries = <_HistoryRow>[];
    for (final h in (history.value ?? const <HistoryEntry>[])) {
      if (h.duration.inMilliseconds == 0) continue;
      // A series episode has no catalog item; we fetch the parent series
      // item via parentId. If there's no match we record it as an orphan
      // row but still show it (so the user can delete it).
      final lookup = catalog[h.contentId] ??
          (h.parentId != null ? catalog[h.parentId!] : null);
      if (lookup != null && isAdult(lookup)) continue;
      entries.add(_HistoryRow(entry: h, item: lookup));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ref.tr('history.title')),
        actions: [
          IconButton(
            tooltip: ref.tr('history.clearAll'),
            onPressed: entries.isEmpty
                ? null
                : () => _confirmClearAll(context, ref),
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (_) {
          if (entries.isEmpty) {
            return EmptyStateView(
              icon: Icons.history_rounded,
              title: ref.tr('history.empty'),
              message: ref.tr('history.emptyMsg'),
              action: ElevatedButton(
                onPressed: () => context.go('/movies'),
                child: Text(ref.tr('library.discover')),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              // A slightly taller aspect ratio (2 / 4.0) for the poster +
              // 3-4 text lines below; so category and episode badge don't overflow.
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
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final row = entries[i];
                  return _HistoryTile(
                    row: row,
                    onTap: () => _openContent(context, row),
                    onRemove: () => _confirmDelete(context, ref, row.entry),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openContent(BuildContext context, _HistoryRow row) {
    final item = row.item;
    if (item == null) return;
    // Series episode record: route to the parent series detail; there's no
    // single-episode page, let the user pick from there.
    if (row.entry.parentId != null) {
      final parts = row.entry.parentId!.split('|');
      if (parts.length >= 2) {
        context.pushOnce('/series/${parts[0]}/${parts[1]}');
        return;
      }
    }
    if (item.kind == MediaKind.series) {
      context.pushOnce('/series/${item.sourceId}/${item.streamId}');
    } else {
      context.pushOnce('/movie/${item.sourceId}/${item.streamId}');
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(ref.tr('history.clearAll')),
        content: Text(ref.tr('history.confirmAll')),
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
      await ref.read(historyProvider.notifier).clearAll();
    } catch (e, st) {
      // ignore: avoid_print
      print('[History] clearAll hata: $e\n$st');
      if (!context.mounted) return;
      await showErrorDialog(
        context,
        source: 'History clearAll',
        error: e,
        stack: st,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HistoryEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(ref.tr('common.delete')),
        content: Text(ref.tr('history.confirmSingle')),
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
      await ref.read(historyProvider.notifier).remove(
            sourceId: entry.sourceId,
            contentId: entry.contentId,
          );
    } catch (e, st) {
      // ignore: avoid_print
      print('[History] remove hata: $e\n$st');
      if (!context.mounted) return;
      await showErrorDialog(
        context,
        source: 'History remove',
        error: e,
        stack: st,
      );
    }
  }
}

class _HistoryRow {
  final HistoryEntry entry;
  /// The parent series item for series episodes; the movie itself for
  /// movies; null for orphan records.
  final MediaItem? item;
  const _HistoryRow({required this.entry, required this.item});

  bool get isSeries => entry.parentId != null;
}

class _HistoryTile extends ConsumerWidget {
  final _HistoryRow row;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _HistoryTile({
    required this.row,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = row.entry;
    final item = row.item;
    final percent = (entry.progress * 100).round();
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
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
              if (entry.isCompleted)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _Badge(
                    label: ref.tr('history.completed'),
                    color: AppColors.accent,
                  ),
                )
              else if (entry.isSkimmed)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _Badge(
                    label: ref.tr('history.skimmed'),
                    color: Colors.orangeAccent,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: LinearProgressIndicator(
                    value: entry.progress,
                    minHeight: 4,
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    valueColor: AlwaysStoppedAnimation(
                      entry.isSkimmed
                          ? Colors.orangeAccent
                          : AppColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item?.displayName ?? entry.contentId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (entry.episodeLabel != null && entry.episodeLabel!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              entry.episodeLabel!,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          _formatDate(ref, entry.lastWatchedAt),
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              ref.tr(
                'history.watchedPercent',
                {'n': percent.toString()},
              ),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            if ((entry.categoryName ?? item?.categoryName) != null &&
                (entry.categoryName ?? item!.categoryName)!.isNotEmpty)
              Flexible(
                child: Text(
                  '• ${entry.categoryName ?? item!.categoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
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

/// Card that replaces PosterCard for an orphan (source-removed) history
/// record. Focusable on TV: opens with SELECT/OK, accent frame when focused.
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
