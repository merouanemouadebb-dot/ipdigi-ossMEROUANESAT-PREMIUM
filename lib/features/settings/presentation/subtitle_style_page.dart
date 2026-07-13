import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/providers/subtitle_settings_provider.dart';

class SubtitleStylePage extends ConsumerWidget {
  const SubtitleStylePage({super.key});

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
    final settingsAsync = ref.watch(persistedSubtitleSettingsProvider);
    final notifier = ref.read(persistedSubtitleSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('player.subtitleStyleSection'))),
      body: settingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text(
            '${ref.tr('common.error')}: $e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                ref.tr('player.subtitleStyleDesc'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                ref.tr('player.exampleSubtitle'),
                style: settings.toTextStyle(),
              ),
            ),
            const SizedBox(height: 22),
            _Header(
              label: ref.tr('player.fontSize'),
              trailing: '${settings.fontSize.round()} px',
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
              onChanged: (v) => notifier.setFontSize(v),
            ),
            const SizedBox(height: 10),
            _Header(label: ref.tr('player.color')),
            _ColorRow(
              colors: _colorOptions,
              selected: settings.color,
              onSelect: notifier.setColor,
            ),
            const SizedBox(height: 18),
            _Header(label: ref.tr('player.outline')),
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
              onChanged: (v) => notifier.setOutlineWidth(v),
            ),
            const SizedBox(height: 10),
            _Header(label: ref.tr('player.background')),
            _ColorRow(
              colors: _backgrounds,
              selected: settings.backgroundColor,
              onSelect: notifier.setBackgroundColor,
            ),
            const SizedBox(height: 18),
            _Header(label: ref.tr('player.weight')),
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
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  final String? trailing;
  const _Header({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final void Function(Color) onSelect;
  const _ColorRow({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: colors.map((c) {
        final isSelected = c.toARGB32() == selected.toARGB32();
        return GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c == Colors.transparent ? Colors.transparent : c,
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.divider,
                width: isSelected ? 2.5 : 1,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: c == Colors.transparent
                ? const Icon(
                    Icons.close_rounded,
                    size: 16,
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
  final void Function(FontWeight) onTap;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
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
