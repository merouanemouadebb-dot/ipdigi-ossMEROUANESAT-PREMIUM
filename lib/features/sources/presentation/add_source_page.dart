import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/i18n.dart';
import '../../../core/widgets/dpad_text_field.dart';
import '../domain/source.dart';
import '../providers/sources_provider.dart';

class AddSourcePage extends ConsumerStatefulWidget {
  const AddSourcePage({super.key});

  @override
  ConsumerState<AddSourcePage> createState() => _AddSourcePageState();
}

class _AddSourcePageState extends ConsumerState<AddSourcePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _saving = false;
  String? _error;

  final _xtreamName = TextEditingController();
  final _xtreamUrl = TextEditingController();
  final _xtreamUser = TextEditingController();
  final _xtreamPass = TextEditingController();

  final _m3uName = TextEditingController();
  final _m3uUrl = TextEditingController();
  final _m3uEpg = TextEditingController();

  final _directName = TextEditingController();
  final _directUrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _xtreamName,
      _xtreamUrl,
      _xtreamUser,
      _xtreamPass,
      _m3uName,
      _m3uUrl,
      _m3uEpg,
      _directName,
      _directUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    IptvSource? src;
    try {
      final now = DateTime.now();
      if (_tabs.index == 0) {
        if (_xtreamUrl.text.trim().isEmpty || _xtreamUser.text.trim().isEmpty) {
          throw ref.tr('sources.needCreds');
        }
        final url = _xtreamUrl.text.trim();
        final user = _xtreamUser.text.trim();
        src = XtreamSource(
          // Deterministic id: adding the same panel again yields the same id →
          // ratings/history/favorites don't break.
          id: IptvSource.deterministicId(
            kind: SourceKind.xtream,
            config: {'url': url, 'username': user},
          ),
          name: _xtreamName.text.trim().isEmpty
              ? 'Xtream'
              : _xtreamName.text.trim(),
          createdAt: now,
          url: url,
          username: user,
          password: _xtreamPass.text,
        );
      } else if (_tabs.index == 1) {
        if (_m3uUrl.text.trim().isEmpty) throw ref.tr('sources.needM3u');
        final m3uUrl = _m3uUrl.text.trim();
        src = M3uSource(
          id: IptvSource.deterministicId(
            kind: SourceKind.m3u,
            config: {'urlOrPath': m3uUrl},
          ),
          name: _m3uName.text.trim().isEmpty ? 'M3U' : _m3uName.text.trim(),
          createdAt: now,
          urlOrPath: m3uUrl,
          epgUrl: _m3uEpg.text.trim().isEmpty ? null : _m3uEpg.text.trim(),
        );
      } else {
        if (_directUrl.text.trim().isEmpty) throw ref.tr('sources.needStream');
        final dUrl = _directUrl.text.trim();
        src = DirectUrlSource(
          id: IptvSource.deterministicId(
            kind: SourceKind.direct,
            config: {'url': dUrl},
          ),
          name: _directName.text.trim().isEmpty
              ? 'Stream'
              : _directName.text.trim(),
          createdAt: now,
          url: dUrl,
        );
      }
      final sources = ref.read(sourcesProvider.notifier);
      // On Android TV, fetching the whole Xtream catalog while on the form
      // (live + VOD + series, sometimes tens of thousands of rows) puts the
      // Activity under memory/IO pressure and can look like "the app crashed
      // when I entered the account". Persist the record quickly, close the
      // screen, and leave the heavy download to the provider's background refresh.
      await sources.addSource(src, autoLoad: false);
      if (!mounted) return;
      context.pop();
      unawaited(
        sources.refreshSource(src).catchError((e, st) {
          // ignore: avoid_print
          print(
            '[${AppConfig.I.appName}] background source load error: $e\n$st',
          );
        }),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[${AppConfig.I.appName}] addSource error: $e\n$st');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('sources.addPage')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: ref.tr('addSource.tabXtream')),
            Tab(text: ref.tr('addSource.tabM3u')),
            Tab(text: ref.tr('addSource.tabDirect')),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [_xtreamTab(), _m3uTab(), _directTab()],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(ref.tr('sources.saveLoad')),
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

  Widget _xtreamTab() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        _field(
          controller: _xtreamName,
          label: ref.tr('sources.name'),
          hint: ref.tr('addSource.xtreamName'),
        ),
        _field(
          controller: _xtreamUrl,
          label: ref.tr('sources.serverUrl'),
          hint: ref.tr('addSource.serverHint'),
          isUrl: true,
        ),
        _field(controller: _xtreamUser, label: ref.tr('sources.username')),
        _field(
          controller: _xtreamPass,
          label: ref.tr('sources.password'),
          obscure: true,
        ),
      ],
    ),
  );

  Widget _m3uTab() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        _field(controller: _m3uName, label: ref.tr('sources.name')),
        _field(
          controller: _m3uUrl,
          label: ref.tr('sources.m3uUrl'),
          hint: ref.tr('addSource.m3uHint'),
          isUrl: true,
        ),
        _field(
          controller: _m3uEpg,
          label: ref.tr('sources.epgUrl'),
          isUrl: true,
        ),
      ],
    ),
  );

  Widget _directTab() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        _field(controller: _directName, label: ref.tr('sources.name')),
        _field(
          controller: _directUrl,
          label: ref.tr('sources.streamUrl'),
          hint: ref.tr('addSource.streamHint'),
          isUrl: true,
        ),
      ],
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    bool isUrl = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      // D-pad: let the vertical arrow keys move focus between fields (TV
      // remote). Otherwise the TextField swallows the arrow keys and the
      // remote can't reach the next field.
      child: DpadTextField(
        child: TextField(
          controller: controller,
          obscureText: obscure,
          // URL fields: the http keyboard (/ and . are easy), auto-
          // capitalization + autocorrect off (otherwise you get broken
          // input like "Http://Example"). Paste is on by default in Flutter.
          keyboardType: isUrl ? TextInputType.url : TextInputType.text,
          autocorrect: !isUrl && !obscure,
          enableSuggestions: !isUrl && !obscure,
          textCapitalization: (isUrl || obscure)
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          enableInteractiveSelection: true,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      ),
    );
  }
}
