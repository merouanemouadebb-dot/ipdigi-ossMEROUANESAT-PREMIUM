import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../epg/domain/epg_program.dart';
import '../../epg/providers/epg_provider.dart';
import '../../sources/domain/media_item.dart';

/// The home page's live channels row. The RowCarousel + PosterCard combo
/// looked weak for channels (it squeezed channel logos into a portrait
/// poster frame). Here each card is a tile in the category palette:
/// channel logo top-left, current program (if EPG is available) in the
/// middle, live progress bar at the bottom.
class LiveChannelsRow extends ConsumerWidget {
  final List<MediaItem> channels;
  final void Function(MediaItem) onTap;
  final String? title;
  const LiveChannelsRow({
    super.key,
    required this.channels,
    required this.onTap,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (channels.isEmpty) return const SizedBox.shrink();
    final epg = ref.watch(epgProvider).value;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              title ?? ref.tr('home.liveChannels'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(
            height: 166,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              clipBehavior: Clip.none,
              itemCount: channels.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final c = channels[i];
                final cid = c.epgChannelId ?? c.streamId;
                final program = epg?.nowPlaying(c.sourceId, cid, now);
                return _LiveTile(
                  channel: c,
                  program: program,
                  now: now,
                  onTap: () => onTap(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTile extends ConsumerStatefulWidget {
  final MediaItem channel;
  final EpgProgram? program;
  final DateTime now;
  final VoidCallback onTap;
  const _LiveTile({
    required this.channel,
    required this.program,
    required this.now,
    required this.onTap,
  });

  @override
  ConsumerState<_LiveTile> createState() => _LiveTileState();
}

class _LiveTileState extends ConsumerState<_LiveTile> {
  bool _hover = false;

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Color _palette(String? name) {
    if (name == null) return AppColors.surfaceElevated;
    final low = name.toLowerCase();
    if (low.contains('spor') || low.contains('sport'))
      return const Color(0xFF1F4A3F);
    if (low.contains('haber') || low.contains('news'))
      return const Color(0xFF1F344A);
    if (low.contains('film') ||
        low.contains('cinema') ||
        low.contains('movie')) {
      return const Color(0xFF3D2A4A);
    }
    if (low.contains('belgesel') || low.contains('document'))
      return const Color(0xFF3D331F);
    if (low.contains('çocuk') ||
        low.contains('cocuk') ||
        low.contains('kids') ||
        low.contains('cartoon'))
      return const Color(0xFF4A2A38);
    if (low.contains('müzik') ||
        low.contains('muzik') ||
        low.contains('music')) {
      return const Color(0xFF3F1F4A);
    }
    return AppColors.surfaceElevated;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    final p = widget.program;
    final palette = _palette(c.categoryName);
    final title = p?.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    final progress = p?.progressAt(widget.now) ?? 0.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // Border color does not change on hover (user request).
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: palette),
                  if (c.logoUrl != null)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.16,
                        child: CachedNetworkImage(
                          imageUrl: c.logoUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          placeholder: (_, _) => const SizedBox.shrink(),
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.background.withValues(alpha: 0.88),
                          AppColors.background.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  // Channel logo top-left (32x32)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: c.logoUrl == null
                          ? const Icon(
                              Icons.tv_rounded,
                              size: 18,
                              color: AppColors.textTertiary,
                            )
                          : CachedNetworkImage(
                              imageUrl: c.logoUrl!,
                              fit: BoxFit.contain,
                              placeholder: (_, _) => const SizedBox.shrink(),
                              errorWidget: (_, _, _) => const Icon(
                                Icons.tv_rounded,
                                size: 18,
                                color: AppColors.textTertiary,
                              ),
                            ),
                    ),
                  ),
                  // LIVE badge top-right
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ref.tr('live.badge'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Bottom: channel name + program name + progress
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title ?? c.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        if (p != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${_hm(p.start)} – ${_hm(p.stop)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(1.5),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2,
                              backgroundColor: AppColors.surfaceElevated
                                  .withValues(alpha: 0.6),
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
