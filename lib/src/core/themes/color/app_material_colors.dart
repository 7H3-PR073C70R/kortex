import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/color_extension.dart';

/// Editorial & Organic Design Tokens for Kortex.
/// Eliminates all generic AI-generated aesthetics in favor of a boutique,
/// tactile, low-fatigue study environment.
class AppMaterialColors {
  const AppMaterialColors._();

  // ---------------------------------------------------------------------------
  // Boutique Preset Accent Palettes (Mineral & Earth Tones)
  // ---------------------------------------------------------------------------
  /// Muted Sage / Organic Focus (Default Brand)
  static const Color mutedSage = Color(0xFF788C7E);

  /// Warm Ochre / Academic Sandstone
  static const Color warmOchre = Color(0xFFD4A373);

  /// Deep Bronze / Editorial Amber
  static const Color deepBronze = Color(0xFFC69251);

  /// Slate Terracotta / Contrast Warmth
  static const Color slateTerracotta = Color(0xFFD97757);

  /// Alpine Moss / Deep STEM Green
  static const Color alpineMoss = Color(0xFF4A6B5D);

  /// Quartz Cyan / Muted LaTeX Ink
  static const Color quartzCyan = Color(0xFF5B8C93);

  // ---------------------------------------------------------------------------
  // Brand & Engine Primary Accents
  // ---------------------------------------------------------------------------
  static const Color primaryBase = mutedSage;
  static MaterialColor primary = primaryBase.toMaterialColor(
    shade50: const Color(0xFFF2F5F3),
    shade100: const Color(0xFFE3E8E5),
    shade200: const Color(0xFFC7D2CC),
    shade300: const Color(0xFFA5B8AE),
    shade400: const Color(0xFF8BA396),
    shade500: primaryBase,
    shade600: const Color(0xFF5F7065),
    shade700: const Color(0xFF4A574E),
  );

  /// Secondary Architectural Accent (Warm Ochre)
  static const Color secondaryBase = warmOchre;
  static MaterialColor secondary = secondaryBase.toMaterialColor(
    shade50: const Color(0xFFFAF6F0),
    shade100: const Color(0xFFF4EBE1),
    shade200: const Color(0xFFEAD8C2),
    shade300: const Color(0xFFDFC4A0),
    shade400: const Color(0xFFD4B389),
    shade500: secondaryBase,
    shade600: const Color(0xFFB88654),
    shade700: const Color(0xFF94693F),
  );

  /// STEM / LaTeX Highlight (Quartz Cyan)
  static const Color latexBase = quartzCyan;
  static MaterialColor latex = latexBase.toMaterialColor(
    shade50: const Color(0xFFF0F5F6),
    shade100: const Color(0xFFD9E7E9),
    shade400: const Color(0xFF75A3A9),
    shade500: latexBase,
    shade700: const Color(0xFF3F6166),
  );

  // ---------------------------------------------------------------------------
  // Active Recall & Spaced Repetition Tokens (Subdued & Human)
  // ---------------------------------------------------------------------------
  /// Mastered / Easy recall (Calm Alpine Green)
  static const Color recallEasy = Color(0xFF52796F);

  /// Good / Standard recall (Muted Teal)
  static const Color recallGood = Color(0xFF5B8C93);

  /// Hard / Needs review (Warm Ochre)
  static const Color recallHard = Color(0xFFD4A373);

  /// Again / Failed recall (Subdued Terracotta, not harsh neon red)
  static const Color recallAgain = Color(0xFFC86D51);

  static const Color masteredBase = recallEasy;
  static MaterialColor mastered = masteredBase.toMaterialColor(
    shade50: const Color(0xFFF1F5F3),
    shade100: const Color(0xFFE2EBE7),
    shade400: const Color(0xFF6B9A8E),
    shade500: masteredBase,
    shade700: const Color(0xFF3B564F),
  );

