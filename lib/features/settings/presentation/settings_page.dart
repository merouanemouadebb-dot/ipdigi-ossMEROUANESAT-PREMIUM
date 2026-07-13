import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_info.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/widgets/dpad_text_field.dart';
import '../../../core/metadata/tmdb_provider.dart';
import '../../../core/metadata/tmdb_service.dart';
import '../../../core/utils/nav_throttle.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/prefs/user_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../sources/presentation/source_tile.dart';
import '../../sources/providers/sources_provider.dart';
import '../providers/adult_filter_provider.dart';
import '../providers/tmdb_credentials_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeProvider);
    final adultAsync = ref.watch(adultFilterProvider);
    final sourcesAsync = ref.watch(sourcesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        children: [
          // The Pro subscription status and account block moved to the
          // Profile page - the Apple App Review "subscription management UI
          // in a visible place" criterion is met by Profile (accessible in
          // the sidebar).
          _Section(
            title: ref.tr('settings.appearance'),
            child: Column(
              children: [
                _LanguageRow(localeAsync: localeState, ref: ref),
                const Divider(height: 1, color: AppColors.divider),
                _SubtitleStyleRow(ref: ref),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: ref.tr('settings.contentSection'),
            child: _AdultBlock(state: adultAsync, ref: ref),
          ),
          const SizedBox(height: 18),
          _Section(
            title: ref.tr('settings.tmdbSection'),
            child: const _TmdbBlock(),
          ),
          const SizedBox(height: 18),
          _Section(
            title: ref.tr('settings.sourcesSection'),
            trailing: TextButton.icon(
              onPressed: () => context.go('/sources/add'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(ref.tr('sources.add')),
            ),
            child: _SourcesBlock(state: sourcesAsync, ref: ref),
          ),
          const SizedBox(height: 18),
          _Section(
            title: ref.tr('settings.cacheSection'),
            child: const _CacheBlock(),
          ),
        ],
      ),
    );
  }
}

