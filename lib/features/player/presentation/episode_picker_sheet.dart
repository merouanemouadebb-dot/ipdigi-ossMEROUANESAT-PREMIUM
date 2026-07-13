import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../sources/domain/media_item.dart';
import '../domain/series_queue.dart';

/// Bottom sheet that slides up from the player and lists every episode of
/// the active series. Episodes are grouped by season behind a dropdown in
/// the header (matching the series detail page); the currently-playing
/// episode is highlighted and tapping any row switches the player to it.
class EpisodePickerSheet extends ConsumerStatefulWidget {
  final SeriesQueue queue;
  final void Function(int index) onSelect;
  const EpisodePickerSheet({
    super.key,
    required this.queue,
    required this.onSelect,
  });

  static Future<void> show({
    required BuildContext context,
    required SeriesQueue queue,
    required void Function(int index) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      // Native bottom-sheet transition is ~250ms in Material; that
      // is the "waits too long before the menu opens" the user
      // reported. A custom controller cuts the slide to a tight
      // 90ms which lands well within the "feels instant" budget.
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 80),
        vsync: Navigator.of(context),
      ),
      builder: (_) => EpisodePickerSheet(queue: queue, onSelect: onSelect),
    );
  }

  @override
  ConsumerState<EpisodePickerSheet> createState() => _EpisodePickerSheetState();
}

class _EpisodePickerSheetState extends ConsumerState<EpisodePickerSheet> {
  late int _selectedSeason;
  late final List<int> _seasonKeys;
  late final Map<int, List<int>> _indicesBySeason;

  @override
  void initState() {
    super.initState();
    final eps = widget.queue.episodes;
    // Build {season -> [originalIndex, ...]} so taps can map back to the
    // flat queue position without searching by id every time.
    final map = <int, List<int>>{};
    for (var i = 0; i < eps.length; i++) {
      map.putIfAbsent(eps[i].season, () => <int>[]).add(i);
    }
    _seasonKeys = map.keys.toList()..sort();
    _indicesBySeason = map;
    final currentSeason = eps.isNotEmpty
        ? eps[widget.queue.currentIndex].season
        : (_seasonKeys.isEmpty ? 0 : _seasonKeys.first);
    _selectedSeason = _seasonKeys.contains(currentSeason)
        ? currentSeason
        : _seasonKeys.first;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final indices = _indicesBySeason[_selectedSeason] ?? const <int>[];
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          color: AppColors.background.withValues(alpha: 0.5),
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          ref.tr('player.episodes'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_seasonKeys.length > 1)
                          _SeasonDropdown(
                            seasons: _seasonKeys,
                            selected: _selectedSeason,
                            label: ref.tr('series.season'),
                            onChanged: (v) =>
                                setState(() => _selectedSeason = v),
                          )
                        else if (_seasonKeys.length == 1)
                          Text(
                            '${ref.tr('series.season')} ${_seasonKeys.first}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          tooltip: ref.tr('common.close'),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.queue.seriesName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: indices.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, i) {
                    final flatIndex = indices[i];
                    final ep = widget.queue.episodes[flatIndex];
                    final isCurrent = flatIndex == widget.queue.currentIndex;
                    return _EpisodeRow(
                      seriesPosterUrl: widget.queue.seriesPosterUrl,
                      episode: ep,
                      isCurrent: isCurrent,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (!isCurrent) widget.onSelect(flatIndex);
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

class _SeasonDropdown extends StatelessWidget {
  final List<int> seasons;
  final int selected;
  final String label;
  final ValueChanged<int> onChanged;
  const _SeasonDropdown({
    required this.seasons,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.expand_more_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: seasons
              .map((s) => DropdownMenuItem(value: s, child: Text('$label $s')))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatefulWidget {
  final String? seriesPosterUrl;
  final SeriesEpisode episode;
  final bool isCurrent;
  final VoidCallback onTap;
  const _EpisodeRow({
    required this.seriesPosterUrl,
    required this.episode,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _hover = false;
  bool _focus = false;
  bool get _active => _hover || _focus;

  /// "S1 E4 · Mar 15, 2024 · added Mar 18". Skips the parts we don't
  /// have: when the panel only ships an air date we drop the "added"
  /// half (and vice-versa) so we don't show stray separators.
  String _episodeMeta(SeriesEpisode ep) {
    final parts = <String>['S${ep.season} E${ep.episode}'];
    if (ep.airDate != null && ep.airDate!.isNotEmpty) {
      parts.add(ep.airDate!);
    }
    final added = ep.addedAt;
    if (added != null) {
      final local = added.toLocal();
      final mm = local.month.toString().padLeft(2, '0');
      final dd = local.day.toString().padLeft(2, '0');
      parts.add('eklendi ${local.year}-$mm-$dd');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final thumbUrl = ep.thumbnailUrl ?? widget.seriesPosterUrl;
    final bgColor = widget.isCurrent
        ? AppColors.accent.withValues(alpha: 0.18)
        : (_active ? AppColors.surface : Colors.transparent);
    final titleColor = widget.isCurrent
        ? AppColors.accent
        : AppColors.textPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _focus = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: bgColor,
              border: (_focus && PlatformInfo.isTv)
                  ? Border.all(color: AppColors.accent, width: 3)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${ep.episode}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.isCurrent
                        ? AppColors.accent
                        : AppColors.textTertiary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 110,
                  height: 62,
                  color: AppColors.surfaceElevated,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumbUrl != null)
                        CachedNetworkImage(
                          fadeInDuration: const Duration(milliseconds: 220),
                          fadeOutDuration: const Duration(milliseconds: 80),
                          imageUrl: thumbUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.surfaceElevated),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.surfaceElevated),
                        ),
                      Container(
                        color: Colors.black.withValues(
                          alpha: widget.isCurrent ? 0.25 : (_hover ? 0.3 : 0.5),
                        ),
                      ),
                      Center(
                        child: Icon(
                          widget.isCurrent
                              ? Icons.play_circle_filled_rounded
                              : Icons.play_arrow_rounded,
                          size: widget.isCurrent ? 32 : 28,
                          color: widget.isCurrent
                              ? AppColors.accent
                              : Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ep.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _episodeMeta(ep),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ep.plot != null && ep.plot!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        ep.plot!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
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
    );
  }
}
