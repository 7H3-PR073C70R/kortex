import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';

/// Unique, iconic Syllabot AI avatar mascot with vibrant ambient glow,
/// and live animated unhappy/sad distress state on errors.
class SyllabotAvatar extends StatelessWidget {
  const SyllabotAvatar({
    super.key,
    this.size = 38,
    this.isError = false,
  });

  final double size;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    if (isError) {
      return _UnhappySyllabot(size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.syllabotAccent.withAlpha(isDark ? 220 : 180),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.syllabotAccent.withAlpha(isDark ? 110 : 70),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Image(
          image: AppAssets.images.syllabotAvatar.provider(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: colors.primary.withAlpha(isDark ? 80 : 40),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_awesome,
              size: size * 0.55,
              color: colors.syllabotAccent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Live animated unhappy Syllabot robot mascot with distressed wobble,
/// pulsing alert beacon, blinking sad LED eyes, and an animated cyber tear.
class _UnhappySyllabot extends HookWidget {
  const _UnhappySyllabot({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    // 1. Distress subtle head shake / sigh controller
    final wobbleController = useAnimationController(
      duration: const Duration(milliseconds: 2400),
    );

    // 2. Alert beacon pulse controller
    final beaconController = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );

    // 3. Blinking and tear animation controller
    final blinkController = useAnimationController(
      duration: const Duration(milliseconds: 3200),
    );

    useEffect(
      () {
        unawaited(wobbleController.repeat(reverse: true));
        unawaited(beaconController.repeat(reverse: true));
        unawaited(blinkController.repeat());
        return null;
      },
      const [],
    );

    return AnimatedBuilder(
      animation: Listenable.merge([
        wobbleController,
        beaconController,
        blinkController,
      ]),
      builder: (context, child) {
        // Calculate gentle distressed head tilt (-2.5 to +2.5 degrees)
        final wobbleVal = math.sin(wobbleController.value * math.pi * 2);
        final rotation = wobbleVal * 0.05;

        // Calculate beacon glow intensity
        final beaconGlow = beaconController.value;

        // Calculate blink curve (quick close/open in last 15% of duration)
        final blinkProgress = blinkController.value;
        var blinkAmount = 0.0;
        if (blinkProgress > 0.85 && blinkProgress < 0.95) {
          final t = (blinkProgress - 0.85) / 0.10;
          blinkAmount = math.sin(t * math.pi);
        }

        // Tear animation runs in first 60% of duration
        final tearProgress = (blinkProgress / 0.60).clamp(0.0, 1.0);

        return Transform.rotate(
          angle: rotation,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B0F19),
              border: Border.all(
                color: const Color(0xFFEF4444),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFEF4444,
                  ).withAlpha((100 + (beaconGlow * 80)).toInt()),
                  blurRadius: 12 + (beaconGlow * 4),
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Top Alert Beacon Light
                Positioned(
                  top: -2.5,
                  child: Container(
                    width: size * 0.20,
                    height: size * 0.14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFEF4444,
                          ).withAlpha((140 + (beaconGlow * 115)).toInt()),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

                // Center Visor & Sad LED Face
                ClipOval(
                  child: Container(
                    width: size * 0.82,
                    height: size * 0.82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF1E1B4B).withAlpha(240),
                          const Color(0xFF020617),
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _UnhappyFacePainter(
                        blinkProgress: blinkAmount,
                        tearProgress: tearProgress,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UnhappyFacePainter extends CustomPainter {
  const _UnhappyFacePainter({
    required this.blinkProgress,
    required this.tearProgress,
    required this.isDark,
  });

  final double blinkProgress;
  final double tearProgress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintEye = Paint()
      ..color = const Color(0xFFF87171)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;

    final paintMouth = Paint()
      ..color = const Color(0xFFFCA5A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round;

    final eyeOpen = (1.0 - blinkProgress).clamp(0.05, 1.0);

    // 1. Left sad/worried eye
    final leftPath = Path()
      ..moveTo(w * 0.24, h * 0.46)
      ..quadraticBezierTo(
        w * 0.35,
        h * (0.34 + (0.12 * (1.0 - eyeOpen))),
        w * 0.44,
        h * 0.40,
      );
    canvas.drawPath(leftPath, paintEye);

    // 2. Right sad/worried eye
    final rightPath = Path()
      ..moveTo(w * 0.56, h * 0.40)
      ..quadraticBezierTo(
        w * 0.65,
        h * (0.34 + (0.12 * (1.0 - eyeOpen))),
        w * 0.76,
        h * 0.46,
      );
    canvas.drawPath(rightPath, paintEye);

    // 3. Sad downturned mouth
    final mouthPath = Path()
      ..moveTo(w * 0.36, h * 0.72)
      ..quadraticBezierTo(
        w * 0.50,
        h * 0.61,
        w * 0.64,
        h * 0.72,
      );
    canvas.drawPath(mouthPath, paintMouth);

    // 4. Animated Cybernetic Tear / Sweat droplet
    if (tearProgress > 0.08 && tearProgress < 0.92) {
      final tearY = h * (0.46 + tearProgress * 0.26);
      final tearAlpha = (math.sin(tearProgress * math.pi) * 255).toInt().clamp(
        0,
        255,
      );
      final paintTear = Paint()
        ..color = const Color(0xFF38BDF8).withAlpha(tearAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(w * 0.77, tearY), w * 0.055, paintTear);
    }
  }

  @override
  bool shouldRepaint(covariant _UnhappyFacePainter oldDelegate) {
    return oldDelegate.blinkProgress != blinkProgress ||
        oldDelegate.tearProgress != tearProgress ||
        oldDelegate.isDark != isDark;
  }
}
