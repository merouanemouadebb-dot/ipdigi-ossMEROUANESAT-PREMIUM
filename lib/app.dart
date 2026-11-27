
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'core/config/app_config.dart';
import 'core/config/platform_info.dart';
import 'core/utils/orientation_lock.dart';
import 'core/router/app_router.dart';
import 'core/shutdown/shutdown_coordinator.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/epg/providers/epg_provider.dart';
import 'features/sources/providers/sources_provider.dart';

class IplifeApp extends ConsumerStatefulWidget {
  const IplifeApp({super.key});

  @override
  ConsumerState<IplifeApp> createState() =>
      _IplifeAppState();
}

class _IplifeAppState extends ConsumerState<IplifeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isTablet =
            MediaQuery.of(context).size.shortestSide >= 600;

        OrientationLock.browsing(
          isTablet: isTablet || PlatformInfo.isTv,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await ShutdownCoordinator.instance.runAll();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final isDark = ref.watch(themeProvider).value ?? true;

    ref.watch(sourceAutoRefreshProvider);
    ref.watch(epgProvider);
    ref.watch(epgAutoRefreshProvider);

    AppColors.setDark(isDark);

    return MaterialApp.router(
      title: AppConfig.I.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(isDark),
      routerConfig: router,
      builder: (context, child) {
        return _PremiumStartupIntro(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

// MEROUANESAT PREMIUM CINEMATIC INTRO

class _PremiumStartupIntro extends StatefulWidget {
  final Widget child;

  const _PremiumStartupIntro({
    required this.child,
  });

  @override
  State<_PremiumStartupIntro> createState() =>
      _PremiumStartupIntroState();
}

class _PremiumStartupIntroState
    extends State<_PremiumStartupIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  final Completer<void> _stopAudio =
      Completer<void>();

  bool _visible = true;
  bool _started = false;

  static const gold = Color(0xFFD4AF37);
  static const brightGold = Color(0xFFFFEDB0);

  @override
  void initState() {
    super.initState();

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _visible = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_visible) return;

      _animation.forward();
      unawaited(_playIntroSound());
    });
  }

  void _finish() {
    if (!mounted || !_visible) return;

    _animation.stop();

    if (!_stopAudio.isCompleted) {
      _stopAudio.complete();
    }

    setState(() {
      _visible = false;
    });
  }

  @override
  void dispose() {
    if (!_stopAudio.isCompleted) {
      _stopAudio.complete();
    }

    _animation.dispose();
    super.dispose();
  }

  // Original cinematic sound generated offline.

  Future<void> _playIntroSound() async {
    Player? player;
    Directory? folder;

    try {
      final cache = await getTemporaryDirectory();

      folder = await cache.createTemp(
        'merouanesat_intro_',
      );

      final file = File(
        '${folder.path}/premium_intro.wav',
      );

      await file.writeAsBytes(
        _generateMusic(),
      );

      if (!mounted || _stopAudio.isCompleted) return;

      final audio = Player();
      player = audio;

      await audio.open(
        Media(file.uri.toString()),
        play: false,
      );

      await audio.setVolume(45.0);

      if (!mounted || _stopAudio.isCompleted) return;

      await audio.play();

      await _stopAudio.future;
    } catch (_) {
      // Audio errors must never block app startup.
    } finally {
      try {
        if (player != null) {
          await player.dispose();
        }
      } catch (_) {}

      try {
        if (folder != null) {
          await folder.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Uint8List _generateMusic() {
    const sampleRate = 22050;
    const duration = 2.8;
    final samples = (sampleRate * duration).round();
    final data = ByteData(44 + samples * 2);

    void writeText(int offset, String value) {
      for (int i = 0; i < value.length; i++) {
        data.setUint8(
          offset + i,
          value.codeUnitAt(i),
        );
      }
    }

    writeText(0, 'RIFF');
    data.setUint32(4, 36 + samples * 2, Endian.little);
    writeText(8, 'WAVE');
    writeText(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeText(36, 'data');
    data.setUint32(40, samples * 2, Endian.little);

    double note(double t, double start, double freq) {
      final x = t - start;

      if (x < 0) return 0;

      final attack = math.min(1.0, x / 0.16);
      final decay = math.exp(-x * 1.7);

      return attack * decay * (
        math.sin(2 * math.pi * freq * x) +
        0.28 * math.sin(4 * math.pi * freq * x)
      );
    }

    for (int i = 0; i < samples; i++) {
      final t = i / sampleRate;

      final swell =
          math.sin(math.pi * t / duration);

      final bass =
          math.sin(2 * math.pi * 55 * t) *
          swell * 0.14;

      final harmony =
          note(t, 0.12, 220.0) * 0.12 +
          note(t, 0.48, 329.63) * 0.10 +
          note(t, 0.88, 554.37) * 0.08 +
          note(t, 1.28, 440.0) * 0.10;

      final fade =
          ((duration - t) / 0.5)
              .clamp(0.0, 1.0)
              .toDouble();

      final sample =
          ((bass + harmony) * fade * 32767)
              .round()
              .clamp(-32768, 32767)
              .toInt();

      data.setInt16(
        44 + i * 2,
        sample,
        Endian.little,
      );
    }

    return data.buffer.asUint8List();
  }

  double _progress(
    double value,
    double start,
    double end,
  ) {
    return ((value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _visible,
          child: IgnorePointer(
            ignoring: _visible,
            child: widget.child,
          ),
        ),

        if (_visible)
          Material(
            color: Colors.black,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final t = _animation.value;

                final reveal = Curves.easeOutCubic
                    .transform(
                      _progress(t, 0.04, 0.48),
                    );

                final lineProgress = Curves.easeOutCubic
                    .transform(
                      _progress(t, 0.20, 0.75),
                    );

                final premium = Curves.easeOut
                    .transform(
                      _progress(t, 0.38, 0.78),
                    );

                final fadeOut =
                    1 - _progress(t, 0.88, 1.0);

                final glow =
                    math.sin(t * math.pi);

                final sweep = -3.0 + t * 6.0;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.8,
                          colors: [
                            gold.withValues(
                              alpha: glow * 0.13,
                            ),
                            Colors.black,
                          ],
                        ),
                      ),
                    ),

                    Opacity(
                      opacity: fadeOut,
                      child: Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(24),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 320,
                              child: Column(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: reveal,
                                    child: Transform.scale(
                                      scale:
                                          1.12 - reveal * 0.12,
                                      child: Container(
                                        width: 96,
                                        height: 96,
                                        decoration:
                                            BoxDecoration(
                                          color: const Color(
                                            0xFF101010,
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(24),
                                          border: Border.all(
                                            color: gold,
                                            width: 1.6,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: gold
                                                  .withValues(
                                                alpha:
                                                    glow * 0.35,
                                              ),
                                              blurRadius:
                                                  35 + glow * 25,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 66,
                                          color: gold,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 36),

                                  Opacity(
                                    opacity: reveal,
                                    child: Transform.scale(
                                      scale:
                                          1.15 - reveal * 0.15,
                                      child: ShaderMask(
                                        blendMode:
                                            BlendMode.srcIn,
                                        shaderCallback: (rect) {
                                          return LinearGradient(
                                            begin: Alignment(
                                              sweep - 1,
                                              -1,
                                            ),
                                            end: Alignment(
                                              sweep + 1,
                                              1,
                                            ),
                                            colors: const [
                                              Color(0xFF9D721D),
                                              gold,
                                              brightGold,
                                              gold,
                                              Color(0xFF9D721D),
                                            ],
                                          ).createShader(rect);
                                        },
                                        child: const Text(
                                          'MEROUANESAT',
                                          maxLines: 1,
                                          textAlign:
                                              TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 34,
                                            fontWeight:
                                                FontWeight.w900,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  Container(
                                    width: 290 * lineProgress,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient:
                                          const LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          gold,
                                          brightGold,
                                          gold,
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: gold.withValues(
                                            alpha: glow * 0.5,
                                          ),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  Opacity(
                                    opacity: premium,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        12 * (1 - premium),
                                      ),
                                      child: const Text(
                                        'P R E M I U M',
                                        style: TextStyle(
                                          color: gold,
                                          fontSize: 21,
                                          fontWeight:
                                              FontWeight.w700,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 30),

                                  Opacity(
                                    opacity: premium,
                                    child: const Text(
                                      'THE CINEMA EXPERIENCE',
                                      textAlign:
                                          TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: SafeArea(
                        child: TextButton(
                          onPressed: _finish,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
