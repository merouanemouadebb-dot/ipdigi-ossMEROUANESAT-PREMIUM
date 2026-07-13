import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/watchlists_provider.dart';
import 'watchlists_page.dart';

/// The "Add to List" sheet - for adding a content item to one or more
/// watchlists. Every existing list shows up as a checkbox; each toggle
/// adds/removes the item. At the top of the same sheet there is a
/// "Create new list" quick-access row.
class AddToWatchlistSheet extends ConsumerWidget {
  final String sourceId;
  final String contentId;
  final String contentName;
  const AddToWatchlistSheet({
    super.key,
    required this.sourceId,
    required this.contentId,
    required this.contentName,
  });

  static Future<void> show(
    BuildContext context, {
    required String sourceId,
    required String contentId,
    required String contentName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToWatchlistSheet(
        sourceId: sourceId,
        contentId: contentId,
        contentName: contentName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(watchlistsProvider);
    final containing =
        ref.watch(watchlistsContainingProvider(contentId)).value ??
            const <String>{};
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: mq.size.height * 0.7,
        ),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
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
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  ref.tr('watchlists.addToList'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  contentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.add_rounded,
                  color: AppColors.accent,
                ),
                title: Text(
                  ref.tr('watchlists.new'),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Future<void>.delayed(
                      const Duration(milliseconds: 80));
                  if (!context.mounted) return;
                  // Open the edit sheet; re-showing the add sheet after
                  // saving is complex, so after the user creates a new list
                  // they tap "Add to List" again - the flow stays clear.
                  WatchlistEditorSheet.show(context, ref);
                },
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: listsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('${ref.tr('common.error')}: $e'),
                  ),
                  data: (lists) {
                    if (lists.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          ref.tr('watchlists.emptyMsg'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: lists.length,
                      itemBuilder: (context, i) {
                        final list = lists[i];
                        final has = containing.contains(list.id);
                        return CheckboxListTile(
                          value: has,
                          activeColor: AppColors.accent,
                          checkColor: Colors.white,
                          controlAffinity:
                              ListTileControlAffinity.leading,
                          title: Text(
                            list.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: list.description != null &&
                                  list.description!.isNotEmpty
                              ? Text(
                                  list.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          onChanged: (next) async {
                            final notifier =
                                ref.read(watchlistsProvider.notifier);
                            if (next == true) {
                              await notifier.addItem(
                                watchlistId: list.id,
                                contentId: contentId,
                                sourceId: sourceId,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ref.tr('watchlists.addedTo',
                                          {'name': list.name}),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              await notifier.removeItem(
                                watchlistId: list.id,
                                contentId: contentId,
                                sourceId: sourceId,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ref.tr('watchlists.removedFrom',
                                          {'name': list.name}),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
