import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';

/// Callback signature for spawning a reaction particle.
typedef FloatingReactionCallback =
    void Function(
      String emoji, {
      Offset? startOffset,
    });

/// Controller to programmatically spawn floating reaction emojis on the overlay.
class FloatingReactionController {
  FloatingReactionCallback? _onSpawn;
  void Function(List<String> emojis, {Offset? startOffset})? _onSpawnMultiple;

  /// Attaches the overlay's spawn callback.
  void attach(
    FloatingReactionCallback callback, {
    void Function(List<String> emojis, {Offset? startOffset})? onSpawnMultiple,
  }) {
    _onSpawn = callback;
    _onSpawnMultiple = onSpawnMultiple;
  }

  /// Detaches the current callback when disposed.
  void detach() {
    _onSpawn = null;
    _onSpawnMultiple = null;
  }

  /// Spawns a floating reaction with classical drifting, scaling, and fading.
  void spawn(String emoji, {Offset? startOffset}) {
    _onSpawn?.call(emoji, startOffset: startOffset);
  }

  /// Spawns multiple floating reaction emojis with micro-staggered timing.
  void spawnMultiple(List<String> emojis, {Offset? startOffset}) {
    if (_onSpawnMultiple != null) {
      _onSpawnMultiple?.call(emojis, startOffset: startOffset);
    } else {
      for (final e in emojis) {
        spawn(e, startOffset: startOffset);
      }
    }
  }
}

/// A particle representation for a floating emoji.
class _ReactionParticle {
  _ReactionParticle({
    required this.id,
    required this.emoji,
    required this.startX,
    required this.startY,
    required this.amplitude,
    required this.frequency,
    required this.driftX,
    required this.scale,
    required this.maxRotation,
    required this.controller,
  });

  final int id;
  final String emoji;
  final double startX;
  final double startY;
  final double amplitude;
  final double frequency;
  final double driftX;
  final double scale;
  final double maxRotation;
  final AnimationController controller;
}

/// Classical floating reaction overlay that renders rising, swaying emojis.
class FloatingReactionOverlay extends StatefulWidget {
  const FloatingReactionOverlay({
    required this.child,
    this.controller,
    super.key,
  });

  final Widget child;
  final FloatingReactionController? controller;

  @override
  State<FloatingReactionOverlay> createState() =>
      _FloatingReactionOverlayState();
}

class _FloatingReactionOverlayState extends State<FloatingReactionOverlay>
    with TickerProviderStateMixin {
  final List<_ReactionParticle> _particles = [];
  final math.Random _random = math.Random();
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(spawn, onSpawnMultiple: spawnMultiple);
  }

  @override
  void didUpdateWidget(FloatingReactionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(spawn, onSpawnMultiple: spawnMultiple);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    for (final p in _particles) {
      p.controller.dispose();
    }
    _particles.clear();
    super.dispose();
  }

  void spawnMultiple(List<String> emojis, {Offset? startOffset}) {
    if (!mounted || emojis.isEmpty) return;

    for (var i = 0; i < emojis.length; i++) {
      final emoji = emojis[i];
      final delayMs = i * 75;
      if (delayMs == 0) {
        spawn(emoji, startOffset: startOffset);
      } else {
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (mounted) {
            spawn(emoji, startOffset: startOffset);
          }
        });
      }
    }
  }

  void spawn(String emoji, {Offset? startOffset}) {
    if (!mounted) return;

    // Cap max active particles to prevent performance degradation
    if (_particles.length >= 35) {
      final oldest = _particles.removeAt(0);
      oldest.controller.dispose();
    }

    final durationMs = 2000 + _random.nextInt(600); // 2.0s to 2.6s
    final animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 375.0;
    final screenHeight = MediaQuery.maybeOf(context)?.size.height ?? 812.0;

    // Base position: bottom center-right if not specified
    final defaultX =
        startOffset?.dx ??
        (screenWidth * 0.5 + (_random.nextDouble() * 80 - 40));
    final defaultY = startOffset?.dy ?? (screenHeight * 0.78);

    final particle = _ReactionParticle(
      id: _nextId++,
      emoji: emoji,
      startX: defaultX,
      startY: defaultY,
      amplitude: 16.0 + _random.nextDouble() * 24.0, // horizontal sway
      frequency: 2.0 + _random.nextDouble() * 2.0, // wave oscillations
      driftX: (_random.nextDouble() - 0.5) * 60.0, // overall left/right drift
      scale: 0.9 + _random.nextDouble() * 0.45, // size variation
      maxRotation:
          (_random.nextDouble() - 0.5) * 0.35, // subtle tilt in radians
      controller: animController,
    );

    animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _particles.removeWhere((p) => p.id == particle.id);
          });
        }
        animController.dispose();
      }
    });

    setState(() {
      _particles.add(particle);
    });

    unawaited(animController.forward());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _particles.isEmpty
                  ? null
                  : _ReactionCanvasPainter(
                      typography: context.typography,
                      particles: _particles,
                      shadowColor: context.colors.black,
                      repaint: Listenable.merge(
                        _particles.map((p) => p.controller).toList(),
                      ),
                    ),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }
}

/// Efficient CustomPainter that draws floating emoji glyphs with classical easing
class _ReactionCanvasPainter extends CustomPainter {
  _ReactionCanvasPainter({
    required this.typography,
    required this.particles,
    required this.shadowColor,
    required super.repaint,
  });

  final TypographyThemeExtension typography;
  final List<_ReactionParticle> particles;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = p.controller.value;
      if (progress <= 0.0 || progress >= 1.0) continue;

      // Vertical movement: ease-out cubic rising with zero paint-loop allocation
      final riseDist = size.height * 0.42;
      final curvedProgress = Curves.easeOutCubic.transform(progress);
      final currentY = p.startY - (curvedProgress * riseDist);

      // Horizontal movement: drift + sinusoidal wave
      final sway = math.sin(progress * p.frequency * math.pi) * p.amplitude;
      final currentX = p.startX + (p.driftX * progress) + sway;

      // Scale: pop in smoothly (0.0 -> 0.2: 0 to 1.2), then settle to 1.0
      var currentScale = p.scale;
      if (progress < 0.2) {
        currentScale *= progress / 0.2 * 1.2;
      } else if (progress < 0.35) {
        currentScale *= 1.2 - ((progress - 0.2) / 0.15 * 0.2);
      }

      // Opacity: fade out smoothly in the last 30% of lifetime
      final opacity = progress > 0.70
          ? ((1.0 - progress) / 0.30).clamp(0.0, 1.0)
          : 1.0;

      // Subtle rotation along sway
      final rotation =
          math.sin(progress * p.frequency * math.pi) * p.maxRotation;

      final textPainter = TextPainter(
        text: TextSpan(
          text: p.emoji,
          style: typography.body.regular.copyWith(
            fontSize: 32.0 * currentScale,
            shadows: [
              Shadow(
                color: shadowColor.withValues(alpha: 0.25 * opacity),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas
        ..save()
        ..translate(currentX, currentY)
        ..rotate(rotation);

      final paintAlpha = (opacity * 255).round().clamp(0, 255);
      if (paintAlpha < 255) {
        canvas.saveLayer(
          Rect.fromLTWH(
            -textPainter.width / 2,
            -textPainter.height / 2,
            textPainter.width,
            textPainter.height,
          ),
          Paint()..color = Color.fromARGB(paintAlpha, 255, 255, 255),
        );
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
      } else {
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ReactionCanvasPainter oldDelegate) => true;
}
