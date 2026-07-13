import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/widgets/dpad_text_field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../shared/widgets/error_dialog.dart';
import '../../../shared/widgets/skeleton.dart';
import '../providers/watchlists_provider.dart';

/// Watchlists listing page. A CTA when empty; when populated each card
/// is a list; from a card you reach its contents or the edit/delete
/// menu. Ordering is position+createdAt on the provider side.
class WatchlistsPage extends ConsumerWidget {
  const WatchlistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(watchlistsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ref.tr('watchlists.title')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => WatchlistEditorSheet.show(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(ref.tr('watchlists.new')),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${ref.tr('common.error')}: $e')),
        data: (lists) {
          if (lists.isEmpty) {
            return EmptyStateView(
              icon: Icons.playlist_play_rounded,
              title: ref.tr('watchlists.empty'),
              message: ref.tr('watchlists.emptyMsg'),
              action: ElevatedButton.icon(
                onPressed: () => WatchlistEditorSheet.show(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: Text(ref.tr('watchlists.new')),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: lists.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final list = lists[i];
              return _WatchlistCard(list: list);
            },
          );
        },
      ),
    );
  }
}

class _WatchlistCard extends ConsumerStatefulWidget {
  final Watchlist list;
  const _WatchlistCard({required this.list});

  @override
  ConsumerState<_WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends ConsumerState<_WatchlistCard> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final items = ref
        .watch(watchlistItemsProvider(WatchlistItemsArgs(list.id)))
        .value;
    final count = items?.length ?? 0;
    return Focus(
      onFocusChange: (v) => setState(() => _focus = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          context.pushOnce('/watchlists/${list.id}');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: _focus ? AppColors.surfaceElevated : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: (_focus && PlatformInfo.isTv)
              ? const BorderSide(color: AppColors.accent, width: 3)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.pushOnce('/watchlists/${list.id}'),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.playlist_play_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (list.description != null &&
                        list.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        list.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      count == 1
                          ? ref.tr('watchlists.itemCountOne')
                          : ref.tr('watchlists.itemCount', {
                              'n': count.toString(),
                            }),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textTertiary,
                ),
                color: AppColors.surfaceElevated,
                onSelected: (v) async {
                  if (v == 'edit') {
                    WatchlistEditorSheet.show(context, ref, existing: list);
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      useRootNavigator: true,
                      builder: (dialogCtx) => AlertDialog(
                        title: Text(ref.tr('watchlists.delete')),
                        content: Text(
                          ref.tr('watchlists.deleteConfirm', {
                            'name': list.name,
                          }),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(
                              dialogCtx,
                              rootNavigator: true,
                            ).pop(false),
                            child: Text(ref.tr('common.cancel')),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            onPressed: () => Navigator.of(
                              dialogCtx,
                              rootNavigator: true,
                            ).pop(true),
                            child: Text(ref.tr('common.delete')),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    try {
                      await ref
                          .read(watchlistsProvider.notifier)
                          .delete(list.id);
                    } catch (e, st) {
                      // ignore: avoid_print
                      print('[Watchlist] delete hata: $e\n$st');
                      if (!context.mounted) return;
                      await showErrorDialog(
                        context,
                        source: 'Watchlist delete',
                        error: e,
                        stack: st,
                      );
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded, size: 18),
                        const SizedBox(width: 10),
                        Text(ref.tr('watchlists.edit')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          ref.tr('watchlists.delete'),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// Sheet to create a new list / edit an existing list.
class WatchlistEditorSheet extends ConsumerStatefulWidget {
  final Watchlist? existing;
  const WatchlistEditorSheet({super.key, this.existing});

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    Watchlist? existing,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchlistEditorSheet(existing: existing),
    );
  }

  @override
  ConsumerState<WatchlistEditorSheet> createState() =>
      _WatchlistEditorSheetState();
}

class _WatchlistEditorSheetState extends ConsumerState<WatchlistEditorSheet> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _descCtl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtl =
        TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    if (widget.existing == null) {
      await ref
          .read(watchlistsProvider.notifier)
          .create(name: name, description: _descCtl.text);
    } else {
      await ref.read(watchlistsProvider.notifier).updateList(
            id: widget.existing!.id,
            name: name,
            description: _descCtl.text,
          );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Text(
                editing
                    ? ref.tr('watchlists.edit')
                    : ref.tr('watchlists.new'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              DpadTextField(
                child: TextField(
                controller: _nameCtl,
                maxLength: 80,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: ref.tr('watchlists.name'),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  counterStyle:
                      const TextStyle(color: AppColors.textTertiary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              ),
              const SizedBox(height: 10),
              DpadTextField(
                child: TextField(
                controller: _descCtl,
                maxLength: 240,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: ref.tr('watchlists.description'),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  counterStyle:
                      const TextStyle(color: AppColors.textTertiary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving || _nameCtl.text.trim().isEmpty
                    ? null
                    : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  editing
                      ? ref.tr('watchlists.save')
                      : ref.tr('watchlists.create'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
