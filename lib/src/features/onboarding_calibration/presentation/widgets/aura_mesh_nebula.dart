import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/auth/presentation/widgets/breathing_campus_background.dart';

/// A deep, slow-pulsing Aura Mesh Nebula combining Indigo, Violet,
/// and Cyan gradients into an ambient edge-to-edge backdrop.
class AuraMeshNebula extends StatefulWidget {
  const AuraMeshNebula({
    required this.child,
    this.showBackgroundImage = false,
    super.key,
  });

  final Widget child;
  final bool showBackgroundImage;

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
        // 1. Solid surface background or Campus Background Atmosphere
        if (widget.showBackgroundImage)
          const Positioned.fill(
            child: BreathingCampusBackground(),
          )
        else ...[
          Positioned.fill(
            child: Container(
              color: colors.surfacePrimary,
            ),
          ),

          // 2. Animated Mesh Nebula Painter (only when
          // showBackgroundImage is false)
          if (!disableAnimations)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _NebulaMeshPainter(
                    progress: _controller.value,
                    themeColors: colors,
                    isDark: isDark,
                  ),
                );
              },
            )
          else
            CustomPaint(
              painter: _NebulaMeshPainter(
                progress: 0.5,
                themeColors: colors,
                isDark: isDark,
              ),
            ),
        ],

        // Foreground Content
        widget.child,
      ],
    );
  }
}

class _NebulaMeshPainter extends CustomPainter {
  _NebulaMeshPainter({
    required this.progress,
    required this.themeColors,
    required this.isDark,
  });

  final double progress;
  final AppThemeColorsExtension themeColors;
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
      ..shader =
          RadialGradient(
            colors: [
              themeColors.primary.withAlpha(isDark ? 85 : 45),
              themeColors.primary.withAlpha(isDark ? 30 : 15),
              themeColors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: center1, radius: size.width * 0.7),
          );
    canvas.drawCircle(center1, size.width * 0.7, paint1);

    // Orb 2: Syllabot Cyan / Violet Pulse
    final paint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              themeColors.syllabotAccent.withAlpha(isDark ? 70 : 35),
              themeColors.syllabotAccent.withAlpha(isDark ? 25 : 10),
              themeColors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(center: center2, radius: size.width * 0.65),
          );
    canvas.drawCircle(center2, size.width * 0.65, paint2);

    // Orb 3: Deep Ambient Core
    final paint3 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              themeColors.secondary.withAlpha(isDark ? 60 : 30),
              themeColors.transparent,
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
        oldDelegate.isDark != isDark ||
        oldDelegate.themeColors != themeColors;
  }
}
