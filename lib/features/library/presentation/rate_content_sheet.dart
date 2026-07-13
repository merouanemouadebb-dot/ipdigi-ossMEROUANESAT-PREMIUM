import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/widgets/dpad_text_field.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/ratings_provider.dart';

/// Rating sheet from 1.0 - 10.0 in 0.5 steps + an optional comment field.
/// One tap fills, a second tap gives a half star (0.5 down); a third tap
/// clears that star entirely - this ordering makes scores like "7.5 out
/// of 10" reachable with a single thumb.
class RateContentSheet extends ConsumerStatefulWidget {
  final String sourceId;
  final String contentId;
  final String contentName;
  final String? parentId;
  final UserRating? existing;
  /// The content's TMDB id (passed in from the detail page). Persisted
  /// together with the rating; for cross-panel matching.
  final int? tmdbId;
  const RateContentSheet({
    super.key,
    required this.sourceId,
    required this.contentId,
    required this.contentName,
    this.parentId,
    this.existing,
    this.tmdbId,
  });

  static Future<void> show(
    BuildContext context, {
    required String sourceId,
    required String contentId,
    required String contentName,
    String? parentId,
    UserRating? existing,
    int? tmdbId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RateContentSheet(
        sourceId: sourceId,
        contentId: contentId,
        contentName: contentName,
        parentId: parentId,
        existing: existing,
        tmdbId: tmdbId,
      ),
    );
  }

  @override
  ConsumerState<RateContentSheet> createState() => _RateContentSheetState();
}

class _RateContentSheetState extends ConsumerState<RateContentSheet> {
  late double _score;
  late TextEditingController _commentCtl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _score = widget.existing?.score ?? 0;
    _commentCtl = TextEditingController(text: widget.existing?.comment ?? '');
  }

  @override
  void dispose() {
    _commentCtl.dispose();
    super.dispose();
  }

  void _onStarTap(int index1Based) {
    // A single star maps to two "halves". Order: 0 → full → half → 0.
    final full = index1Based * 2.0;
    final half = full - 1.0;
    final scoreSteps = (_score * 2).round();
    setState(() {
      if (scoreSteps == full.toInt()) {
        _score = half / 2;
      } else if (scoreSteps == half.toInt()) {
        _score = 0;
      } else {
        _score = full / 2;
      }
    });
  }

  Future<void> _save() async {
    if (_score < 1.0) return;
    setState(() => _saving = true);
    await ref.read(userRatingsProvider.notifier).rate(
          sourceId: widget.sourceId,
          contentId: widget.contentId,
          parentId: widget.parentId,
          score: _score,
          comment: _commentCtl.text,
          tmdbId: widget.tmdbId ?? widget.existing?.tmdbId,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    await ref.read(userRatingsProvider.notifier).remove(
          sourceId: widget.sourceId,
          contentId: widget.contentId,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final hasRating = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.contentName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ref.tr('rating.subtitle'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              _StarRow(score: _score, onTap: _onStarTap),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _score >= 1.0
                      ? ref.tr(
                          'rating.scoreLabel',
                          {'n': _score.toStringAsFixed(1)},
                        )
                      : ref.tr('rating.scoreEmpty'),
                  style: TextStyle(
                    color: _score >= 1.0
                        ? AppColors.accent
                        : AppColors.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              DpadTextField(
                child: TextField(
                controller: _commentCtl,
                minLines: 2,
                maxLines: 5,
                maxLength: 800,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: ref.tr('rating.commentHint'),
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  counterStyle:
                      const TextStyle(color: AppColors.textTertiary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (hasRating)
                    Expanded(
                      child: TextButton(
                        onPressed: _saving ? null : _delete,
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.redAccent,
                        ),
                        child: Text(ref.tr('rating.delete')),
                      ),
                    ),
                  if (hasRating) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          _saving || _score < 1.0 ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        ref.tr('rating.save'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double score; // 0..10
  final void Function(int index1Based) onTap;
  const _StarRow({required this.score, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 1; i <= 10; i++)
          _FocusableStar(
            state: _stateFor(i),
            onTap: () => onTap(i),
          ),
      ],
    );
  }

  _StarState _stateFor(int i) {
    final steps = (score * 2).round(); // half-steps
    final fullThreshold = i * 2;
    if (steps >= fullThreshold) return _StarState.full;
    if (steps == fullThreshold - 1) return _StarState.half;
    return _StarState.empty;
  }
}

enum _StarState { empty, half, full }

/// A single star. Focusable on the TV remote: navigated with the D-pad,
/// rated with SELECT/OK; an accent border when focused.
class _FocusableStar extends StatefulWidget {
  final _StarState state;
  final VoidCallback onTap;
  const _FocusableStar({required this.state, required this.onTap});

  @override
  State<_FocusableStar> createState() => _FocusableStarState();
}

class _FocusableStarState extends State<_FocusableStar> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: (_focus && PlatformInfo.isTv)
                ? Border.all(color: AppColors.accent, width: 3)
                : null,
          ),
          child: _StarIcon(state: widget.state),
        ),
      ),
    );
  }
}

class _StarIcon extends StatelessWidget {
  final _StarState state;
  const _StarIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StarState.full:
        return const Icon(
          Icons.star_rounded,
          size: 30,
          color: AppColors.accent,
        );
      case _StarState.half:
        return const Icon(
          Icons.star_half_rounded,
          size: 30,
          color: AppColors.accent,
        );
      case _StarState.empty:
        return Icon(
          Icons.star_outline_rounded,
          size: 30,
          color: AppColors.textTertiary.withValues(alpha: 0.7),
        );
    }
  }
}
