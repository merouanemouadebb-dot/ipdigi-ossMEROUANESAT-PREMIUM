import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';

enum DownloadToastState { progress, success, error, cancelled, unsupported }

class DownloadToastData {
  final DownloadToastState state;
  final String? fileName;
  final String? dirPath;
  final String? filePath;

  /// 0.0 – 1.0. `null` -> indeterminate (if the server sends no Content-Length).
  final double? fraction;
  final int received;
  final int? total;

  /// Instantaneous download speed (bytes/sec). Populated only in the progress state.
  final double? bytesPerSecond;

  /// Description returned by the server on error (e.g. "HTTP 403 • connectionError").
  final String? detail;
  const DownloadToastData({
    required this.state,
    this.fileName,
    this.dirPath,
    this.filePath,
    this.fraction,
    this.received = 0,
    this.total,
    this.bytesPerSecond,
    this.detail,
  });
}

/// Download toast that appears in the top-right corner. Stays put while the
/// download is running; after completion / error / cancellation it auto-closes shortly.
class DownloadToast extends ConsumerStatefulWidget {
  final DownloadToastData? data;
  final VoidCallback onDismiss;
  final VoidCallback? onCancel;
  final Duration autoDismiss;
  const DownloadToast({
    super.key,
    required this.data,
    required this.onDismiss,
    this.onCancel,
    this.autoDismiss = const Duration(seconds: 5),
  });

  @override
  ConsumerState<DownloadToast> createState() => _DownloadToastState();
}

class _DownloadToastState extends ConsumerState<DownloadToast> {
  Timer? _timer;
  DownloadToastState? _lastTerminalState;

  void _scheduleDismiss() {
    _timer?.cancel();
    _timer = Timer(widget.autoDismiss, () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void didUpdateWidget(covariant DownloadToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    final d = widget.data;
    if (d == null) {
      _timer?.cancel();
      _lastTerminalState = null;
      return;
    }
    if (d.state == DownloadToastState.progress) {
      _timer?.cancel();
      _lastTerminalState = null;
      return;
    }
    if (d.state != _lastTerminalState) {
      _lastTerminalState = d.state;
      _scheduleDismiss();
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
              key: ValueKey('${d.state.name}-${d.fileName ?? ''}'),
              data: d,
              onDismiss: widget.onDismiss,
              onCancel: widget.onCancel,
            ),
    );
  }
}

class _ToastCard extends ConsumerWidget {
  final DownloadToastData data;
  final VoidCallback onDismiss;
  final VoidCallback? onCancel;
  const _ToastCard({
    super.key,
    required this.data,
    required this.onDismiss,
    this.onCancel,
  });

  IconData _icon() {
    switch (data.state) {
      case DownloadToastState.progress:
        return Icons.download_rounded;
      case DownloadToastState.success:
        return Icons.check_circle_rounded;
      case DownloadToastState.cancelled:
        return Icons.cancel_outlined;
      case DownloadToastState.error:
      case DownloadToastState.unsupported:
        return Icons.error_outline_rounded;
    }
  }

  Color _iconColor() {
    switch (data.state) {
      case DownloadToastState.progress:
      case DownloadToastState.success:
        return AppColors.accent;
      case DownloadToastState.cancelled:
        return Colors.white70;
      case DownloadToastState.error:
      case DownloadToastState.unsupported:
        return Colors.redAccent;
    }
  }

  String _title(WidgetRef ref) {
    switch (data.state) {
      case DownloadToastState.progress:
        return ref.tr('player.downloadInProgress');
      case DownloadToastState.success:
        return ref.tr('player.downloadSaved');
      case DownloadToastState.cancelled:
        return ref.tr('player.downloadCancelled');
      case DownloadToastState.error:
        return ref.tr('player.downloadFailed');
      case DownloadToastState.unsupported:
        return ref.tr('player.downloadUnsupported');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProgress = data.state == DownloadToastState.progress;
    final isSuccess = data.state == DownloadToastState.success;
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
            Icon(_icon(), color: _iconColor(), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title(ref),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (isProgress) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: data.fraction,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.total != null
                          ? '${_formatBytes(data.received)} / ${_formatBytes(data.total!)}'
                                '${data.fraction != null ? '  •  ${(data.fraction! * 100).toStringAsFixed(0)}%' : ''}'
                          : _formatBytes(data.received),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (data.state == DownloadToastState.error &&
                      data.detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (isSuccess && data.fileName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    if (data.filePath != null || data.dirPath != null) ...[
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () {
                          try {
                            // -R reveals the file selected in Finder; if that
                            // fails, fall back to the raw folder.
                            if (data.filePath != null) {
                              Process.run('open', ['-R', data.filePath!]);
                            } else {
                              Process.run('open', [data.dirPath!]);
                            }
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
            if (isProgress && onCancel != null)
              IconButton(
                tooltip: ref.tr('player.cancelDownload'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
                iconSize: 16,
                icon: const Icon(Icons.stop_rounded, color: Colors.white70),
                onPressed: onCancel,
              )
            else
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
