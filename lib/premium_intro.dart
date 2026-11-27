
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

const _gold = Color(0xFFD4AF37);
const _light = Color(0xFFFFEAB0);

class PremiumIntro extends StatefulWidget {
  final Widget child;

  const PremiumIntro({
    super.key,
    required this.child,
  });

  @override
  State<PremiumIntro> createState() =>
      _PremiumIntroState();
}

class _PremiumIntroState extends State<PremiumIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final _finished = Completer<void>();

  bool _visible = true;
  bool _started = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
      animationBehavior: AnimationBehavior.preserve,
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_visible) return;

      _fallback = Timer(
        const Duration(seconds: 2),
        _startAnimation,
      );

      unawaited(_playMusic());
    });
  }

  void _startAnimation() {
    if (!mounted || !_visible) return;

    _fallback?.cancel();

    if (!_controller.isAnimating &&
        _controller.value == 0) {
      _controller.forward();
    }
  }

  Future<void> _playMusic() async {
    Player? player;

    try {
      final audio = Player();
      player = audio;

      await audio.open(
        Media('asset:///assets/icon/premium_cinema.mp3'),
        play: false,
      );

      await audio.setVolume(75);

      if (!mounted ||
          !_visible ||
          _controller.value > 0.08) {
        return;
      }

      _startAnimation();

      await audio.play();
      await _finished.future;
    } catch (_) {
      _startAnimation();
    } finally {
      try {
        await player?.dispose();
      } catch (_) {}
    }
  }

  void _finish() {
    if (!mounted || !_visible) return;

    _fallback?.cancel();
    _controller.stop();

    if (!_finished.isCompleted) {
      _finished.complete();
    }

    setState(() => _visible = false);
  }

  @override
  void dispose() {
    _fallback?.cancel();

    if (!_finished.isCompleted) {
      _finished.complete();
    }

    _controller.dispose();
    super.dispose();
  }

  double phase(double t, double a, double b) {
    return ((t - a) / (b - a))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  Widget metalText(
    String value,
    double size,
    double sweep, {
    double spacing = 1.2,
  }) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment(sweep - 1, -1),
          end: Alignment(sweep + 1, 1),
          colors: const [
            Color(0xFF805415),
            Color(0xFFD4AF37),
            Color(0xFFFFF3D1),
            Colors.white,
            Color(0xFFC59630),
            Color(0xFF805415),
          ],
        ).createShader(rect);
      },
      child: Text(
        value,
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: spacing,
        ),
      ),
    );
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
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 10;

              final logo = Curves.easeOutCubic.transform(
                phase(t, 1.0, 3.4),
              );

              final name = Curves.easeOutCubic.transform(
                phase(t, 3.0, 5.1),
              );

              final premium = Curves.easeOutCubic.transform(
                phase(t, 5.6, 7.1),
              );

              final beam = Curves.easeOutCubic.transform(
                phase(t, 4.4, 6.4),
              );

              final fade = 1 - phase(t, 9.2, 10);

              final sweep =
                  -3 + phase(t, 4, 8.7) * 6;

              return Opacity(
                opacity: fade,
                child: Material(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _CinemaLight(t),
                      ),

                      SafeArea(
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(24),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 680,
                                height: 470,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Opacity(
                                      opacity: logo,
                                      child: Transform.scale(
                                        scale:
                                            2.1 - logo * 1.1,
                                        child: Container(
                                          width: 142,
                                          height: 142,
                                          decoration:
                                              BoxDecoration(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(36),
                                            border: Border.all(
                                              color: _gold,
                                              width: 2.5,
                                            ),
                                            gradient:
                                                const LinearGradient(
                                              begin:
                                                  Alignment.topLeft,
                                              end:
                                                  Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF382810),
                                                Color(0xFF080808),
                                                Color(0xFF17120A),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _gold
                                                    .withValues(
                                                  alpha: logo * .4,
                                                ),
                                                blurRadius: 65,
                                                spreadRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 108,
                                            color: _light,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 42),

                                    Opacity(
                                      opacity: name,
                                      child: Transform.scale(
                                        scale:
                                            1.5 - name * .5,
                                        child: metalText(
                                          'MEROUANESAT',
                                          65,
                                          sweep,
                                          spacing: 2,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 18),

                                    Container(
                                      width: 630 * beam,
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
                                            color:
                                                _gold.withValues(
                                              alpha: beam * .65,
                                            ),
                                            blurRadius: 30,
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
                                          22 * (1 - premium),
                                        ),
                                        child: metalText(
                                          'PREMIUM',
                                          35,
                                          sweep,
                                          spacing: 15,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 30),

                                    Opacity(
                                      opacity: premium,
                                      child: const Text(
                                        'BEYOND ENTERTAINMENT',
                                        textDirection:
                                            TextDirection.ltr,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 15,
                                          letterSpacing: 5,
                                          fontWeight:
                                              FontWeight.w500,
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
                        right: 16,
                        bottom: 12,
                        child: SafeArea(
                          child: TextButton.icon(
                            autofocus: true,
                            onPressed: _finish,
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: _gold,
                            ),
                            label: const Text(
                              'Skip intro',
                              style: TextStyle(
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _CinemaLight extends CustomPainter {
  final double time;

  _CinemaLight(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final center = size.center(Offset.zero);
    final rect = Offset.zero & size;

    final radius = size.longestSide * .7;

    final impact =
        math.exp(-math.pow((time - 6.4) / .5, 2));

    final glow =
        (.08 + impact * .18).toDouble();

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _gold.withValues(alpha: glow),
            Colors.black,
          ],
        ).createShader(rect),
    );

    final random = math.Random(37);

    for (int i = 0; i < 100; i++) {
      final angle =
          random.nextDouble() * math.pi * 2;

      final seed = random.nextDouble();
      final speed =
          .12 + random.nextDouble() * .18;

      final p =
          (seed + time * speed) % 1.0;

      final distance =
          (1 - p) * radius;

      final direction = Offset(
        math.cos(angle),
        math.sin(angle),
      );

      final head =
          center + direction * distance;

      final tail = center +
          direction *
              (distance + 8 + 60 * (1 - p));

      final opacity =
          (math.sin(p * math.pi) * .42)
              .clamp(0.0, 1.0)
              .toDouble();

      final paint = Paint()
        ..strokeWidth =
            .5 + random.nextDouble() * 1.6
        ..strokeCap = StrokeCap.round
        ..color = _gold.withValues(
          alpha: opacity,
        );

      canvas.drawLine(head, tail, paint);
    }

    final orbitOpacity =
        (math.sin(time / 10 * math.pi) * .20)
            .clamp(0.0, 1.0)
            .toDouble();

    for (int i = 0; i < 3; i++) {
      final orbit =
          size.shortestSide * (.30 + i * .09);

      final oval = Rect.fromCenter(
        center: center,
        width: orbit * 2,
        height: orbit * .9,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(
        time * .12 + i * math.pi / 3,
      );
      canvas.translate(-center.dx, -center.dy);

      canvas.drawArc(
        oval,
        time * .65 + i,
        math.pi * 1.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _gold.withValues(
            alpha: orbitOpacity,
          ),
      );

      canvas.restore();
    }

    final lineAlpha =
        (impact * .55).toDouble();

    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: size.width,
        height: 2,
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _gold.withValues(alpha: lineAlpha),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(
    covariant _CinemaLight oldDelegate,
  ) {
    return oldDelegate.time != time;
  }
}
