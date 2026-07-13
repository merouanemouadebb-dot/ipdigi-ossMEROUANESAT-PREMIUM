import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/nav_throttle.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../settings/providers/adult_filter_provider.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';
import '../providers/library_provider.dart';

/// "Continue Watching" - the single central management page for the
/// movies/series the user left unfinished. Supports deleting one at a
/// time (the × on the card) and bulk deletion via selection mode. The
/// AppBar's "Clear All" removes every visible card (0%/100% or orphan
/// records outside the catalog are already absent here, so it leaves them).
class ContinueWatchingPage extends ConsumerStatefulWidget {
  const ContinueWatchingPage({super.key});

  @override
  ConsumerState<ContinueWatchingPage> createState() =>
      _ContinueWatchingPageState();
}

class _ContinueWatchingPageState extends ConsumerState<ContinueWatchingPage> {
  bool _selectMode = false;
  final Set<String> _selectedKeys = <String>{};

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedKeys.clear();
    });
  }

  void _toggleItem(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  /// When a card is deleted, [removeForContent] removes both `contentId`
  /// and `parentId` matches - so selecting a series clears all of that
  /// series' episode history records at once. For movies only that movie
  /// is deleted (there is no parentId anyway).
  Future<void> _deleteOne(MediaItem item) async {
    await ref
        .read(historyProvider.notifier)
        .removeForContent(sourceId: item.sourceId, contentId: item.id);
  }

  Future<void> _deleteSelected(List<_ContinueEntry> all) async {
    if (_selectedKeys.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          ref.tr('continueWatching.confirmSelected', {
            'n': _selectedKeys.length.toString(),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: Text(ref.tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: Text(ref.tr('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final selected = all
        .where((e) => _selectedKeys.contains(e.item.id))
        .map((e) => e.item)
        .toList();
    for (final item in selected) {
      await ref
          .read(historyProvider.notifier)
          .removeForContent(sourceId: item.sourceId, contentId: item.id);
    }
    if (!mounted) return;
    setState(() {
      _selectedKeys.clear();
      _selectMode = false;
    });
  }

  Future<void> _deleteAll(List<_ContinueEntry> all) async {
    if (all.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(ref.tr('continueWatching.confirmAll')),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: Text(ref.tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: Text(ref.tr('common.clearAll')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final e in all) {
      await ref
          .read(historyProvider.notifier)
          .removeForContent(sourceId: e.item.sourceId, contentId: e.item.id);
    }
    if (!mounted) return;
    setState(() {
      _selectedKeys.clear();
      _selectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allItemsAsync = ref.watch(
      libraryItemsProvider(const LibraryItemsArgs()),
    );
    final history = ref.watch(historyProvider);

    // Compute once; kept at the top of build so both the AppBar actions
    // and the body use the same reference.
    final entries = _resolveItems(
      allItemsAsync.value ?? const [],
      history.value ?? const [],
    );

    // If entries empties out in selection mode after a delete or a
    // provider invalidation, staying in the mode is pointless - auto-close.
    if (_selectMode && entries.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectMode && entries.isEmpty) {
          setState(() {
            _selectMode = false;
            _selectedKeys.clear();
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectMode
              ? ref.tr('continueWatching.selectedCount', {
                  'n': _selectedKeys.length.toString(),
                })
              : ref.tr('continueWatching.title'),
        ),
        actions: _selectMode
            ? [
                TextButton.icon(
                  onPressed: _selectedKeys.isEmpty
                      ? null
                      : () => _deleteSelected(entries),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _selectedKeys.isEmpty
                        ? ref.tr('common.delete')
                        : '${ref.tr('common.delete')} (${_selectedKeys.length})',
                  ),
                ),
                IconButton(
                  tooltip: ref.tr('common.cancel'),
                  onPressed: _toggleSelectMode,
                  icon: const Icon(Icons.close_rounded),
                ),
              ]
            : [
                // Pushed the destructive action left so it does not read
                // like an overflow; "Select" stays near the right edge,
                // where the thumb naturally lands.
                IconButton(
                  tooltip: ref.tr('common.clearAll'),
                  onPressed: entries.isEmpty ? null : () => _deleteAll(entries),
                  icon: const Icon(Icons.delete_sweep_rounded),
                ),
                IconButton(
                  tooltip: ref.tr('continueWatching.select'),
                  onPressed: entries.isEmpty ? null : _toggleSelectMode,
                  icon: const Icon(Icons.check_box_outlined),
                ),
              ],
      ),
      body: allItemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (_) {
          if (entries.isEmpty) {
            return EmptyStateView(
              icon: Icons.history_rounded,
              title: ref.tr('continueWatching.empty'),
              message: ref.tr('continueWatching.emptyMsg'),
              action: ElevatedButton(
                onPressed: () => context.go('/movies'),
                child: Text(ref.tr('library.discover')),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              // Bend the max extent to the viewport so narrow mobile keeps
              // 2 columns; wide desktop uses the standard 180.
              final maxExtent = constraints.maxWidth < 600 ? 150.0 : 180.0;
              return GridView.builder(
                padding: const EdgeInsets.all(20),
                cacheExtent: 800,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  childAspectRatio: 2 / 3.7,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final selected = _selectedKeys.contains(e.item.id);
                  return _ContinueTile(
                    entry: e,
                    selectMode: _selectMode,
                    selected: selected,
                    onTap: () {
                      if (_selectMode) {
                        _toggleItem(e.item.id);
                      } else if (e.item.kind == MediaKind.movie) {
                        context.push(
                          '/movie/${e.item.sourceId}/${e.item.streamId}',
                        );
                      } else if (e.item.kind == MediaKind.series) {
                        context.pushOnce(
                          '/series/${e.item.sourceId}/${e.item.streamId}',
                        );
                      }
                    },
                    onLongPress: _selectMode
                        ? null
                        : () {
                            setState(() {
                              _selectMode = true;
                              _selectedKeys.add(e.item.id);
                            });
                          },
                    onRemove: _selectMode ? null : () => _deleteOne(e.item),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Matches history rows against the catalog and returns the ones counted
  /// as "still watching" (≥2% and ≤97%), deduplicated. Series episodes are
  /// folded into their parent series. Orphan rows no longer in the catalog
  /// (source deleted or dropped from the panel) are not shown here. XXX
  /// records are filtered out even when showAdult is on - Continue Watching
  /// is a recommendation surface, not a dedicated browser.
  List<_ContinueEntry> _resolveItems(
    List<MediaItem> all,
    List<HistoryEntry> history,
  ) {
    if (history.isEmpty) return const [];
    final byId = {for (final i in all) i.id: i};
    final seen = <String>{};
    final entries = <_ContinueEntry>[];
    for (final h in history) {
      if (h.duration.inMilliseconds == 0) continue;
      if (h.progress < 0.02 || h.progress > 0.97) continue;
      final key = h.parentId ?? h.contentId;
      if (!seen.add(key)) continue;
      final item = byId[key];
      if (item == null) continue;
      if (isAdult(item)) continue;
      if (item.kind != MediaKind.movie && item.kind != MediaKind.series) {
        continue;
      }
      entries.add(_ContinueEntry(item: item, entry: h));
    }
    return entries;
  }
}

class _ContinueEntry {
  final MediaItem item;
  final HistoryEntry entry;
  const _ContinueEntry({required this.item, required this.entry});
}

class _ContinueTile extends StatelessWidget {
  final _ContinueEntry entry;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRemove;

  const _ContinueTile({
    required this.entry,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onLongPress: onLongPress,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PosterCard(item: entry.item, onTap: onTap),
                // On touch screens PosterCard's hover-based × button never
                // shows; we add our own always-visible delete button. In
                // select mode this button is hidden because the selection
                // toggle, not deletion, is the main flow.
                if (!selectMode && onRemove != null)
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
                if (selectMode)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          // PosterCard uses ClipRRect(8) internally; if the
                          // overlay's border-radius does not match it exactly,
                          // a 1-2 px outline leaks at the edge.
                          borderRadius: BorderRadius.circular(8),
                          color: selected
                              ? AppColors.accent.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.25),
                          border: Border.all(
                            color: selected
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.35),
                            width: selected ? 2.5 : 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (selectMode)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.accent
                            : Colors.black.withValues(alpha: 0.55),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          entry.item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: entry.entry.progress,
            minHeight: 4,
            backgroundColor: AppColors.trackUnplayed,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ],
    );
  }
}