class _CacheBlock extends ConsumerWidget {
  const _CacheBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(ref.tr('settings.clearCache')),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            ref.tr('settings.clearCacheDesc'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _confirm(context, ref),
          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
          label: Text(ref.tr('settings.clearCache')),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('settings.clearCache')),
        content: Text(ref.tr('settings.clearCacheConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.tr('settings.clearCache')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _clearAll(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ref.tr('settings.cacheCleared'))));
  }

  Future<void> _clearAll(WidgetRef ref) async {
    // Drop the live decoded-image map first so any poster on screen is
    // forced to re-pull from the (now empty) disk cache below.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
    // Wipe every cached TMDB lookup result so the next paint re-queries
    // with the current rules (incl. adult-skip / TMDB-host-block).
    ref.invalidate(tmdbDetailProvider);
  }
}

class _SourcesBlock extends StatelessWidget {
  final AsyncValue state;
  final WidgetRef ref;
  const _SourcesBlock({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '${ref.tr('common.error')}: $e',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.tr('sources.empty'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ref.tr('sources.emptyMsg'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/sources/add'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(ref.tr('sources.add')),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              SourceTile(source: list[i]),
              if (i != list.length - 1)
                const Divider(height: 1, color: AppColors.divider),
            ],
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SegOption {
  final String id;
  final String label;
  final IconData icon;
  const _SegOption({required this.id, required this.label, required this.icon});
}

class _SegmentedButton extends StatelessWidget {
  final List<_SegOption> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _SegmentedButton({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final active = o.id == selected;
          return GestureDetector(
            onTap: () => onChanged(o.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    o.icon,
                    size: 14,
                    color: active
                        ? (AppColors.isDark ? Colors.black : Colors.white)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    o.label,
                    style: TextStyle(
                      color: active
                          ? (AppColors.isDark ? Colors.black : Colors.white)
                          : AppColors.textSecondary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final AsyncValue<LocaleState> localeAsync;
  final WidgetRef ref;
  const _LanguageRow({required this.localeAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        children: [
          const Icon(
            Icons.language_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ref.tr('settings.language'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          localeAsync.when(
            loading: () => const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            error: (e, _) => Text(
              '$e',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            data: (state) => DropdownButton<String>(
              value: state.code,
              // Zinc-900: the popup did not stand out enough between the
              // surface (#15151B) and the page background (#0B0B0F), so when
              // the dropdown opened the user could not tell where the menu
              // started.
              dropdownColor: const Color(0xFF18181B),
              underline: const SizedBox.shrink(),
              items: state.available
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(_languageNativeName(c)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) ref.read(localeProvider.notifier).setLocale(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtitleStyleRow extends StatefulWidget {
  final WidgetRef ref;
  const _SubtitleStyleRow({required this.ref});

  @override
  State<_SubtitleStyleRow> createState() => _SubtitleStyleRowState();
}

class _SubtitleStyleRowState extends State<_SubtitleStyleRow> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final ref = widget.ref;
    return Focus(
      onFocusChange: (v) => setState(() => _focus = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          context.pushOnce('/sources/subtitle-style');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: (_focus && PlatformInfo.isTv)
            ? AppColors.accent.withValues(alpha: 0.16)
            : Colors.transparent,
        child: InkWell(
          onTap: () => context.pushOnce('/sources/subtitle-style'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
          children: [
            const Icon(
              Icons.closed_caption_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr('player.subtitleStyleSection'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ref.tr('player.subtitleStyleDesc'),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _AdultBlock extends ConsumerStatefulWidget {
  final AsyncValue<AdultFilterState> state;
  final WidgetRef ref;
  const _AdultBlock({required this.state, required this.ref});

  @override
  ConsumerState<_AdultBlock> createState() => _AdultBlockState();
}

class _AdultBlockState extends ConsumerState<_AdultBlock> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return widget.state.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '$e',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      data: (s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.accent,
              title: Text(
                widget.ref.tr('settings.adultShow'),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                widget.ref.tr('settings.adultDesc'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              // Inverted logic: switch on = 18+ content hidden. Turning it
              // off (switching to show) makes _toggleShow take target=true
              // and prompts for the PIN.
              value: !s.showAdult,
              onChanged: _busy ? null : (v) => _toggleShow(s, !v),
            ),
            const SizedBox(height: 4),
            Text(
              s.hasPin
                  ? widget.ref.tr('settings.adultPinHelpHas')
                  : widget.ref.tr('settings.adultPinHelpNone'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.accent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _setPin(s),
                    icon: Icon(
                      s.hasPin ? Icons.lock_reset_rounded : Icons.lock_rounded,
                    ),
                    label: Text(
                      s.hasPin
                          ? widget.ref.tr('settings.adultPinChange')
                          : widget.ref.tr('settings.adultPinSet'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (s.hasPin) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _clearPin(s),
                      icon: const Icon(
                        Icons.lock_open_rounded,
                        color: AppColors.accent,
                      ),
                      label: Text(
                        widget.ref.tr('settings.adultPinRemove'),
                        style: const TextStyle(color: AppColors.accent),
                      ),
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
        ),
      ),
    );
  }

  Future<void> _toggleShow(AdultFilterState s, bool target) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (target && s.hasPin) {
        final ok = await _askPin();
        if (!ok) {
          setState(() => _error = widget.ref.tr('settings.pinWrong'));
          return;
        }
      }
      await ref.read(adultFilterProvider.notifier).setShowAdult(target);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPin(AdultFilterState s) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (s.hasPin) {
        final ok = await _askPin();
        if (!ok) {
          setState(() => _error = widget.ref.tr('settings.pinWrong'));
          return;
        }
      }
      final newPin = await _askNewPin();
      if (newPin == null) return;
      await ref.read(adultFilterProvider.notifier).setPin(newPin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.ref.tr('settings.pinUpdated'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearPin(AdultFilterState s) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _askPin();
      if (!ok) {
        setState(() => _error = widget.ref.tr('settings.pinWrong'));
        return;
      }
      await ref.read(adultFilterProvider.notifier).clearPin();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _askPin() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _PinPromptDialog(
        controller: ctl,
        title: widget.ref.tr('settings.pinCurrent'),
      ),
    );
    if (ok != true) return false;
    return ref.read(adultFilterProvider.notifier).verifyPin(ctl.text);
  }

  Future<String?> _askNewPin() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _PinPromptDialog(
        controller: ctl,
        title: widget.ref.tr('settings.pinNew'),
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
      title: Text(
        widget.title,
        style: const TextStyle(color: AppColors.textPrimary),
      ),
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
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(ref.tr('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            if (widget.controller.text.length < widget.minLen) {
              setState(() => _error =
                  ref.tr('settings.pinMinLen', {'n': '${widget.minLen}'}));
              return;
            }
            Navigator.of(context, rootNavigator: true).pop(true);
          },
          child: Text(ref.tr('common.ok')),
        ),
      ],
    );
  }
}

class _TmdbBlock extends ConsumerStatefulWidget {
  const _TmdbBlock();

  @override
  ConsumerState<_TmdbBlock> createState() => _TmdbBlockState();
}

class _TmdbBlockState extends ConsumerState<_TmdbBlock> {
  final _controller = TextEditingController();
  bool _obscured = true;
  bool _busy = false;
  // Local mirror of what's persisted in the keychain, refreshed once on
  // mount and updated by our own save/clear. Decoupled from the provider's
  // AsyncValue so save → snackbar → text field stay consistent without
  // depending on Riverpod's rebuild timing (provider invalidate during
  // save was racing the build that resynced the controller, which made it
  // look like the key wasn't persisted).
  String _savedKey = '';

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final stored =
          await ref
              .read(userPreferencesProvider)
              .getString(PrefKeys.tmdbApiKey) ??
          '';
      if (!mounted) return;
      setState(() {
        _savedKey = stored;
        _controller.text = stored;
      });
    } catch (e) {
      _showSnack('TMDB: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _maskTail(String key) {
    if (key.length <= 4) return '••••';
    return '•••• ${key.substring(key.length - 4)}';
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final input = _controller.text.trim();
      if (input.isEmpty) {
        await ref.read(tmdbApiKeyProvider.notifier).clear();
        if (!mounted) return;
        setState(() => _savedKey = '');
        _showSnack(ref.tr('settings.tmdbCleared'));
        return;
      }
      final service = TmdbService(dio: ref.read(dioProvider), apiKey: '');
      final result = await service.verifyKey(input);
      switch (result) {
        case TmdbVerifyResult.ok:
          await ref.read(tmdbApiKeyProvider.notifier).setKey(input);
          if (!mounted) return;
          setState(() => _savedKey = input);
          _showSnack('${ref.tr('settings.tmdbSaved')} (${_maskTail(input)})');
        case TmdbVerifyResult.invalid:
          _showSnack(ref.tr('settings.tmdbInvalid'), isError: true);
        case TmdbVerifyResult.networkError:
          _showSnack(ref.tr('settings.tmdbNetworkError'), isError: true);
        case TmdbVerifyResult.empty:
          await ref.read(tmdbApiKeyProvider.notifier).clear();
          if (!mounted) return;
          setState(() => _savedKey = '');
          _showSnack(ref.tr('settings.tmdbCleared'));
      }
    } catch (e) {
      _showSnack('TMDB: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _controller.clear();
      await ref.read(tmdbApiKeyProvider.notifier).clear();
      if (!mounted) return;
      setState(() => _savedKey = '');
      _showSnack(ref.tr('settings.tmdbCleared'));
    } catch (e) {
      _showSnack('TMDB: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _savedKey.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasKey
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                color: hasKey ? AppColors.accent : AppColors.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasKey
                      ? ref.tr('settings.tmdbActive')
                      : ref.tr('settings.tmdbInactive'),
                  style: TextStyle(
                    color: hasKey ? AppColors.accent : AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ref.tr('settings.tmdbDesc'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          DpadTextField(
            child: TextField(
            controller: _controller,
            obscureText: _obscured,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              hintText: ref.tr('settings.tmdbKeyHint'),
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                tooltip: _obscured
                    ? ref.tr('settings.tmdbReveal')
                    : ref.tr('settings.tmdbHide'),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _busy
                      ? ref.tr('settings.tmdbValidating')
                      : ref.tr('common.save'),
                ),
              ),
              const SizedBox(width: 10),
              if (hasKey)
                TextButton.icon(
                  onPressed: _busy ? null : _clear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(ref.tr('common.remove')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The name of a language **in its own language** for a given BCP-47 code.
/// So the language picker always shows a language's visual label in that
/// language's own spelling - e.g. the native name instead of "TR / EN".
/// The list stays parallel to tr.json + en.json; if the user adds their own
/// locale JSON, the file name (basename) is shown as the label.
String _languageNativeName(String code) {
  switch (code.toLowerCase()) {
    case 'tr':
      return 'Türkçe';
    case 'en':
      return 'English';
    case 'de':
      return 'Deutsch';
    case 'fr':
      return 'Français';
    case 'es':
      return 'Español';
    case 'it':
      return 'Italiano';
    case 'pt':
      return 'Português';
    case 'ru':
      return 'Русский';
    case 'ar':
      return 'العربية';
    case 'nl':
      return 'Nederlands';
    case 'pl':
      return 'Polski';
    case 'ro':
      return 'Română';
    case 'az':
      return 'Azərbaycanca';
    case 'fa':
      return 'فارسی';
    case 'zh':
      return '中文';
    case 'ja':
      return '日本語';
    case 'ko':
      return '한국어';
    default:
      return code;
  }
}

