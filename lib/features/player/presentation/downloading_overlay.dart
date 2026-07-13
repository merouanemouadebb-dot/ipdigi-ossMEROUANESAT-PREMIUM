import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../sources/domain/media_item.dart';
import 'download_toast.dart';

/// A waiting screen that fully covers the video area during the download.
/// The movie's backdrop is blurred in the background, the poster (sharp)
/// sits center-left, with progress info + a cancel button on the right.
class DownloadingOverlay extends ConsumerWidget {
  final MediaItem item;
  final DownloadToastData? toast;
  final VoidCallback onCancel;
  const DownloadingOverlay({
    super.key,
    required this.item,
    required this.toast,
    required this.onCancel,
  });

  String? get _backdropUrl => item.backdropUrl ?? item.logoUrl;
  String? get _posterUrl => item.logoUrl ?? item.backdropUrl;

  String _formatBytes(num bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  String _formatSpeed(double bps) => '${_formatBytes(bps)}/s';

  String _formatEta(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '$h sa $m dk';
    }
    if (d.inMinutes >= 1) {
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60);
      return '$m dk $s sn';
    }
    return '${d.inSeconds} sn';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backdrop = _backdropUrl;
    final poster = _posterUrl;
    final t = toast;
    final fraction = t?.fraction;
    final received = t?.received ?? 0;
    final total = t?.total;
    final bps = t?.bytesPerSecond;
    final Duration? eta = (bps != null && bps > 1 && total != null)
        ? Duration(seconds: ((total - received) / bps).round())
        : null;

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred backdrop background.
          if (backdrop != null && backdrop.isNotEmpty)
            CachedNetworkImage(
              imageUrl: backdrop,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.black),
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
          // Main content - poster + info in the center.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (poster != null && poster.isNotEmpty)
                      _Poster(url: poster),
                    if (poster != null && poster.isNotEmpty)
                      const SizedBox(width: 32),
                    Flexible(
                      child: _InfoColumn(
                        title: item.displayName,
                        waitMessage: ref.tr('player.downloadWaitMessage'),
                        cancelLabel: ref.tr('player.cancelDownload'),
                        fraction: fraction,
                        received: received,
                        total: total,
                        speedLabel: bps != null && bps > 1
                            ? _formatSpeed(bps)
                            : null,
                        etaLabel: eta != null ? _formatEta(eta) : null,
                        formatBytes: _formatBytes,
                        onCancel: onCancel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  final String url;
  const _Poster({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 220,
        height: 330,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.white10),
          errorWidget: (_, __, ___) => Container(
            color: Colors.white12,
            child: const Icon(
              Icons.movie_rounded,
              color: Colors.white24,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoColumn extends ConsumerWidget {
  final String title;
  final String waitMessage;
  final String cancelLabel;
  final double? fraction;
  final int received;
  final int? total;
  final String? speedLabel;
  final String? etaLabel;
  final String Function(num) formatBytes;
  final VoidCallback onCancel;
  const _InfoColumn({
    required this.title,
    required this.waitMessage,
    required this.cancelLabel,
    required this.fraction,
    required this.received,
    required this.total,
    required this.speedLabel,
    required this.etaLabel,
    required this.formatBytes,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          waitMessage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
        const SizedBox(height: 10),
        DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                total != null
                    ? '${formatBytes(received)} / ${formatBytes(total!)}'
                          '${fraction != null ? '   •   ${(fraction! * 100).toStringAsFixed(1)}%' : ''}'
                    : formatBytes(received),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (speedLabel != null) ...[
                    const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white54,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(speedLabel!),
                  ],
                  if (speedLabel != null && etaLabel != null) ...[
                    const SizedBox(width: 14),
                    Container(width: 1, height: 12, color: Colors.white24),
                    const SizedBox(width: 14),
                  ],
                  if (etaLabel != null) ...[
                    const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white54,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(ref.tr('common.timeLeft', {'value': etaLabel!})),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.stop_rounded, color: Colors.white),
          label: Text(cancelLabel, style: const TextStyle(color: Colors.white)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
