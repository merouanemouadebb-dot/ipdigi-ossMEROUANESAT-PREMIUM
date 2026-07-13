import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/sources_provider.dart';
import 'source_tile.dart';

/// Standalone Sources page kept around as the parent route for
/// `/sources/add` and `/sources/subtitle-style`. The primary entry point
/// for sources is now the Settings page; this listing is only reached
/// when someone deep-links to `/sources`.
class SourcesListPage extends ConsumerWidget {
  const SourcesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('sources.title')),
        actions: [
          IconButton(
            tooltip: ref.tr('sources.add'),
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/sources/add'),
          ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '${ref.tr('common.error')}: $e',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.dns_rounded,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ref.tr('sources.empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ref.tr('sources.emptyMsg'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/sources/add'),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(ref.tr('sources.add')),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SourceTile(source: list[i]),
            ),
          );
        },
      ),
    );
  }
}
