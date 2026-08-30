import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_material_colors.dart';

@immutable
class AppThemeColorsExtension extends ThemeExtension<AppThemeColorsExtension> {
  const AppThemeColorsExtension({
    required this.primary,
    required this.syllabotAccent,
    required this.latexHighlight,
    required this.flashcardMastered,
    required this.flashcardReview,
    required this.flashcardLearning,
    required this.confidenceHigh,
    required this.confidenceMed,
    required this.confidenceLow,
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceTertiary,
    required this.surfaceBorder,
    required this.surfaceBorderHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.gray,
    required this.white,
    required this.black,
  });

  /// Light theme color configuration
  factory AppThemeColorsExtension.light() {
    return AppThemeColorsExtension(
      primary: AppMaterialColors.primaryBase,
      syllabotAccent: AppMaterialColors.syllabotBase,
      latexHighlight: AppMaterialColors.latexBase,
      flashcardMastered: AppMaterialColors.masteredBase,
      flashcardReview: AppMaterialColors.reviewBase,
      flashcardLearning: AppMaterialColors.learningBase,
      confidenceHigh: AppMaterialColors.masteredBase,
      confidenceMed: AppMaterialColors.reviewBase,
      confidenceLow: AppMaterialColors.learningBase,
      backgroundPrimary: AppMaterialColors.lightCanvas,
      backgroundSecondary: AppMaterialColors.lightSurfaceElevated2,
      surfacePrimary: AppMaterialColors.lightSurfaceElevated1,
      surfaceSecondary: AppMaterialColors.lightSurfaceElevated2,
      surfaceTertiary: AppMaterialColors.lightSurfaceElevated3,
      surfaceBorder: AppMaterialColors.lightBorder,
      surfaceBorderHighlight: AppMaterialColors.lightBorderHighlight,
      textPrimary: AppMaterialColors.textLightPrimary,
      textSecondary: AppMaterialColors.textLightSecondary,
      textMuted: AppMaterialColors.textLightMuted,
      success: AppMaterialColors.masteredBase,
      warning: AppMaterialColors.reviewBase,
      error: AppMaterialColors.learningBase,
      info: AppMaterialColors.latexBase,
      gray: AppMaterialColors.gray,
      white: const Color(0xFFFFFFFF),
      black: const Color(0xFF000000),
    );
  }

  /// OLED dark theme color configuration
  factory AppThemeColorsExtension.dark() {
    return AppThemeColorsExtension(
      primary: AppMaterialColors.primaryBase,
      syllabotAccent: AppMaterialColors.syllabotBase,
      latexHighlight: AppMaterialColors.latexBase,
      flashcardMastered: AppMaterialColors.masteredBase,
      flashcardReview: AppMaterialColors.reviewBase,
      flashcardLearning: AppMaterialColors.learningBase,
      confidenceHigh: AppMaterialColors.masteredBase,
      confidenceMed: AppMaterialColors.reviewBase,
      confidenceLow: AppMaterialColors.learningBase,
      backgroundPrimary: AppMaterialColors.darkCanvas,
      backgroundSecondary: AppMaterialColors.darkSurfaceElevated1,
      surfacePrimary: AppMaterialColors.darkSurfaceElevated1,
      surfaceSecondary: AppMaterialColors.darkSurfaceElevated2,
      surfaceTertiary: AppMaterialColors.darkSurfaceElevated3,
      surfaceBorder: AppMaterialColors.darkBorder,
      surfaceBorderHighlight: AppMaterialColors.darkBorderHighlight,
      textPrimary: AppMaterialColors.textDarkPrimary,
      textSecondary: AppMaterialColors.textDarkSecondary,
      textMuted: AppMaterialColors.textDarkMuted,
      success: AppMaterialColors.masteredBase,
      warning: AppMaterialColors.reviewBase,
      error: AppMaterialColors.learningBase,
      info: AppMaterialColors.latexBase,
      gray: AppMaterialColors.gray,
      white: const Color(0xFFFFFFFF),
      black: const Color(0xFF000000),
    );
  }

  // STEM and Syllabot Engine tokens
  final Color primary;
  final Color syllabotAccent;
  final Color latexHighlight;
  final Color flashcardMastered;
  final Color flashcardReview;
  final Color flashcardLearning;
  final Color confidenceHigh;
  final Color confidenceMed;
  final Color confidenceLow;

  // Surfaces & Borders
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceTertiary;
  final Color surfaceBorder;
  final Color surfaceBorderHighlight;

  // Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Status & Feedback
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Convenience & Shared
  final MaterialColor gray;
  final Color white;
  final Color black;

  @override
  AppThemeColorsExtension copyWith({
    Color? primary,
    Color? syllabotAccent,
    Color? latexHighlight,
    Color? flashcardMastered,
    Color? flashcardReview,
    Color? flashcardLearning,
    Color? confidenceHigh,
    Color? confidenceMed,
    Color? confidenceLow,
    Color? backgroundPrimary,
    Color? backgroundSecondary,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceTertiary,
    Color? surfaceBorder,
    Color? surfaceBorderHighlight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    MaterialColor? gray,
    Color? white,
    Color? black,
  }) {
    return AppThemeColorsExtension(
      primary: primary ?? this.primary,
      syllabotAccent: syllabotAccent ?? this.syllabotAccent,
      latexHighlight: latexHighlight ?? this.latexHighlight,
      flashcardMastered: flashcardMastered ?? this.flashcardMastered,
      flashcardReview: flashcardReview ?? this.flashcardReview,
      flashcardLearning: flashcardLearning ?? this.flashcardLearning,
      confidenceHigh: confidenceHigh ?? this.confidenceHigh,
      confidenceMed: confidenceMed ?? this.confidenceMed,
      confidenceLow: confidenceLow ?? this.confidenceLow,
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceTertiary: surfaceTertiary ?? this.surfaceTertiary,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      surfaceBorderHighlight:
          surfaceBorderHighlight ?? this.surfaceBorderHighlight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      gray: gray ?? this.gray,
      white: white ?? this.white,
      black: black ?? this.black,
    );
  }

  @override
  ThemeExtension<AppThemeColorsExtension> lerp(
    ThemeExtension<AppThemeColorsExtension>? other,
    double t,
  ) {
    if (other is! AppThemeColorsExtension) return this;
    return AppThemeColorsExtension(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      syllabotAccent:
          Color.lerp(syllabotAccent, other.syllabotAccent, t) ?? syllabotAccent,
      latexHighlight:
          Color.lerp(latexHighlight, other.latexHighlight, t) ?? latexHighlight,
      flashcardMastered:
          Color.lerp(flashcardMastered, other.flashcardMastered, t) ??
              flashcardMastered,
      flashcardReview:
          Color.lerp(flashcardReview, other.flashcardReview, t) ??
              flashcardReview,
      flashcardLearning:
          Color.lerp(flashcardLearning, other.flashcardLearning, t) ??
              flashcardLearning,
      confidenceHigh:
          Color.lerp(confidenceHigh, other.confidenceHigh, t) ?? confidenceHigh,
      confidenceMed:
          Color.lerp(confidenceMed, other.confidenceMed, t) ?? confidenceMed,
      confidenceLow:
          Color.lerp(confidenceLow, other.confidenceLow, t) ?? confidenceLow,
      backgroundPrimary:
          Color.lerp(backgroundPrimary, other.backgroundPrimary, t) ??
              backgroundPrimary,
      backgroundSecondary:
          Color.lerp(backgroundSecondary, other.backgroundSecondary, t) ??
              backgroundSecondary,
      surfacePrimary:
          Color.lerp(surfacePrimary, other.surfacePrimary, t) ?? surfacePrimary,
      surfaceSecondary:
          Color.lerp(surfaceSecondary, other.surfaceSecondary, t) ??
              surfaceSecondary,
      surfaceTertiary:
          Color.lerp(surfaceTertiary, other.surfaceTertiary, t) ??
              surfaceTertiary,
      surfaceBorder:
          Color.lerp(surfaceBorder, other.surfaceBorder, t) ?? surfaceBorder,
      surfaceBorderHighlight:
          Color.lerp(surfaceBorderHighlight, other.surfaceBorderHighlight, t) ??
              surfaceBorderHighlight,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      info: Color.lerp(info, other.info, t) ?? info,
      gray: _lerpMaterialColor(gray, other.gray, t),
      white: Color.lerp(white, other.white, t) ?? white,
      black: Color.lerp(black, other.black, t) ?? black,
    );
  }

  static MaterialColor _lerpMaterialColor(
    MaterialColor a,
    MaterialColor b,
    double t,
  ) {
    return MaterialColor(
      400,
      {
        50: Color.lerp(a[50], b[50], t) ?? a,
        for (int shade = 100; shade <= 900; shade += 100)
          shade: Color.lerp(a[shade], b[shade], t) ?? a,
      },
    );
  }
}
