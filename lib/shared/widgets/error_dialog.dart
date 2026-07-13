import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/i18n.dart';
import '../../core/theme/app_theme.dart';

/// Modal error box. A SnackBar appears at the bottom and disappears after
/// 6s, and in some edge cases (if the parent Scaffold goes dark) never
/// shows at all. This helper shows the error dead-center with an
/// AlertDialog, stack trace included; the user can copy and report it.
Future<void> _showErrorDialog(
  BuildContext context,
  String source,
  Object error,
  StackTrace? stack,
) async {
  final fullText = stack == null ? '$error' : '$error\n\n$stack';
  final tr = ProviderScope.containerOf(context, listen: false)
      .read(translationsProvider);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr.t('common.errorTitle', {'source': source}),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 360),
        child: SingleChildScrollView(
          child: SelectableText(
            fullText,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: fullText));
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: Text(tr.t('common.copy')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr.t('common.ok')),
        ),
      ],
    ),
  );
}

/// Public alias - so callers can use the private function.
Future<void> showErrorDialog(
  BuildContext context, {
  required String source,
  required Object error,
  StackTrace? stack,
}) =>
    _showErrorDialog(context, source, error, stack);