  static const Color reviewBase = recallHard;
  static MaterialColor review = reviewBase.toMaterialColor(
    shade50: const Color(0xFFFAF6F0),
    shade100: const Color(0xFFF4EBE1),
    shade400: const Color(0xFFE2B886),
    shade500: reviewBase,
    shade700: const Color(0xFFA87B49),
  );

  static const Color learningBase = recallAgain;
  static MaterialColor learning = learningBase.toMaterialColor(
    shade50: const Color(0xFFFAF2F0),
    shade100: const Color(0xFFF4E2DE),
    shade400: const Color(0xFFD98E7B),
    shade500: learningBase,
    shade700: const Color(0xFF9E4E37),
  );

  // ---------------------------------------------------------------------------
  // Editorial Light Surfaces & Palette
  // ---------------------------------------------------------------------------
  static const Color lightCanvas = Color(0xFFF6F6F8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated1 = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated2 = Color(0xFFECECEF);
  static const Color lightSurfaceElevated3 = Color(0xFFDDDDD2);
  static const Color lightBorder = Color(0xFFE2E2E6);
  static const Color lightBorderHighlight = Color(0xFFC8C8CD);

  static const Color textLightPrimary = Color(0xFF18181B);
  static const Color textLightSecondary = Color(0xFF52525B);
  static const Color textLightMuted = Color(0xFFA1A1AA);

  // ---------------------------------------------------------------------------
  // Deep Neutral Charcoal Dark Surfaces (Zero Blue-Cast)
  // ---------------------------------------------------------------------------
  static const Color darkCanvas = Color(0xFF0D0D0F); // Pure neutral carbon dark
  static const Color darkCard = Color(0xFF141417); // Warm, tactile dark surface
  static const Color darkSurfaceElevated1 = Color(0xFF141417);
  static const Color darkSurfaceElevated2 = Color(0xFF1D1D22);
  static const Color darkSurfaceElevated3 = Color(0xFF2B2B33);
  static const Color darkBorder = Color(0x1AFFFFFF); // 10% crisp white hairline
  static const Color darkBorderHighlight = Color(
    0x33FFFFFF,
  ); // 20% focus hairline

  static const Color textDarkPrimary = Color(0xFFFAFAFA);
  static const Color textDarkSecondary = Color(0xFFA1A1AA);
  static const Color textDarkMuted = Color(0xFF71717A);

  // ---------------------------------------------------------------------------
  // Midnight OLED Surfaces (True #000000 with Minimal Contrast Steps)
  // ---------------------------------------------------------------------------
  static const Color oledCanvas = Color(0xFF000000);
  static const Color oledCard = Color(0xFF09090B);
  static const Color oledSurfaceElevated1 = Color(0xFF09090B);
  static const Color oledSurfaceElevated2 = Color(0xFF121216);
  static const Color oledSurfaceElevated3 = Color(0xFF1C1C21);
  static const Color oledBorder = Color(0x22FFFFFF);
  static const Color oledBorderHighlight = Color(0x44FFFFFF);

  static const Color textOledPrimary = Color(0xFFFFFFFF);
  static const Color textOledSecondary = Color(0xFFF4F4F5);
  static const Color textOledMuted = Color(0xFFA1A1AA);

  // ---------------------------------------------------------------------------
  // Legacy / Common Material Helpers & Aliases
  // ---------------------------------------------------------------------------
  static const Color academicBlue = primaryBase;
  static const Color emeraldStem = alpineMoss;
  static const Color royalAmethyst = deepBronze;
  static const Color syllabotBase = secondaryBase;
  static MaterialColor syllabot = secondary;

  static MaterialColor gray = const Color(0xFF71717A).toMaterialColor();
  static MaterialColor success = mastered;
  static MaterialColor error = learning;
  static MaterialColor warning = review;
  static MaterialColor info = latex;
  static MaterialColor white = const Color(0xFFFFFFFF).toMaterialColor();
  static MaterialColor black = const Color(0xFF000000).toMaterialColor();
  static MaterialColor disable = const Color(0xFF71717A).toMaterialColor();
}
