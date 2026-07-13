import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../domain/source.dart';
import '../providers/sources_provider.dart';

/// Single-row card for one configured IPTV source: name + type chip,
/// truncated connection detail, refresh and delete buttons. Used by both
/// the Settings page (inline Sources section) and the standalone Sources
/// listing route.
class SourceTile extends ConsumerStatefulWidget {
  final IptvSource source;
  const SourceTile({super.key, required this.source});

  @override
  ConsumerState<SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends ConsumerState<SourceTile> {
  bool _refreshing = false;
  bool _deleting = false;

  String get _typeLabel {
    switch (widget.source.kind) {
      case SourceKind.xtream:
        return 'Xtream';
      case SourceKind.m3u:
        return 'M3U';
      case SourceKind.direct:
        return 'Direct';
    }
  }

  String get _detail {
    switch (widget.source) {
      case XtreamSource(:final url, :final username):
        return '$url • $username';
      case M3uSource(:final urlOrPath):
        return urlOrPath;
      case DirectUrlSource(:final url):
        return url;
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    final startedAt = DateTime.now();
    try {
      await ref.read(sourcesProvider.notifier).refreshSource(widget.source);
      if (!mounted) return;
      final elapsed = DateTime.now().difference(startedAt);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ref.tr('sources.refreshOk', {
                    'name': widget.source.name,
                    'secs':
                        '${elapsed.inSeconds}.${(elapsed.inMilliseconds % 1000) ~/ 100}',
                  }),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] refresh tile error: $e\n$st');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ref.tr('sources.refreshFailed', {'error': '$e'}),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          ref.tr('sources.deleteTitle'),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          ref.tr('sources.deleteConfirm', {'name': widget.source.name}),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(ref.tr('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(ref.tr('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sourcesProvider.notifier).removeSource(widget.source.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            ref.tr('sources.removed', {'name': widget.source.name}),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ref.tr('sources.deleteFailed', {'error': '$e'}),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _lastUpdatedLabel() {
    final async = ref.watch(sourceLastUpdatedProvider(widget.source.id));
    final dt = async.value;
    if (dt == null) {
      return ref.tr('sources.lastUpdatedNever');
    }
    return ref.tr('sources.lastUpdated', {'date': formatLocalDateTime(dt)});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _deleting ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.live_tv_rounded, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.source.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _typeLabel,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _lastUpdatedLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (_refreshing)
              const SizedBox(
                width: 32,
                height: 32,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.accent,
                  ),
                ),
              )
            else
              IconButton(
                tooltip: ref.tr('common.refresh'),
                onPressed: _refreshing || _deleting ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            IconButton(
              tooltip: ref.tr('common.delete'),
              onPressed: _refreshing || _deleting ? null : _confirmDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
