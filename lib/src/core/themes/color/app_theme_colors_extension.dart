import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_material_colors.dart';
import 'package:kortex/src/core/themes/enums/theme_preset.dart';

@immutable
class AppThemeColorsExtension extends ThemeExtension<AppThemeColorsExtension> {
  const AppThemeColorsExtension({
    required this.primary,
    required this.syllabotAccent,
    required this.syllabotGlow,
    required this.latexHighlight,
    required this.latexBackground,
    required this.recallEasy,
    required this.recallGood,
    required this.recallHard,
    required this.recallAgain,
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
    required this.surfaceElevated,
    required this.cardBackground,
    required this.surfaceBorder,
    required this.surfaceBorderHighlight,
    required this.borderOutline,
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
  factory AppThemeColorsExtension.light({Color? primaryAccent}) {
    final accent = primaryAccent ?? AppMaterialColors.academicBlue;
    return AppThemeColorsExtension(
      primary: accent,
      syllabotAccent: AppMaterialColors.syllabotBase,
      syllabotGlow: AppMaterialColors.syllabotBase.withAlpha(50),
      latexHighlight: AppMaterialColors.latexBase,
      latexBackground: AppMaterialColors.latexBase.withAlpha(25),
      recallEasy: AppMaterialColors.recallEasy,
      recallGood: AppMaterialColors.recallGood,
      recallHard: AppMaterialColors.recallHard,
      recallAgain: AppMaterialColors.recallAgain,
      flashcardMastered: AppMaterialColors.recallEasy,
      flashcardReview: AppMaterialColors.recallHard,
      flashcardLearning: AppMaterialColors.recallAgain,
      confidenceHigh: AppMaterialColors.recallEasy,
      confidenceMed: AppMaterialColors.recallHard,
      confidenceLow: AppMaterialColors.recallAgain,
      backgroundPrimary: AppMaterialColors.lightCanvas,
      backgroundSecondary: AppMaterialColors.lightSurfaceElevated2,
      surfacePrimary: AppMaterialColors.lightSurfaceElevated1,
      surfaceSecondary: AppMaterialColors.lightSurfaceElevated2,
      surfaceTertiary: AppMaterialColors.lightSurfaceElevated3,
      surfaceElevated: AppMaterialColors.lightSurfaceElevated1,
      cardBackground: AppMaterialColors.lightCard,
      surfaceBorder: AppMaterialColors.lightBorder,
      surfaceBorderHighlight: AppMaterialColors.lightBorderHighlight,
      borderOutline: AppMaterialColors.lightBorder,
      textPrimary: AppMaterialColors.textLightPrimary,
      textSecondary: AppMaterialColors.textLightSecondary,
      textMuted: AppMaterialColors.textLightMuted,
      success: AppMaterialColors.recallEasy,
      warning: AppMaterialColors.recallHard,
      error: AppMaterialColors.recallAgain,
      info: AppMaterialColors.latexBase,
      gray: AppMaterialColors.gray,
      white: const Color(0xFFFFFFFF),
      black: const Color(0xFF000000),
    );
  }

  /// Slate dark theme color configuration
  factory AppThemeColorsExtension.dark({Color? primaryAccent}) {
    final accent = primaryAccent ?? AppMaterialColors.academicBlue;
    return AppThemeColorsExtension(
      primary: accent,
      syllabotAccent: AppMaterialColors.syllabotBase,
      syllabotGlow: AppMaterialColors.syllabotBase.withAlpha(50),
      latexHighlight: AppMaterialColors.latexBase,
      latexBackground: AppMaterialColors.latexBase.withAlpha(35),
      recallEasy: AppMaterialColors.recallEasy,
      recallGood: AppMaterialColors.recallGood,
      recallHard: AppMaterialColors.recallHard,
      recallAgain: AppMaterialColors.recallAgain,
      flashcardMastered: AppMaterialColors.recallEasy,
      flashcardReview: AppMaterialColors.recallHard,
      flashcardLearning: AppMaterialColors.recallAgain,
      confidenceHigh: AppMaterialColors.recallEasy,
      confidenceMed: AppMaterialColors.recallHard,
      confidenceLow: AppMaterialColors.recallAgain,
      backgroundPrimary: AppMaterialColors.darkCanvas,
      backgroundSecondary: AppMaterialColors.darkSurfaceElevated1,
      surfacePrimary: AppMaterialColors.darkSurfaceElevated1,
      surfaceSecondary: AppMaterialColors.darkSurfaceElevated2,
      surfaceTertiary: AppMaterialColors.darkSurfaceElevated3,
      surfaceElevated: AppMaterialColors.darkSurfaceElevated2,
      cardBackground: AppMaterialColors.darkCard,
      surfaceBorder: AppMaterialColors.darkBorder,
      surfaceBorderHighlight: AppMaterialColors.darkBorderHighlight,
      borderOutline: AppMaterialColors.darkBorder,
      textPrimary: AppMaterialColors.textDarkPrimary,
      textSecondary: AppMaterialColors.textDarkSecondary,
      textMuted: AppMaterialColors.textDarkMuted,
      success: AppMaterialColors.recallEasy,
      warning: AppMaterialColors.recallHard,
      error: AppMaterialColors.recallAgain,
      info: AppMaterialColors.latexBase,
      gray: AppMaterialColors.gray,
      white: const Color(0xFFFFFFFF),
      black: const Color(0xFF000000),
    );
  }

  /// Midnight OLED pure #000000 black theme color configuration
  factory AppThemeColorsExtension.oled({Color? primaryAccent}) {
    final accent = primaryAccent ?? AppMaterialColors.academicBlue;
    return AppThemeColorsExtension(
      primary: accent,
      syllabotAccent: AppMaterialColors.syllabotBase,
      syllabotGlow: AppMaterialColors.syllabotBase.withAlpha(60),
      latexHighlight: AppMaterialColors.latexBase,
      latexBackground: AppMaterialColors.latexBase.withAlpha(40),
      recallEasy: AppMaterialColors.recallEasy,
      recallGood: AppMaterialColors.recallGood,
      recallHard: AppMaterialColors.recallHard,
      recallAgain: AppMaterialColors.recallAgain,
      flashcardMastered: AppMaterialColors.recallEasy,
      flashcardReview: AppMaterialColors.recallHard,
      flashcardLearning: AppMaterialColors.recallAgain,
      confidenceHigh: AppMaterialColors.recallEasy,
      confidenceMed: AppMaterialColors.recallHard,
      confidenceLow: AppMaterialColors.recallAgain,
      backgroundPrimary: AppMaterialColors.oledCanvas,
      backgroundSecondary: AppMaterialColors.oledSurfaceElevated1,
      surfacePrimary: AppMaterialColors.oledSurfaceElevated1,
      surfaceSecondary: AppMaterialColors.oledSurfaceElevated2,
      surfaceTertiary: AppMaterialColors.oledSurfaceElevated3,
      surfaceElevated: AppMaterialColors.oledSurfaceElevated2,
      cardBackground: AppMaterialColors.oledCard,
      surfaceBorder: AppMaterialColors.oledBorder,
      surfaceBorderHighlight: AppMaterialColors.oledBorderHighlight,
      borderOutline: AppMaterialColors.oledBorder,
      textPrimary: AppMaterialColors.textOledPrimary,
      textSecondary: AppMaterialColors.textOledSecondary,
      textMuted: AppMaterialColors.textOledMuted,
      success: AppMaterialColors.recallEasy,
      warning: AppMaterialColors.recallHard,
      error: AppMaterialColors.recallAgain,
      info: AppMaterialColors.latexBase,
      gray: AppMaterialColors.gray,
      white: const Color(0xFFFFFFFF),
      black: const Color(0xFF000000),
    );
  }

  /// Build theme colors based on a selected [ThemePreset].
  factory AppThemeColorsExtension.fromPreset(
    ThemePreset preset, {
    Color? customAccent,
  }) {
    final accent = customAccent ?? preset.defaultAccent;
    switch (preset) {
      case ThemePreset.cleanLight:
        return AppThemeColorsExtension.light(primaryAccent: accent);
      case ThemePreset.slateDark:
        return AppThemeColorsExtension.dark(primaryAccent: accent);
      case ThemePreset.midnightOled:
        return AppThemeColorsExtension.oled(primaryAccent: accent);
      case ThemePreset.emeraldStem:
        return AppThemeColorsExtension.dark(
          primaryAccent: customAccent ?? AppMaterialColors.emeraldStem,
        );
      case ThemePreset.royalAmethyst:
        return AppThemeColorsExtension.dark(
          primaryAccent: customAccent ?? AppMaterialColors.royalAmethyst,
        );
    }
  }

  // Brand & STEM Tokens
  final Color primary;
  final Color syllabotAccent;
  final Color syllabotGlow;
  final Color latexHighlight;
  final Color latexBackground;

  // Active Recall Tokens
  final Color recallEasy;
  final Color recallGood;
  final Color recallHard;
  final Color recallAgain;
  final Color flashcardMastered;
  final Color flashcardReview;
  final Color flashcardLearning;
  final Color confidenceHigh;
  final Color confidenceMed;
  final Color confidenceLow;

  // Surfaces & Structural Borders
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceTertiary;
  final Color surfaceElevated;
  final Color cardBackground;
  final Color surfaceBorder;
  final Color surfaceBorderHighlight;
  final Color borderOutline;

  // Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Status & Feedback
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Convenience
  final MaterialColor gray;
  final Color white;
  final Color black;

  @override
  AppThemeColorsExtension copyWith({
    Color? primary,
    Color? syllabotAccent,
    Color? syllabotGlow,
    Color? latexHighlight,
    Color? latexBackground,
    Color? recallEasy,
    Color? recallGood,
    Color? recallHard,
    Color? recallAgain,
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
    Color? surfaceElevated,
    Color? cardBackground,
    Color? surfaceBorder,
    Color? surfaceBorderHighlight,
    Color? borderOutline,
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
      syllabotGlow: syllabotGlow ?? this.syllabotGlow,
      latexHighlight: latexHighlight ?? this.latexHighlight,
      latexBackground: latexBackground ?? this.latexBackground,
      recallEasy: recallEasy ?? this.recallEasy,
      recallGood: recallGood ?? this.recallGood,
      recallHard: recallHard ?? this.recallHard,
      recallAgain: recallAgain ?? this.recallAgain,
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
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      cardBackground: cardBackground ?? this.cardBackground,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      surfaceBorderHighlight:
          surfaceBorderHighlight ?? this.surfaceBorderHighlight,
      borderOutline: borderOutline ?? this.borderOutline,
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
      syllabotGlow:
          Color.lerp(syllabotGlow, other.syllabotGlow, t) ?? syllabotGlow,
      latexHighlight:
          Color.lerp(latexHighlight, other.latexHighlight, t) ?? latexHighlight,
      latexBackground:
          Color.lerp(latexBackground, other.latexBackground, t) ??
              latexBackground,
      recallEasy: Color.lerp(recallEasy, other.recallEasy, t) ?? recallEasy,
      recallGood: Color.lerp(recallGood, other.recallGood, t) ?? recallGood,
      recallHard: Color.lerp(recallHard, other.recallHard, t) ?? recallHard,
      recallAgain: Color.lerp(recallAgain, other.recallAgain, t) ?? recallAgain,
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
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
              surfaceElevated,
      cardBackground:
          Color.lerp(cardBackground, other.cardBackground, t) ?? cardBackground,
      surfaceBorder:
          Color.lerp(surfaceBorder, other.surfaceBorder, t) ?? surfaceBorder,
      surfaceBorderHighlight:
          Color.lerp(surfaceBorderHighlight, other.surfaceBorderHighlight, t) ??
              surfaceBorderHighlight,
      borderOutline:
          Color.lerp(borderOutline, other.borderOutline, t) ?? borderOutline,
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
