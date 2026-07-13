import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/quality_provider.dart';
import '../providers/subtitle_settings_provider.dart';
import '../providers/track_prefs_provider.dart';
import '../providers/video_zoom_provider.dart';

enum _Section { audio, subtitle, quality, zoom, style, speed }

class PlayerSettingsPanel extends ConsumerStatefulWidget {
  final Player player;
  final VoidCallback onClose;
  const PlayerSettingsPanel({
    super.key,
    required this.player,
    required this.onClose,
  });

  @override
  ConsumerState<PlayerSettingsPanel> createState() =>
      _PlayerSettingsPanelState();
}

class _PlayerSettingsPanelState extends ConsumerState<PlayerSettingsPanel> {
  _Section _section = _Section.audio;

  @override
  Widget build(BuildContext context) {
    // Sagdan tam boy cekmece (drawer). Genislik ekrana gore: telefonda
    // dar (%86), genis ekranda 400. Yukseklik AnimatedPositioned
    // tarafindan (top:0/bottom:0) verilir -> double.infinity ile doldur.
    // Sol kenarlar yuvarlatilir (drawer kenari), sag kenar duz (ekran
    // kenarina yaslanir).
    final size = MediaQuery.of(context).size;
    final panelW = size.width < 460 ? size.width * 0.86 : 400.0;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(16),
      bottomLeft: Radius.circular(16),
    );
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: AppColors.background.withValues(alpha: 0.72),
          elevation: 24,
          borderRadius: radius,
          child: SizedBox(
            width: panelW,
            height: double.infinity,
            child: SafeArea(
              left: false,
              child: Column(
                children: [
                  _Header(
                    section: _section,
                    onSection: (s) => setState(() => _section = s),
                    onClose: widget.onClose,
                  ),
                  Expanded(
                    child: _Body(section: _section, player: widget.player),
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

class _Header extends ConsumerWidget {
  final _Section section;
  final ValueChanged<_Section> onSection;
  final VoidCallback onClose;
  const _Header({
    required this.section,
    required this.onSection,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _Tab(
            label: ref.tr('player.audio'),
            section: _Section.audio,
            active: section,
            onTap: onSection,
          ),
          _Tab(
            label: ref.tr('player.subtitle'),
            section: _Section.subtitle,
            active: section,
            onTap: onSection,
          ),
          _Tab(
            label: ref.tr('player.quality'),
            section: _Section.quality,
            active: section,
            onTap: onSection,
          ),
          _Tab(
            label: ref.tr('player.zoom'),
            section: _Section.zoom,
            active: section,
            onTap: onSection,
          ),
          _Tab(
            label: ref.tr('player.style'),
            section: _Section.style,
            active: section,
            onTap: onSection,
          ),
          _Tab(
            label: ref.tr('player.speed'),
            section: _Section.speed,
            active: section,
            onTap: onSection,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: onClose,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final _Section section;
  final _Section active;
  final ValueChanged<_Section> onTap;
  const _Tab({
    required this.label,
    required this.section,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = section == active;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final _Section section;
  final Player player;
  const _Body({required this.section, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (section) {
      case _Section.audio:
        return _AudioList(player: player);
      case _Section.subtitle:
        return _SubtitleList(player: player);
      case _Section.quality:
        return const _QualityList();
      case _Section.zoom:
        return const _ZoomList();
      case _Section.style:
        return const _StyleSection();
      case _Section.speed:
        return _SpeedSection(player: player);
    }
  }
}

class _AudioList extends ConsumerWidget {
  final Player player;
  const _AudioList({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<Tracks>(
      stream: player.stream.tracks,
      initialData: player.state.tracks,
      builder: (_, tracksSnap) {
        return StreamBuilder<Track>(
          stream: player.stream.track,
          initialData: player.state.track,
          builder: (_, currentSnap) {
            final tracks = tracksSnap.data?.audio ?? const <AudioTrack>[];
            final current = currentSnap.data?.audio;
            if (tracks.isEmpty) {
              return _Empty(label: ref.tr('player.noAudio'));
            }
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: tracks
                  .map(
                    (t) => _TrackTile(
                      label: _audioLabel(ref, t),
                      selected: t.id == current?.id,
                      onTap: () {
                        player.setAudioTrack(t);
                        ref
                            .read(trackPrefsProvider.notifier)
                            .setAudio(lang: t.language, title: t.title);
                      },
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }

  String _audioLabel(WidgetRef ref, AudioTrack t) {
    if (t.id == 'auto') return ref.tr('player.auto');
    if (t.id == 'no') return ref.tr('player.off');
    final parts = <String>[];
    if (t.title != null && t.title!.isNotEmpty) parts.add(t.title!);
    if (t.language != null && t.language!.isNotEmpty)
      parts.add('(${t.language})');
    if (parts.isEmpty) parts.add('${t.id}');
    return parts.join(' ');
  }
}

class _SubtitleList extends ConsumerWidget {
  final Player player;
  const _SubtitleList({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<Tracks>(
      stream: player.stream.tracks,
      initialData: player.state.tracks,
      builder: (_, tracksSnap) {
        return StreamBuilder<Track>(
          stream: player.stream.track,
          initialData: player.state.track,
          builder: (_, currentSnap) {
            final tracks = tracksSnap.data?.subtitle ?? const <SubtitleTrack>[];
            final current = currentSnap.data?.subtitle;
            if (tracks.isEmpty) {
              return _Empty(label: ref.tr('player.noSubtitle'));
            }
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: tracks
                  .map(
                    (t) => _TrackTile(
                      label: _subtitleLabel(ref, t),
                      selected: t.id == current?.id,
                      onTap: () {
                        player.setSubtitleTrack(t);
                        ref
                            .read(trackPrefsProvider.notifier)
                            .setSubtitle(
                              lang: t.language,
                              title: t.title,
                              id: t.id == 'no' || t.id == 'auto' ? t.id : null,
                            );
                      },
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }

  String _subtitleLabel(WidgetRef ref, SubtitleTrack t) {
    if (t.id == 'auto') return ref.tr('player.auto');
    if (t.id == 'no') return ref.tr('player.off');
    final parts = <String>[];
    if (t.title != null && t.title!.isNotEmpty) parts.add(t.title!);
    if (t.language != null && t.language!.isNotEmpty)
      parts.add('(${t.language})');
    if (parts.isEmpty) parts.add('${t.id}');
    return parts.join(' ');
  }
}

class _ZoomList extends ConsumerWidget {
  const _ZoomList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(videoZoomProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            ref.tr('player.zoomIntro'),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final mode in VideoZoomMode.values)
          _TrackTile(
            label: ref.tr(mode.labelKey),
            sublabel: ref.tr(mode.hintKey),
            selected: mode == current,
            onTap: () => ref.read(videoZoomProvider.notifier).set(mode),
          ),
      ],
    );
  }
}

class _QualityList extends ConsumerWidget {
  const _QualityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualityAsync = ref.watch(qualityProvider);
    final current = qualityAsync.value ?? QualityCap.auto;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            ref.tr('player.qualityIntro'),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final cap in QualityCap.values)
          _TrackTile(
            label: ref.tr(cap.labelKey),
            sublabel: ref.tr(cap.hintKey),
            selected: cap == current,
            onTap: () => ref.read(qualityProvider.notifier).set(cap),
          ),
      ],
    );
  }
}

class _SpeedSection extends StatelessWidget {
  final Player player;
  const _SpeedSection({required this.player});

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.rate,
      initialData: player.state.rate,
      builder: (_, snap) {
        final current = snap.data ?? 1.0;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: _speeds
              .map(
                (s) => _TrackTile(
                  label:
                      '${s.toStringAsFixed(s.truncateToDouble() == s ? 1 : 2)}x',
                  selected: (s - current).abs() < 0.01,
                  onTap: () => player.setRate(s),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StyleSection extends ConsumerWidget {
  const _StyleSection();

  static const _colorOptions = <Color>[
    Colors.white,
    Color(0xFFFFEB3B),
    Color(0xFF00E5FF),
    Color(0xFF7CFF6B),
    Color(0xFFFF8A65),
    Color(0xFFFF4081),
  ];
  static const _outlineColors = <Color>[
    Colors.black,
    Color(0xFF222222),
    Color(0xFF555555),
    Color(0x00000000),
  ];
  static const _backgrounds = <Color>[
    Colors.transparent,
    Color(0x66000000),
    Color(0xAA000000),
    Colors.black,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(subtitleSettingsProvider);
    final notifier = ref.read(subtitleSettingsProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            ref.tr('player.exampleSubtitle'),
            style: settings.toTextStyle(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Label(ref.tr('player.fontSize')),
            const Spacer(),
            Text(
              '${settings.fontSize.round()} px',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: settings.fontSize,
          min: SubtitleSettings.minFontSize,
          max: SubtitleSettings.maxFontSize,
          divisions:
              (SubtitleSettings.maxFontSize - SubtitleSettings.minFontSize)
                  .round() ~/
              2,
          activeColor: AppColors.accent,
          label: '${settings.fontSize.round()} px',
          onChanged: notifier.setFontSize,
        ),
        const SizedBox(height: 4),
        _Label(ref.tr('player.color')),
        _ColorRow(
          colors: _colorOptions,
          selected: settings.color,
          onSelect: notifier.setColor,
        ),
        const SizedBox(height: 12),
        _Label(ref.tr('player.outline')),
        _ColorRow(
          colors: _outlineColors,
          selected: settings.outlineColor,
          onSelect: notifier.setOutlineColor,
        ),
        Slider(
          value: settings.outlineWidth,
          min: 0,
          max: 6,
          divisions: 12,
          activeColor: AppColors.accent,
          label: settings.outlineWidth.toStringAsFixed(1),
          onChanged: notifier.setOutlineWidth,
        ),
        const SizedBox(height: 4),
        _Label(ref.tr('player.background')),
        _ColorRow(
          colors: _backgrounds,
          selected: settings.backgroundColor,
          onSelect: notifier.setBackgroundColor,
        ),
        const SizedBox(height: 12),
        _Label(ref.tr('player.weight')),
        Wrap(
          spacing: 8,
          children: [
            _WeightChip(
              weight: FontWeight.w400,
              selected: settings.fontWeight,
              onTap: notifier.setFontWeight,
              label: ref.tr('player.weightNormal'),
            ),
            _WeightChip(
              weight: FontWeight.w600,
              selected: settings.fontWeight,
              onTap: notifier.setFontWeight,
              label: ref.tr('player.weightSemi'),
            ),
            _WeightChip(
              weight: FontWeight.w800,
              selected: settings.fontWeight,
              onTap: notifier.setFontWeight,
              label: ref.tr('player.weightBold'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrackTile extends StatefulWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;
  const _TrackTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
  });

  @override
  State<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<_TrackTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: widget.selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : (_hover ? AppColors.surface : Colors.transparent),
          child: Row(
            children: [
              Icon(
                widget.selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: widget.selected
                    ? AppColors.accent
                    : AppColors.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.selected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13.5,
                      ),
                    ),
                    if (widget.sublabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.sublabel!,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11.5,
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
    );
  }
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;
  const _ColorRow({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: colors.map((c) {
        final isSelected = c.value == selected.value;
        return GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c == Colors.transparent ? Colors.transparent : c,
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.divider,
                width: isSelected ? 2.5 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: c == Colors.transparent
                ? const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _WeightChip extends StatelessWidget {
  final FontWeight weight;
  final FontWeight selected;
  final ValueChanged<FontWeight> onTap;
  final String label;
  const _WeightChip({
    required this.weight,
    required this.selected,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = weight == selected;
    return GestureDetector(
      onTap: () => onTap(weight),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontWeight: weight,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
