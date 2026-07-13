import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/i18n.dart';
import '../../../core/widgets/dpad_text_field.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/adult_filter_provider.dart';

class AdultFilterDialog extends ConsumerStatefulWidget {
  const AdultFilterDialog({super.key});

  @override
  ConsumerState<AdultFilterDialog> createState() => _AdultFilterDialogState();
}

class _AdultFilterDialogState extends ConsumerState<AdultFilterDialog> {
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(adultFilterProvider);
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: stateAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (e, _) => Text(
              'Hata: $e',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            data: (state) => _buildBody(state),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AdultFilterState state) {
    final localeAsync = ref.watch(localeProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.settings_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ref.tr('settings.title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Language switcher
        localeAsync.when(
          loading: () => const SizedBox(
            height: 40,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
          ),
          error: (e, _) => Text(
            '$e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          data: (lst) => Row(
            children: [
              const Icon(
                Icons.language_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                ref.tr('settings.language'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: lst.code,
                dropdownColor: AppColors.surface,
                underline: const SizedBox.shrink(),
                items: lst.available
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) ref.read(localeProvider.notifier).setLocale(v);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 2),
          child: Text(
            ref.tr('settings.languageHint'),
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: 12),
        // Adult filter
        Row(
          children: [
            const Icon(Icons.shield_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ref.tr('settings.adultFilter'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          state.hasPin
              ? ref.tr('settings.adultPinHelpHas')
              : ref.tr('settings.adultPinHelpNone'),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.accent,
          title: Text(
            ref.tr('settings.adultShow'),
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            ref.tr('settings.adultDesc'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          // Inverted logic: switch on = 18+ content hidden. When turned off
          // (switching to showing) target=true and a PIN is asked.
          value: !state.showAdult,
          onChanged: _busy ? null : (v) => _onToggleShow(state, !v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.accent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(
                  state.hasPin ? Icons.lock_reset_rounded : Icons.lock_rounded,
                ),
                label: Text(
                  state.hasPin
                      ? ref.tr('settings.adultPinChange')
                      : ref.tr('settings.adultPinSet'),
                ),
                onPressed: _busy ? null : () => _onSetPin(state),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (state.hasPin) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.accent,
                  ),
                  label: Text(
                    ref.tr('settings.adultPinRemove'),
                    style: const TextStyle(color: AppColors.accent),
                  ),
                  onPressed: _busy ? null : () => _onClearPin(state),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _onToggleShow(AdultFilterState state, bool target) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (target && state.hasPin) {
        final ok = await _askPin(verb: 'doğrula');
        if (!ok) {
          setState(() => _error = ref.tr('settings.pinWrong'));
          return;
        }
      }
      await ref.read(adultFilterProvider.notifier).setShowAdult(target);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSetPin(AdultFilterState state) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (state.hasPin) {
        final ok = await _askPin(verb: 'doğrula');
        if (!ok) {
          setState(() => _error = ref.tr('settings.pinWrong'));
          return;
        }
      }
      final newPin = await _askNewPin();
      if (newPin == null) return;
      await ref.read(adultFilterProvider.notifier).setPin(newPin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.tr('settings.pinUpdated'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onClearPin(AdultFilterState state) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _askPin(verb: 'doğrula');
      if (!ok) {
        setState(() => _error = ref.tr('settings.pinWrong'));
        return;
      }
      await ref.read(adultFilterProvider.notifier).clearPin();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _askPin({required String verb}) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _PinPromptDialog(controller: ctl, title: ref.tr('settings.pinCurrent')),
    );
    if (ok != true) return false;
    return ref.read(adultFilterProvider.notifier).verifyPin(ctl.text);
  }

  Future<String?> _askNewPin() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _PinPromptDialog(
        controller: ctl,
        title: ref.tr('settings.pinNew'),
        minLen: 4,
      ),
    );
    if (ok != true) return null;
    return ctl.text;
  }
}

class _PinPromptDialog extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String title;
  final int minLen;
  const _PinPromptDialog({
    required this.controller,
    required this.title,
    this.minLen = 0,
  });

  @override
  ConsumerState<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends ConsumerState<_PinPromptDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DpadTextField(
            child: TextField(
              controller: widget.controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
              ),
              autofocus: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(ref.tr('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            if (widget.controller.text.length < widget.minLen) {
              setState(() => _error = ref.tr('settings.pinMinLen', {
                'n': '${widget.minLen}',
              }));
              return;
            }
            Navigator.of(context).pop(true);
          },
          child: Text(ref.tr('common.confirm')),
        ),
      ],
    );
  }
}
