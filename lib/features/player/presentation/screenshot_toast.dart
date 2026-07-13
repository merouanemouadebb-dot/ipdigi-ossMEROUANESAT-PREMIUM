import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';

class ScreenshotToastData {
  final String fileName;
  final String? dirPath;
  final bool isError;
  const ScreenshotToastData({
    required this.fileName,
    this.dirPath,
    this.isError = false,
  });
}

/// Floating toast in the top-right corner of the player. Auto-dismisses
/// after [autoDismiss], and has an X button for manual close. Lives inside
/// the player Stack as a Positioned widget - visible regardless of the
/// controls overlay state.
class ScreenshotToast extends ConsumerStatefulWidget {
  final ScreenshotToastData? data;
  final VoidCallback onDismiss;
  final Duration autoDismiss;
  const ScreenshotToast({
    super.key,
    required this.data,
    required this.onDismiss,
    this.autoDismiss = const Duration(seconds: 4),
  });

  @override
  ConsumerState<ScreenshotToast> createState() => _ScreenshotToastState();
}

class _ScreenshotToastState extends ConsumerState<ScreenshotToast> {
  Timer? _timer;
  String? _lastShownFile;

  @override
  void didUpdateWidget(covariant ScreenshotToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    final d = widget.data;
    if (d != null && d.fileName != _lastShownFile) {
      _lastShownFile = d.fileName;
      _timer?.cancel();
      _timer = Timer(widget.autoDismiss, () {
        if (mounted) widget.onDismiss();
      });
    }
    if (d == null) {
      _timer?.cancel();
      _lastShownFile = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.2, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: d == null
          ? const SizedBox.shrink()
          : _ToastCard(
              key: ValueKey(d.fileName),
              data: d,
              onDismiss: widget.onDismiss,
            ),
    );
  }
}

class _ToastCard extends ConsumerWidget {
  final ScreenshotToastData data;
  final VoidCallback onDismiss;
  const _ToastCard({super.key, required this.data, required this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              data.isError
                  ? Icons.error_outline_rounded
                  : Icons.photo_camera_rounded,
              color: data.isError ? Colors.redAccent : AppColors.accent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.isError
                        ? ref.tr('player.captureFailed')
                        : ref.tr('player.captureSaved'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (!data.isError) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    if (data.dirPath != null) ...[
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () {
                          try {
                            Process.run('open', [data.dirPath!]);
                          } catch (_) {}
                        },
                        child: Text(
                          ref.tr('player.openFolder'),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: ref.tr('player.dismiss'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 16,
              iconSize: 16,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
