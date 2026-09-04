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
        final effectiveBase = baseOpacity ?? (isDark ? 0.55 : 0.68);
        final dynamicOpacity = effectiveBase + (0.03 * controller.value);
        final bgImageProvider = isDark
            ? AppAssets.images.campusStudentBg.provider()
            : AppAssets.images.campusLightBg.provider();

        return Stack(
          fit: StackFit.expand,
          children: [
            // Base surface foundation
            Container(
              color: colors.surfacePrimary,
            ),

            // Scaled breathing campus background image
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: dynamicOpacity.clamp(0.0, 1.0),
                child: Image(
                  image: bgImageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),

            // Ambient balanced scrim ensuring crystal-clear text readability
            // and visible backdrop.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    if (isDark) ...[
                      colors.black.withAlpha(120),
                      colors.surfacePrimary.withAlpha(180),
                      colors.surfacePrimary.withAlpha(235),
                    ] else ...[
                      colors.surfacePrimary.withAlpha(60),
                      colors.surfacePrimary.withAlpha(115),
                      colors.surfacePrimary.withAlpha(175),
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
