
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
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
        return _CinemaIntro(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

// MEROUANESAT CINEMATIC INTRO V2

const _gold = Color(0xFFD4AF37);
const _lightGold = Color(0xFFFFE9A3);

class _CinemaIntro extends StatefulWidget {
  final Widget child;

  const _CinemaIntro({
    required this.child,
  });

  @override
  State<_CinemaIntro> createState() =>
      _CinemaIntroState();
}

class _CinemaIntroState extends State<_CinemaIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final Completer<void> _stopAudio = Completer<void>();

  bool _visible = true;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _controller.addStatusListener((status) {
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

      _controller.forward();
      unawaited(_playMusic());
    });
  }

  void _finish() {
    if (!mounted || !_visible) return;

    _controller.stop();

    if (!_stopAudio.isCompleted) {
      _stopAudio.complete();
    }

    setState(() => _visible = false);
  }

  @override
  void dispose() {
    if (!_stopAudio.isCompleted) {
      _stopAudio.complete();
    }

    _controller.dispose();
    super.dispose();
  }

  Future<void> _playMusic() async {
    Player? player;
    Directory? folder;

    try {
      final wav = await compute(_cinematicMusic, 0);

      if (!mounted || _stopAudio.isCompleted) return;

      final temp = await getTemporaryDirectory();

      folder = await temp.createTemp(
        'merouanesat_cinema_',
      );

      final file = File(
        '${folder.path}/cinematic_intro.wav',
      );

      await file.writeAsBytes(wav);

      if (!mounted || _stopAudio.isCompleted) return;

      final audio = Player();
      player = audio;

      await audio.open(
        Media(file.uri.toString()),
        play: false,
      );

      await audio.setVolume(75.0);

      if (!mounted || _stopAudio.isCompleted) return;

      await audio.play();
      await _stopAudio.future;
    } catch (_) {
      // Audio failure must not prevent app startup.
    } finally {
      try {
        await player?.dispose();
      } catch (_) {}

      try {
        await folder?.delete(recursive: true);
      } catch (_) {}
    }
  }

  double _phase(double t, double a, double b) {
    return ((t - a) / (b - a))
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
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value * 8;

                final logo = Curves.easeOutCubic.transform(
                  _phase(t, 1.0, 3.2),
                );

                final brand = Curves.easeOutCubic.transform(
                  _phase(t, 2.8, 4.8),
                );

                final premium = Curves.easeOutCubic.transform(
                  _phase(t, 5.0, 6.5),
                );

                final beam = Curves.easeOutCubic.transform(
                  _phase(t, 3.6, 5.6),
                );

                final fade =
                    1.0 - _phase(t, 7.3, 8.0);

                final sweep =
                    -3.0 + _phase(t, 3.2, 6.5) * 6.0;

                final pulse =
                    math.sin(t * 1.8).abs();

                return Opacity(
                  opacity: fade,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.85,
                            colors: [
                              _gold.withValues(
                                alpha: 0.10 + logo * 0.10,
                              ),
                              Colors.black,
                            ],
                          ),
                        ),
                      ),

                      CustomPaint(
                        painter: _GoldParticles(t),
                      ),

                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 480,
                              child: Column(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: logo,
                                    child: Transform.scale(
                                      scale:
                                          1.65 - logo * 0.65,
                                      child: Container(
                                        width: 135,
                                        height: 135,
                                        decoration:
                                            BoxDecoration(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(34),
                                          gradient:
                                              const LinearGradient(
                                            begin:
                                                Alignment.topLeft,
                                            end:
                                                Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF302310),
                                              Color(0xFF080808),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: _gold,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _gold
                                                  .withValues(
                                                alpha:
                                                    0.2 + pulse * 0.3,
                                              ),
                                              blurRadius:
                                                  35 + pulse * 35,
                                              spreadRadius: 3,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: _lightGold,
                                          size: 98,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 42),

                                  Opacity(
                                    opacity: brand,
                                    child: Transform.scale(
                                      scale:
                                          1.3 - brand * 0.3,
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
                                              Color(0xFF967020),
                                              _gold,
                                              _lightGold,
                                              Colors.white,
                                              _gold,
                                              Color(0xFF967020),
                                            ],
                                          ).createShader(rect);
                                        },
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'MEROUANESAT',
                                            maxLines: 1,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 52,
                                              fontWeight:
                                                  FontWeight.w900,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 22),

                                  Container(
                                    width: 440 * beam,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient:
                                          const LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          _gold,
                                          Colors.white,
                                          _gold,
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _gold.withValues(
                                            alpha: beam * 0.65,
                                          ),
                                          blurRadius: 24,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  Opacity(
                                    opacity: premium,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        18 * (1 - premium),
                                      ),
                                      child: const Text(
                                        'P R E M I U M',
                                        style: TextStyle(
                                          color: _lightGold,
                                          fontSize: 28,
                                          fontWeight:
                                              FontWeight.w700,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  Opacity(
                                    opacity: premium,
                                    child: const Text(
                                      'THE ULTIMATE CINEMA EXPERIENCE',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 10,
                        right: 14,
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
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// Animated golden particles

class _GoldParticles extends CustomPainter {
  final double time;

  _GoldParticles(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(2026);
    final paint = Paint();

    for (var i = 0; i < 65; i++) {
      final x = random.nextDouble() * size.width;
      final base = random.nextDouble() * size.height;
      final speed = 12 + random.nextDouble() * 30;

      final y =
          (base - time * speed) % size.height;

      final radius =
          0.5 + random.nextDouble() * 1.8;

      final alpha =
          (0.12 +
                  math.sin(time * 2 + i).abs() * 0.35)
              .clamp(0.0, 1.0)
              .toDouble();

      paint.color = _gold.withValues(alpha: alpha);

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoldParticles old) {
    return old.time != time;
  }
}

// Original cinematic soundtrack.
// Bass, percussion, rising chords and metallic notes.

Uint8List _cinematicMusic(int seed) {
  const rate = 22050;
  const duration = 8.0;
  const tau = math.pi * 2;

  final samples = (rate * duration).round();
  final data = ByteData(44 + samples * 2);

  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);

  final random = math.Random(seed + 2026);

  const drums = [
    0.5, 1.4, 2.1, 2.8,
    3.3, 3.8, 4.3, 4.8,
    5.3, 5.7, 6.1, 6.6,
  ];

  const chords = [
    [110.0, 130.81, 164.81],
    [87.31, 130.81, 174.61],
    [98.0, 146.83, 196.0],
    [110.0, 164.81, 220.0],
  ];

  const melody = [
    220.0, 261.63, 329.63, 392.0,
    440.0, 523.25, 659.25, 880.0,
  ];

  for (var i = 0; i < samples; i++) {
    final t = i / rate;
    final noise = random.nextDouble() * 2 - 1;

    final rise =
        (t / 6.5).clamp(0.0, 1.0).toDouble();

    final fadeIn =
        (t / 0.35).clamp(0.0, 1.0).toDouble();

    final fadeOut =
        ((duration - t) / 1.0)
            .clamp(0.0, 1.0)
            .toDouble();

    double value = 0;

    // Deep cinematic bass.

    value += math.sin(tau * 55 * t) *
        (0.08 + rise * 0.10);

    value += math.sin(tau * 27.5 * t) *
        rise * 0.06;

    // Layered harmonic pads.

    final chordIndex =
        (t / 2).floor().clamp(0, 3).toInt();

    final chordTime = t % 2.0;

    final chordEnvelope =
        math.sin(math.pi * chordTime / 2.0);

    for (final f in chords[chordIndex]) {
      value += (
        math.sin(tau * f * t) +
        0.35 * math.sin(tau * f * 2 * t) +
        0.18 * math.sin(tau * f * 3 * t)
      ) * chordEnvelope * (0.035 + rise * 0.02);
    }

    // Cinematic percussion.

    for (final hit in drums) {
      final x = t - hit;

      if (x >= 0 && x < 0.55) {
        final envelope = math.exp(-x * 10);

        final phase = tau * (
          45 * x +
          5 * (1 - math.exp(-x * 18))
        );

        value += math.sin(phase) *
            envelope * (0.18 + rise * 0.13);

        value += noise *
            math.exp(-x * 24) * 0.055;
      }
    }

    // Rising metallic arpeggio.

    for (var n = 0; n < melody.length; n++) {
      final start = 1.7 + n * 0.62;
      final x = t - start;

      if (x >= 0 && x < 1.5) {
        final attack =
            (x / 0.045).clamp(0.0, 1.0).toDouble();

        final decay = math.exp(-x * 3.0);
        final f = melody[n];

        value += (
          math.sin(tau * f * x) +
          0.30 * math.sin(tau * f * 2 * x) +
          0.12 * math.sin(tau * f * 4 * x)
        ) * attack * decay * 0.10;
      }
    }

    // Rising sound effect.

    if (t > 3.2 && t < 6.6) {
      final x = t - 3.2;

      final envelope =
          math.sin(math.pi * x / 3.4);

      value += noise * envelope * 0.035;

      value += math.sin(
        tau * (80 * x + 65 * x * x),
      ) * envelope * 0.035;
    }

    // Final cinematic impact.

    final finalHit = t - 6.6;

    if (finalHit >= 0) {
      final envelope =
          math.exp(-finalHit * 2.8);

      value += math.sin(tau * 42 * finalHit) *
          envelope * 0.30;

      value += noise *
          math.exp(-finalHit * 12) * 0.13;

      for (final f in [110.0, 164.81, 220.0, 440.0]) {
        value += math.sin(tau * f * finalHit) *
            envelope * 0.045;
      }
    }

    // Soft limiting to reduce clipping.

    value = value / (1 + value.abs() * 0.5);
    value *= fadeIn * fadeOut;

    final sample = (value * 32767)
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
