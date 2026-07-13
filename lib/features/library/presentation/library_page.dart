import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../player/presentation/player_page.dart';
import '../../sources/domain/media_item.dart';
import '../../sources/providers/sources_provider.dart';
import '../providers/library_provider.dart';

/// "Favorites" - a poster grid of the movies, series and channels the
/// user has starred. Same tile structure as the Continue Watching page:
/// a touch-friendly × button, long-press multi-select, and bulk clearing
/// via "Clear All" from the AppBar.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
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

  Future<void> _removeOne(MediaItem item) async {
    await ref.read(favoritesProvider.notifier).toggle(item.sourceId, item.id);
  }

  Future<void> _removeSelected(List<MediaItem> all) async {
    if (_selectedKeys.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          ref.tr('library.confirmSelected', {
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
            child: Text(ref.tr('common.remove')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final notifier = ref.read(favoritesProvider.notifier);
    for (final item in all.where((i) => _selectedKeys.contains(i.id))) {
      await notifier.toggle(item.sourceId, item.id);
    }
    if (!mounted) return;
    setState(() {
      _selectedKeys.clear();
      _selectMode = false;
    });
  }

  Future<void> _removeAll(List<MediaItem> all) async {
    if (all.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(ref.tr('library.confirmAll')),
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
    final notifier = ref.read(favoritesProvider.notifier);
    for (final item in all) {
      await notifier.toggle(item.sourceId, item.id);
    }
    if (!mounted) return;
    setState(() {
      _selectedKeys.clear();
      _selectMode = false;
    });
  }

  void _openItem(BuildContext context, MediaItem item) {
    switch (item.kind) {
      case MediaKind.movie:
        context.pushOnce('/movie/${item.sourceId}/${item.streamId}');
        break;
      case MediaKind.series:
        context.pushOnce('/series/${item.sourceId}/${item.streamId}');
        break;
      case MediaKind.live:
        context.pushOnce(
          '/player',
          extra: PlayerArgs(item: item, isLive: true, startAt: Duration.zero),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final allItems = ref.watch(libraryItemsProvider(const LibraryItemsArgs()));

    final favKeys = favorites.value ?? const <String>{};
    final favItems = (allItems.value ?? const <MediaItem>[])
        .where((i) => favKeys.contains(i.id))
        .toList();

    if (_selectMode && favItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectMode && favItems.isEmpty) {
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
              : ref.tr('library.title'),
        ),
        actions: _selectMode
            ? [
                TextButton.icon(
                  onPressed: _selectedKeys.isEmpty
                      ? null
                      : () => _removeSelected(favItems),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _selectedKeys.isEmpty
                        ? ref.tr('common.remove')
                        : '${ref.tr('common.remove')} (${_selectedKeys.length})',
                  ),
                ),
                IconButton(
                  tooltip: ref.tr('common.cancel'),
                  onPressed: _toggleSelectMode,
                  icon: const Icon(Icons.close_rounded),
                ),
              ]
            : [
                IconButton(
                  tooltip: ref.tr('common.clearAll'),
                  onPressed: favItems.isEmpty
                      ? null
                      : () => _removeAll(favItems),
                  icon: const Icon(Icons.delete_sweep_rounded),
                ),
                IconButton(
                  tooltip: ref.tr('continueWatching.select'),
                  onPressed: favItems.isEmpty ? null : _toggleSelectMode,
                  icon: const Icon(Icons.check_box_outlined),
                ),
              ],
      ),
      body: allItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (_) {
          if (favItems.isEmpty) {
            return EmptyStateView(
              icon: Icons.favorite_rounded,
              title: ref.tr('library.empty'),
              message: ref.tr('library.emptyMsg'),
              action: ElevatedButton(
                onPressed: () => context.go('/movies'),
                child: Text(ref.tr('library.discover')),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxExtent = constraints.maxWidth < 600 ? 150.0 : 180.0;
              return GridView.builder(
                padding: const EdgeInsets.all(20),
                cacheExtent: 800,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  childAspectRatio: 2 / 3.3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                ),
                itemCount: favItems.length,
                itemBuilder: (context, i) {
                  final item = favItems[i];
                  final selected = _selectedKeys.contains(item.id);
                  return _FavoriteTile(
                    item: item,
                    selectMode: _selectMode,
                    selected: selected,
                    onTap: () {
                      if (_selectMode) {
                        _toggleItem(item.id);
                      } else {
                        _openItem(context, item);
                      }
                    },
                    onLongPress: _selectMode
                        ? null
                        : () {
                            setState(() {
                              _selectMode = true;
                              _selectedKeys.add(item.id);
                            });
                          },
                    onRemove: _selectMode ? null : () => _removeOne(item),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final MediaItem item;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRemove;

  const _FavoriteTile({
    required this.item,
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
                PosterCard(item: item, onTap: onTap),
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
          item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (item.categoryName != null && item.categoryName!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            item.categoryName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
