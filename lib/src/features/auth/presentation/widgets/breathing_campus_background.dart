import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';

/// Animated breathing campus background image with subtle scale oscillation
/// and balanced contrast scrim for light and dark themes.
class BreathingCampusBackground extends HookWidget {
  const BreathingCampusBackground({
    super.key,
    this.baseOpacity,
  });

  final double? baseOpacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final controller = useAnimationController(
      duration: const Duration(seconds: 9),
    );

    useEffect(
      () {
        unawaited(controller.repeat(reverse: true));
        return null;
      },
      const [],
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + (0.05 * controller.value);
        final dynamicOpacity =
            (baseOpacity ?? (isDark ? 0.65 : 0.85)) + (0.04 * controller.value);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Scaled breathing campus background image
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: dynamicOpacity.clamp(0.0, 1.0),
                child: Image(
                  image: AppAssets.images.campusStudentBg.provider(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),

            // Ambient balanced scrim with clear visibility in both modes
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    if (isDark) ...[
                      Colors.black.withAlpha(90),
                      colors.surfacePrimary.withAlpha(160),
                    ] else ...[
                      colors.surfacePrimary.withAlpha(40),
                      colors.surfacePrimary.withAlpha(100),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
