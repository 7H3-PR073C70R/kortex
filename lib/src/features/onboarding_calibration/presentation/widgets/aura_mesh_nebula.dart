import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// A deep, slow-pulsing Aura Mesh Nebula combining Indigo, Violet,
/// and Cyan gradients into an ambient edge-to-edge backdrop.
class AuraMeshNebula extends StatefulWidget {
  const AuraMeshNebula({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AuraMeshNebula> createState() => _AuraMeshNebulaState();
}

class _AuraMeshNebulaState extends State<AuraMeshNebula>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Solid Surface Base
        Container(color: colors.surfacePrimary),

        // Animated Mesh Nebula Painter
        if (!disableAnimations)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _NebulaMeshPainter(
                  progress: _controller.value,
                  primary: colors.primary,
                  accent: colors.syllabotAccent,
                  isDark: isDark,
                ),
              );
            },
          )
        else
          CustomPaint(
            painter: _NebulaMeshPainter(
              progress: 0.5,
              primary: colors.primary,
              accent: colors.syllabotAccent,
              isDark: isDark,
            ),
          ),

        // Foreground Content
        widget.child,
      ],
    );
  }
}

class _NebulaMeshPainter extends CustomPainter {
  _NebulaMeshPainter({
    required this.progress,
    required this.primary,
    required this.accent,
    required this.isDark,
  });

  final double progress;
  final Color primary;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center1 = Offset(
      size.width * (0.25 + 0.15 * math.sin(progress * math.pi * 2)),
      size.height * (0.2 + 0.1 * math.cos(progress * math.pi * 2)),
    );

    final center2 = Offset(
      size.width * (0.75 - 0.15 * math.cos(progress * math.pi * 2)),
      size.height * (0.65 + 0.12 * math.sin(progress * math.pi * 2)),
    );

    final center3 = Offset(
      size.width * (0.5 + 0.2 * math.sin(progress * math.pi)),
      size.height * (0.85 - 0.1 * math.cos(progress * math.pi)),
    );

    // Orb 1: Primary Indigo Glow
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withAlpha(isDark ? 85 : 45),
          primary.withAlpha(isDark ? 30 : 15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: center1, radius: size.width * 0.7),
      );
    canvas.drawCircle(center1, size.width * 0.7, paint1);

    // Orb 2: Syllabot Cyan / Violet Pulse
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withAlpha(isDark ? 70 : 35),
          accent.withAlpha(isDark ? 25 : 10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: center2, radius: size.width * 0.65),
      );
    canvas.drawCircle(center2, size.width * 0.65, paint2);

    // Orb 3: Deep Ambient Core
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6366F1).withAlpha(isDark ? 60 : 30),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(center: center3, radius: size.width * 0.55),
      );
    canvas.drawCircle(center3, size.width * 0.55, paint3);
  }

  @override
  bool shouldRepaint(covariant _NebulaMeshPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.accent != accent ||
        oldDelegate.isDark != isDark;
  }
}
