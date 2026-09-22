import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';

/// Animated breathing campus background.
///
/// The raw campus photo is far too busy to sit directly behind UI — its
/// bright windows and fine detail turn translucent buttons into mush and
/// make text hard to read. So this backdrop does three things:
///
///  1. Blurs the photo into a soft, even wash (the "weird" busy texture is
///     gone) while keeping a gentle breathing scale for life.
///  2. Lays a legibility veil on top whose tone is chosen for whatever sits
///     above it: a light, near-uniform veil when the foreground uses dark
///     text (mobile auth, biometric lock, calibration), or a dark cinematic
///     gradient when the foreground uses light text (the desktop hero).
///  3. Honors "reduce motion" by freezing the breath.
class BreathingCampusBackground extends HookWidget {
  const BreathingCampusBackground({
    super.key,
    this.baseOpacity,
    this.foregroundIsLight = false,
    this.blurSigma = 8,
  });

  /// Photo opacity before the veil. Defaults keep the image recessive.
  final double? baseOpacity;

  /// Set true when light/white content sits on top (e.g. the desktop hero),
  /// so a dark veil is used instead of a light one.
  final bool foregroundIsLight;

  /// Gaussian blur applied to the photo. Higher = smoother, less detail.
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final controller = useAnimationController(
      duration: const Duration(seconds: 9),
    );

    useEffect(
      () {
        if (disableAnimations) {
          controller.value = 0;
          return null;
        }
        unawaited(controller.repeat(reverse: true));
        return null;
      },
      [disableAnimations],
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = disableAnimations ? 0.0 : controller.value;
        final scale = 1.0 + (0.05 * t);
        final effectiveBase =
            baseOpacity ??
            (isDark
                ? 0.82
                : foregroundIsLight
                ? 0.8
                : 0.85);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Base surface foundation.
            Container(color: colors.surfacePrimary),

            // Soft, breathing campus photo — blurred into an even wash.
            // The RepaintBoundary lets the blur be computed once and only
            // re-transformed per frame, keeping the animation cheap.
            Transform.scale(
              scale: scale,
              child: RepaintBoundary(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                    tileMode: ui.TileMode.decal,
                  ),
                  child: Opacity(
                    opacity: effectiveBase.clamp(0.0, 1.0),
                    child: Image(
                      image: isDark
                          ? AppAssets.images.campusStudentBg.provider()
                          : AppAssets.images.campusLightBg.provider(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),

            // Legibility veil — tone chosen for the foreground content.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: _veilFor(colors, isDark, foregroundIsLight),
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ],
        );
      },
    );
  }

  static List<Color> _veilFor(
    AppThemeColorsExtension colors,
    bool isDark,
    bool foregroundIsLight,
  ) {
    if (foregroundIsLight) {
      // Dark cinematic gradient so white hero text stays crisp, while still
      // letting the campus photo read through.
      return [
        colors.black.withAlpha(120),
        colors.black.withAlpha(140),
        colors.black.withAlpha(185),
      ];
    }
    if (isDark) {
      // Light text over a darkened, still-recognizable photo.
      return [
        colors.black.withAlpha(60),
        colors.surfacePrimary.withAlpha(130),
        colors.surfacePrimary.withAlpha(195),
      ];
    }
    // Light mode, dark text: a light veil that stays translucent up top so
    // the photo is clearly visible, and firms up toward the bottom where the
    // buttons sit so they keep a clean, even backdrop.
    return [
      colors.surfacePrimary.withAlpha(45),
      colors.surfacePrimary.withAlpha(110),
      colors.surfacePrimary.withAlpha(185),
    ];
  }
}
