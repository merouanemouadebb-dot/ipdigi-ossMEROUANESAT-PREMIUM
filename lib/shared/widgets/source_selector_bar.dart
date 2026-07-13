import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../features/sources/domain/source.dart';
import '../../features/sources/providers/selected_source_provider.dart';
import '../../features/sources/providers/sources_provider.dart';

/// The global source selector shown at the top of the browse pages (just
/// below the hero). If the user has added more than one IPTV source, they
/// pick which one's content to view here; the selection applies across all
/// browse pages and persists (see [selectedSourceProvider]).
///
/// With a single source (or none) it draws nothing ([SizedBox.shrink]) -
/// when there's nothing to pick, the combobox is hidden.
class SourceSelectorBar extends ConsumerWidget {
  final EdgeInsetsGeometry padding;
  const SourceSelectorBar({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 10),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider).value ?? const <IptvSource>[];
    // With a single source there's nothing to pick - hide the combobox entirely.
    if (sources.length < 2) return const SizedBox.shrink();

    // null = "All Sources". If the provider hasn't resolved yet it falls
    // back to null (All), a safe default. The moment a source is deleted
    // the stored id may briefly not be in the list; if the DropdownButton
    // value doesn't match an item it throws an assert - so when it's not
    // in the list we fall back to null (All).
    final raw = ref.watch(selectedSourceProvider).value;
    final selected = (raw != null && sources.any((s) => s.id == raw))
        ? raw
        : null;

    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          // vertical 10: isDense dropdown (24px) + 2*10 = 44px -> iOS HIG
          // minimum touch target.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dns_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              // No isExpanded: the combobox wraps to the selected content
              // (leaves no dead space for a short name). Each item is
              // ellipsized at its own maxWidth, so a long name doesn't overflow.
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selected,
                  isDense: true,
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.surface,
                  icon: const Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: _SourceLabel(ref.tr('sources.allSources')),
                    ),
                    for (final s in sources)
                      DropdownMenuItem<String?>(
                        value: s.id,
                        child: _SourceLabel(s.name),
                      ),
                  ],
                  onChanged: (v) =>
                      ref.read(selectedSourceProvider.notifier).select(v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Combobox item label: prevents long source names from expanding the
/// dropdown without limit; ellipsizes on one line once it exceeds [maxWidth].
class _SourceLabel extends StatelessWidget {
  final String text;
  const _SourceLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
