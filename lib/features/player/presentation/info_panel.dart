import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/metadata/tmdb_overrides_provider.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../epg/domain/epg_program.dart';
import '../../epg/providers/epg_provider.dart';
import '../../sources/domain/media_item.dart';
import '../domain/series_queue.dart';
import '../providers/info_detail_provider.dart';

/// Extracts the year from "2023-04-15", "2023-04", "2023" variants.
/// Returns null for invalid / non-4-digit inputs.
int? _yearFromDate(String? raw) {
  if (raw == null || raw.length < 4) return null;
  final y = int.tryParse(raw.substring(0, 4));
  if (y == null || y < 1800 || y > 2100) return null;
  return y;
}

/// Converts a `Duration` to an hourless `hh:mm` or a shortened `mm`
/// format; seconds are not shown. The user wanted a plain duration like
/// "01:34" in the info panel - since the existing `formatDuration` adds
/// ":ss", this is a separate helper.
String _formatHm(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final mm = m.toString().padLeft(2, '0');
  if (h > 0) {
    final hh = h.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  return mm;
}

/// Shared Text builder for the single-line meta labels in the info panel.
/// When `bold` is true it bumps the weight for standout values like rating.
Widget _metaText(String text, {bool bold = false}) {
  return Text(
    text,
    style: TextStyle(
      color: bold ? Colors.white : AppColors.textSecondary,
      fontSize: 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    ),
  );
}

/// Dot separator between fields in the meta row - a centered, faint `·`
/// like the one in the detail page hero.
Widget _metaSeparator() {
  return const Text(
    '·',
    style: TextStyle(
      color: AppColors.textTertiary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}

class InfoPanel extends ConsumerWidget {
  final MediaItem playingItem;
  final SeriesQueue? seriesQueue;
  final VoidCallback onClose;

  const InfoPanel({
    super.key,
    required this.playingItem,
    required this.onClose,
    this.seriesQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLive = playingItem.kind == MediaKind.live && seriesQueue == null;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: AppColors.background.withValues(alpha: 0.5),
          elevation: 24,
          child: SizedBox(
            width: 380,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ref.tr('player.infoPanelTitle'),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: isLive
                        ? _LiveEpgContent(item: playingItem)
                        : _VodContent(
                            playingItem: playingItem,
                            seriesQueue: seriesQueue,
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

class _VodContent extends ConsumerWidget {
  final MediaItem playingItem;
  final SeriesQueue? seriesQueue;
  const _VodContent({required this.playingItem, this.seriesQueue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = seriesQueue != null
        ? InfoDetailArgs(
            sourceId: seriesQueue!.seriesSourceId,
            streamId: seriesQueue!.seriesId,
            kind: MediaKind.series,
          )
        : InfoDetailArgs(
            sourceId: playingItem.sourceId,
            streamId: playingItem.streamId,
            kind: playingItem.kind,
          );
    final detailAsync = ref.watch(infoDetailProvider(args));
    return detailAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${ref.tr('common.error')}: $e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (info) {
        if (info == null) return _basicInfo(playingItem);
        return _InfoContent(info: info, seriesQueue: seriesQueue);
      },
    );
  }

  Widget _basicInfo(MediaItem item) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.plot != null) ...[
            const SizedBox(height: 12),
            Text(
              item.plot!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoContent extends ConsumerWidget {
  final InfoDetail info;
  final SeriesQueue? seriesQueue;
  const _InfoContent({required this.info, this.seriesQueue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = info.item;
    // The info panel merges the IPTV detail + TMDB enrichment. Otherwise
    // if the panel leaves the "country" field empty, the user sees the
    // country label in the film detail on the right, but the same info
    // disappeared during playback.
    final tmdb = ref
        .watch(tmdbDetailProvider(TmdbLookupArgs.fromItem(item)))
        .value;
    final hasOverride = ref
            .watch(tmdbOverridesProvider)
            .value
            ?.containsKey(item.id) ??
        false;
    final base = info.detail ?? const MediaDetail();
    final detail = (info.detail == null && tmdb == null)
        ? null
        : mergeWithTmdb(base, tmdb, preferTmdb: hasOverride);
    final cover = detail?.coverUrl ?? item.logoUrl;
    final backdrop = detail?.backdropUrl ?? item.backdropUrl ?? cover;
    final rating = detail?.rating ?? item.rating;
    final plot = detail?.plot ?? item.plot;
    final episode = seriesQueue?.current;
    final year = item.year ?? _yearFromDate(detail?.releaseDate);
    final country = detail?.country;
    // The title prefers TMDB's localized name; otherwise the panel name.
    // If the original title (usually English) differs, it's shown faintly
    // alongside - e.g. "Kara Kule  The Dark Tower".
    final localizedTitle = (tmdb?.title?.trim().isNotEmpty ?? false)
        ? tmdb!.title!
        : (seriesQueue?.seriesName ?? item.name);
    final originalTitle = tmdb?.originalTitle?.trim();
    final showOriginal = originalTitle != null &&
        originalTitle.isNotEmpty &&
        originalTitle.toLowerCase() != localizedTitle.toLowerCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: [
        if (backdrop != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                fadeInDuration: const Duration(milliseconds: 220),
                fadeOutDuration: const Duration(milliseconds: 80),
                imageUrl: backdrop,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.surface),
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.surface),
              ),
            ),
          ),
        const SizedBox(height: 14),
        // Row 1: NAME (YEAR). The year sits next to the title in faint
        // gray parentheses - symmetric with the detail page hero title.
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: localizedTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              if (year != null)
                TextSpan(
                  text: '  ($year)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
        // Row 2: ORIGINAL_NAME, italic gray - if present.
        if (showOriginal) ...[
          const SizedBox(height: 2),
          Text(
            originalTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 8),
        // Row 3: ⭐ {rating} · {runtime hh:mm} · {country} - the same
        // language as the hero on the detail page. The star icon is right
        // next to the rating; the fields that follow are separated by the
        // dot separator. Missing fields are skipped, and so the separator
        // naturally isn't placed either.
        Builder(
          builder: (_) {
            final children = <Widget>[];
            void addSeparator() {
              if (children.isNotEmpty) {
                children.add(_metaSeparator());
              }
            }

            if (rating != null) {
              children.add(const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star_rounded,
                    color: Colors.amber, size: 18),
              ));
              children.add(_metaText(
                rating.toStringAsFixed(1),
                bold: true,
              ));
            }
            if (detail?.runtimeSeconds != null &&
                detail!.runtimeSeconds! > 0) {
              addSeparator();
              children.add(_metaText(
                  _formatHm(Duration(seconds: detail.runtimeSeconds!))));
            }
            if (country != null) {
              addSeparator();
              children.add(_metaText(country));
            }
            return Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children,
            );
          },
        ),
        if (item.categoryName != null) ...[
          const SizedBox(height: 6),
          Text(
            item.categoryName!,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
        if (episode != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'S${episode.season}E${episode.episode} • ${episode.title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (episode.plot != null && episode.plot!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    episode.plot!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (plot != null && plot.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            plot,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
        if (detail != null) ...[
          if (detail.genres.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TagSection(
              label: ref.tr('detail.genres'),
              values: detail.genres,
              tagType: 'genre',
            ),
          ],
          if (detail.cast.isNotEmpty) ...[
            const SizedBox(height: 14),
            _TagSection(
              label: ref.tr('detail.cast'),
              values: detail.cast,
              tagType: 'cast',
            ),
          ],
          if (detail.directors.isNotEmpty) ...[
            const SizedBox(height: 14),
            _TagSection(
              label: ref.tr('detail.director'),
              values: detail.directors,
              tagType: 'dir',
            ),
          ],
          // The year is now shown next to the title (faint (YYYY)); the
          // "Production Year" row below was a duplicate - removed.
        ],
      ],
    );
  }
}

class _TagSection extends StatelessWidget {
  final String label;
  final List<String> values;
  final String tagType;
  const _TagSection({
    required this.label,
    required this.values,
    required this.tagType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10.5,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values
              .map((v) => _Chip(label: v, tagType: tagType))
              .toList(),
        ),
      ],
    );
  }
}

class _Chip extends ConsumerStatefulWidget {
  final String label;
  final String tagType;
  const _Chip({required this.label, required this.tagType});

  @override
  ConsumerState<_Chip> createState() => _ChipState();
}

class _ChipState extends ConsumerState<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // If a CJK / non-Latin name shows up in the cast section, pull a
    // Latin alias from TMDB and show that - so the user can read actor
    // names even during playback.
    final displayLabel = widget.tagType == 'cast'
        ? (ref.watch(latinizedNameProvider(widget.label)).value ?? widget.label)
        : widget.label;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          if (widget.tagType == 'cast') {
            context.pushOnce('/person/${Uri.encodeComponent(displayLabel)}');
          } else {
            context.pushOnce(
              '/tag/${widget.tagType}/${Uri.encodeComponent(widget.label)}',
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _hover ? AppColors.accent : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            displayLabel,
            style: TextStyle(
              color: _hover ? Colors.white : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Live-channel companion to [_InfoContent]. Resolves the current and
/// upcoming programmes from the EPG snapshot, ticks every minute so
/// progress stays correct without burning a per-second frame, and
/// falls back to a "no schedule" message when the panel does not
/// ship EPG data for this channel.
class _LiveEpgContent extends ConsumerStatefulWidget {
  final MediaItem item;
  const _LiveEpgContent({required this.item});

  @override
  ConsumerState<_LiveEpgContent> createState() => _LiveEpgContentState();
}

class _LiveEpgContentState extends ConsumerState<_LiveEpgContent> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Align the first tick to the next wall-clock minute so the "now
    // playing" card and tile across the app flip in unison.
    final n = DateTime.now();
    Future.delayed(Duration(seconds: 60 - n.second), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cid = item.epgChannelId ?? item.streamId;
    final snap = ref.watch(epgProvider).value;
    final isLoading = ref.watch(epgProvider).isLoading;
    final now = snap?.nowPlaying(item.sourceId, cid, _now);
    final dayEnd = DateTime(
      _now.year,
      _now.month,
      _now.day,
    ).add(const Duration(days: 1));
    final schedule =
        snap?.rangeFor(
          sourceId: item.sourceId,
          channelId: cid,
          from: _now,
          to: dayEnd,
        ) ??
        const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: [
        Row(
          children: [
            if (item.logoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CachedNetworkImage(
                    fadeInDuration: const Duration(milliseconds: 220),
                    imageUrl: item.logoUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => Container(color: AppColors.surface),
                    errorWidget: (_, _, _) =>
                        Container(color: AppColors.surface),
                  ),
                ),
              ),
            if (item.logoUrl != null) const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (now != null) ...[
          _NowCard(program: now, now: _now),
          const SizedBox(height: 18),
        ] else if (isLoading) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
        ] else ...[
          _EpgEmptyHint(),
          const SizedBox(height: 12),
        ],
        if (schedule.length > 1) ...[
          Text(
            ref.tr('live.upNext').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in schedule.where((p) => p.start.isAfter(_now)).take(6))
            _UpcomingRow(program: p),
        ],
      ],
    );
  }
}

class _NowCard extends ConsumerWidget {
  final EpgProgram program;
  final DateTime now;
  const _NowCard({required this.program, required this.now});

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = program.stop.difference(now);
    final remLabel = remaining.inMinutes > 0
        ? ref.tr('live.remainingM', {'m': '${remaining.inMinutes}'})
        : ref.tr('live.endingNow');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ref.tr('live.now').toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_hm(program.start)} – ${_hm(program.stop)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            program.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: program.progressAt(now),
              minHeight: 3,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            remLabel,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (program.description != null) ...[
            const SizedBox(height: 10),
            Text(
              program.description!,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final EpgProgram program;
  const _UpcomingRow({required this.program});

  String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _hm(program.start),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (program.description != null &&
                    program.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    program.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpgEmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Bu kanal için yayın akışı bilgisi bulunamadı. '
        'Sağlayıcı XMLTV vermiyor olabilir.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12.5,
          height: 1.45,
        ),
      ),
    );
  }
}
