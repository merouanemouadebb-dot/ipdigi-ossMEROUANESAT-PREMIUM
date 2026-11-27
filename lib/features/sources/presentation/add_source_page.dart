
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
  ConsumerState<AddSourcePage> createState() =>
      _AddSourcePageState();
}

class _AddSourcePageState
    extends ConsumerState<AddSourcePage>
    with SingleTickerProviderStateMixin {
  static const gold = Color(0xFFD4AF37);

  late final TabController _tabs;
  bool _saving = false;
  bool _hidePassword = true;
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

    try {
      final now = DateTime.now();
      final IptvSource src;

      if (_tabs.index == 0) {
        if (_xtreamUrl.text.trim().isEmpty ||
            _xtreamUser.text.trim().isEmpty) {
          throw ref.tr('sources.needCreds');
        }

        final url = _xtreamUrl.text.trim();
        final user = _xtreamUser.text.trim();

        src = XtreamSource(
          id: IptvSource.deterministicId(
            kind: SourceKind.xtream,
            config: {'url': url, 'username': user},
          ),
          name: _xtreamName.text.trim().isEmpty
              ? 'MEROUANESAT'
              : _xtreamName.text.trim(),
          createdAt: now,
          url: url,
          username: user,
          password: _xtreamPass.text,
        );
      } else if (_tabs.index == 1) {
        if (_m3uUrl.text.trim().isEmpty) {
          throw ref.tr('sources.needM3u');
        }

        final m3uUrl = _m3uUrl.text.trim();

        src = M3uSource(
          id: IptvSource.deterministicId(
            kind: SourceKind.m3u,
            config: {'urlOrPath': m3uUrl},
          ),
          name: _m3uName.text.trim().isEmpty
              ? 'MEROUANESAT'
              : _m3uName.text.trim(),
          createdAt: now,
          urlOrPath: m3uUrl,
          epgUrl: _m3uEpg.text.trim().isEmpty
              ? null
              : _m3uEpg.text.trim(),
        );
      } else {
        if (_directUrl.text.trim().isEmpty) {
          throw ref.tr('sources.needStream');
        }

        final dUrl = _directUrl.text.trim();

        src = DirectUrlSource(
          id: IptvSource.deterministicId(
            kind: SourceKind.direct,
            config: {'url': dUrl},
          ),
          name: _directName.text.trim().isEmpty
              ? 'MEROUANESAT'
              : _directName.text.trim(),
          createdAt: now,
          url: dUrl,
        );
      }

      final sources =
          ref.read(sourcesProvider.notifier);

      await sources.addSource(
        src,
        autoLoad: false,
      );

      if (!mounted) return;

      context.pop();

      unawaited(
        sources.refreshSource(src).catchError((e, st) {
          print(
            '[${AppConfig.I.appName}] background source load error: $e\n$st',
          );
        }),
      );
    } catch (e, st) {
      print(
        '[${AppConfig.I.appName}] addSource error: $e\n$st',
      );

      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080808),
        foregroundColor: gold,
        centerTitle: true,
        title: const Text(
          'MEROUANESAT PREMIUM',
          style: TextStyle(
            color: gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [
              Color(0xFF302512),
              Color(0xFF080808),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF382B13),
                            Color(0xFF101010),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF65542C),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.movie_filter_outlined,
                            color: gold,
                            size: 40,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome Back',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'LIVE TV • MOVIES • SERIES',
                                  style: TextStyle(
                                    color: gold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF171717),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabs,
                        labelColor: gold,
                        unselectedLabelColor:
                            Colors.white70,
                        indicatorColor: gold,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        tabs: const [
                          Tab(text: 'XTREAM'),
                          Tab(text: 'M3U'),
                          Tab(text: 'DIRECT'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _xtreamTab(),
                          _m3uTab(),
                          _directTab(),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.redAccent,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.play_arrow_rounded,
                            ),
                      label: const Text(
                        'CONNECT NOW',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'YOUR WORLD OF ENTERTAINMENT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _xtreamTab() => SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            _field(
              controller: _xtreamName,
              label: 'Profile Name',
              hint: 'MEROUANESAT',
              icon: Icons.badge_outlined,
            ),
            _field(
              controller: _xtreamUrl,
              label: 'Server URL',
              hint: ref.tr('addSource.serverHint'),
              icon: Icons.language,
              isUrl: true,
            ),
            _field(
              controller: _xtreamUser,
              label: 'Username',
              icon: Icons.person_outline,
            ),
            _field(
              controller: _xtreamPass,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: true,
            ),
          ],
        ),
      );

  Widget _m3uTab() => SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            _field(
              controller: _m3uName,
              label: 'Profile Name',
              hint: 'MEROUANESAT',
              icon: Icons.badge_outlined,
            ),
            _field(
              controller: _m3uUrl,
              label: 'M3U Playlist URL',
              hint: ref.tr('addSource.m3uHint'),
              icon: Icons.link,
              isUrl: true,
            ),
            _field(
              controller: _m3uEpg,
              label: 'EPG URL',
              icon: Icons.calendar_today,
              isUrl: true,
            ),
          ],
        ),
      );

  Widget _directTab() => SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            _field(
              controller: _directName,
              label: 'Profile Name',
              hint: 'MEROUANESAT',
              icon: Icons.badge_outlined,
            ),
            _field(
              controller: _directUrl,
              label: 'Stream URL',
              hint: ref.tr('addSource.streamHint'),
              icon: Icons.link,
              isUrl: true,
            ),
          ],
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    bool isUrl = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DpadTextField(
        child: TextField(
          controller: controller,
          obscureText: obscure && _hidePassword,
          style: const TextStyle(color: Colors.white),
          keyboardType: isUrl
              ? TextInputType.url
              : TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          enableInteractiveSelection: true,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle:
                const TextStyle(color: Colors.white70),
            hintStyle:
                const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF171717),
            prefixIcon: Icon(icon, color: gold),
            suffixIcon: obscure
                ? IconButton(
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: gold,
                    ),
                    onPressed: () {
                      setState(() {
                        _hidePassword = !_hidePassword;
                      });
                    },
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF65542C),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: gold,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
