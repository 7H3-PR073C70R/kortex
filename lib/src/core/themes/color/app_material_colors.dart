import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/color_extension.dart';

/// Design tokens and Material color definitions for Kortex (Engine: Syllabot).
///
/// Provides rich palette definitions for Light, Dark, Midnight OLED,
/// and customizable STEM preset themes.
class AppMaterialColors {
  const AppMaterialColors._();

  // ---------------------------------------------------------------------------
  // Preset Accent Palettes
  // ---------------------------------------------------------------------------
  /// Academic Blue / Deep Electric Indigo (Default)
  static const Color academicBlue = Color(0xFF4361EE);

  /// Emerald STEM / Vibrant Mint
  static const Color emeraldStem = Color(0xFF10B981);

  /// Royal Amethyst / Syllabot AI Violet
  static const Color royalAmethyst = Color(0xFF8B5CF6);

  /// Rose Crimson / Focus Coral
  static const Color roseCrimson = Color(0xFFF43F5E);

  /// Amber Gold / Warm Academic Gold
  static const Color amberGold = Color(0xFFF59E0B);

  /// Cyan Ice / STEM LaTeX Cyan
  static const Color cyanIce = Color(0xFF06B6D4);

  // ---------------------------------------------------------------------------
  // Brand & Engine Primary Accents
  // ---------------------------------------------------------------------------
  static const Color primaryBase = academicBlue;
  static MaterialColor primary = primaryBase.toMaterialColor(
    shade50: const Color(0xFFEEF2FF),
    shade100: const Color(0xFFE0E7FF),
    shade200: const Color(0xFFC7D2FE),
    shade300: const Color(0xFFA5B4FC),
    shade400: const Color(0xFF818CF8),
    shade500: primaryBase,
    shade600: const Color(0xFF3730A3),
    shade700: const Color(0xFF312E81),
  );

  /// Syllabot AI Accent (Electric Violet)
  static const Color syllabotBase = royalAmethyst;
  static MaterialColor syllabot = syllabotBase.toMaterialColor(
    shade50: const Color(0xFFF5F3FF),
    shade100: const Color(0xFFEDE9FE),
    shade200: const Color(0xFFDDD6FE),
    shade300: const Color(0xFFC4B5FD),
    shade400: const Color(0xFFA78BFA),
    shade500: syllabotBase,
    shade600: const Color(0xFF7C3AED),
    shade700: const Color(0xFF6D28D9),
  );

  /// STEM / LaTeX Highlight (Cyan Ice)
  static const Color latexBase = cyanIce;
  static MaterialColor latex = latexBase.toMaterialColor(
    shade50: const Color(0xFFECFEFF),
    shade100: const Color(0xFFCFFAFE),
    shade400: const Color(0xFF22D3EE),
    shade500: latexBase,
    shade700: const Color(0xFF0E7490),
  );

  // ---------------------------------------------------------------------------
  // Active Recall & Spaced Repetition Tokens (Color-blind safe)
  // ---------------------------------------------------------------------------
  /// Mastered / Easy recall
  static const Color recallEasy = Color(0xFF10B981);

  /// Good / Standard recall
  static const Color recallGood = Color(0xFF06B6D4);

  /// Hard / Needs review
  static const Color recallHard = Color(0xFFF59E0B);

  /// Again / Failed recall
  static const Color recallAgain = Color(0xFFF43F5E);

  static const Color masteredBase = recallEasy;
  static MaterialColor mastered = masteredBase.toMaterialColor(
    shade50: const Color(0xFFECFDF5),
    shade100: const Color(0xFFD1FAE5),
    shade400: const Color(0xFF34D399),
    shade500: masteredBase,
    shade700: const Color(0xFF047857),
  );

  static const Color reviewBase = recallHard;
  static MaterialColor review = reviewBase.toMaterialColor(
    shade50: const Color(0xFFFFFBEB),
    shade100: const Color(0xFFFEF3C7),
    shade400: const Color(0xFFFBBF24),
    shade500: reviewBase,
    shade700: const Color(0xFFB45309),
  );

  static const Color learningBase = recallAgain;
  static MaterialColor learning = learningBase.toMaterialColor(
    shade50: const Color(0xFFFFF1F2),
    shade100: const Color(0xFFFFE4E6),
    shade400: const Color(0xFFFB7185),
    shade500: learningBase,
    shade700: const Color(0xFFBE123C),
  );

  // ---------------------------------------------------------------------------
  // Clean Light Surfaces & Palette
  // ---------------------------------------------------------------------------
  static const Color lightCanvas = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated1 = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated2 = Color(0xFFF1F5F9);
  static const Color lightSurfaceElevated3 = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderHighlight = Color(0xFFCBD5E1);

  static const Color textLightPrimary = Color(0xFF0F172A);
  static const Color textLightSecondary = Color(0xFF475569);
  static const Color textLightMuted = Color(0xFF94A3B8);

  // ---------------------------------------------------------------------------
  // Standard Slate Dark Surfaces & Palette (Low Eye-Strain)
  // ---------------------------------------------------------------------------
  static const Color darkCanvas = Color(0xFF090D16);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkSurfaceElevated1 = Color(0xFF111827);
  static const Color darkSurfaceElevated2 = Color(0xFF1F2937);
  static const Color darkSurfaceElevated3 = Color(0xFF374151);
  static const Color darkBorder = Color(0xFF263248);
  static const Color darkBorderHighlight = Color(0xFF3B4861);

  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);
  static const Color textDarkMuted = Color(0xFF64748B);

  // ---------------------------------------------------------------------------
  // Midnight OLED Surfaces & Palette (Pure #000000 True Black)
  // ---------------------------------------------------------------------------
  static const Color oledCanvas = Color(0xFF000000);
  static const Color oledCard = Color(0xFF0A0A0A);
  static const Color oledSurfaceElevated1 = Color(0xFF0A0A0A);
  static const Color oledSurfaceElevated2 = Color(0xFF141414);
  static const Color oledSurfaceElevated3 = Color(0xFF1F1F1F);
  static const Color oledBorder = Color(0xFF27272A);
  static const Color oledBorderHighlight = Color(0xFF3F3F46);

  static const Color textOledPrimary = Color(0xFFFFFFFF);
  static const Color textOledSecondary = Color(0xFFA1A1AA);
  static const Color textOledMuted = Color(0xFF71717A);

  // ---------------------------------------------------------------------------
  // Legacy / Common Material Helpers
  // ---------------------------------------------------------------------------
  static MaterialColor gray = const Color(0xFF64748B).toMaterialColor();
  static MaterialColor success = mastered;
  static MaterialColor error = learning;
  static MaterialColor warning = review;
  static MaterialColor info = latex;
  static MaterialColor white = const Color(0xFFFFFFFF).toMaterialColor();
  static MaterialColor black = const Color(0xFF000000).toMaterialColor();
  static MaterialColor disable = const Color(0xFF94A3B8).toMaterialColor();
}
