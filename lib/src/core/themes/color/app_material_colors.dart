import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/color_extension.dart';

/// Design tokens and Material color definitions for Kortex (Engine: Syllabot).
///
/// Designed with the 60-30-10 rule for STEM edtech:
/// - 60% Surfaces & Canvas: Slate-Charcoal (Dark) / Crisp Off-White (Light)
/// - 30% Structural Hierarchy: Cards, Borders, Glass Layers, Elevated Surfaces
/// - 10% Accents & Feedback: Electric Indigo, Syllabot Violet, Color-blind Safe
class AppMaterialColors {
  const AppMaterialColors._();

  // ---------------------------------------------------------------------------
  // Brand & Engine Primary Accents
  // ---------------------------------------------------------------------------
  /// Deep Electric Indigo - evokes deep focus, intelligence, and neural clarity
  static const Color primaryBase = Color(0xFF4361EE);
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

  /// Syllabot AI Accent (Electric Violet) - dedicated to AI actions, OCR & RAG
  static const Color syllabotBase = Color(0xFF8B5CF6);
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

  /// STEM / LaTeX Highlight (Cyan Ice) - mathematical symbols & code formulas
  static const Color latexBase = Color(0xFF06B6D4);
  static MaterialColor latex = latexBase.toMaterialColor(
    shade50: const Color(0xFFECFEFF),
    shade100: const Color(0xFFCFFAFE),
    shade400: const Color(0xFF22D3EE),
    shade500: latexBase,
    shade700: const Color(0xFF0E7490),
  );

  // ---------------------------------------------------------------------------
  // Color-Blind Safe Mastery & Retention Spaced-Repetition States
  // ---------------------------------------------------------------------------
  /// Mastered / Easy (Emerald Teal - Accessible Success)
  static const Color masteredBase = Color(0xFF10B981);
  static MaterialColor mastered = masteredBase.toMaterialColor(
    shade50: const Color(0xFFECFDF5),
    shade100: const Color(0xFFD1FAE5),
    shade400: const Color(0xFF34D399),
    shade500: masteredBase,
    shade700: const Color(0xFF047857),
  );

  /// Reviewing / Moderate (Warm Amber / Gold - Warning / Reinforce)
  static const Color reviewBase = Color(0xFFF59E0B);
  static MaterialColor review = reviewBase.toMaterialColor(
    shade50: const Color(0xFFFFFBEB),
    shade100: const Color(0xFFFEF3C7),
    shade400: const Color(0xFFFBBF24),
    shade500: reviewBase,
    shade700: const Color(0xFFB45309),
  );

  /// Learning / Hard (Coral Crimson - Immediate Attention)
  static const Color learningBase = Color(0xFFF43F5E);
  static MaterialColor learning = learningBase.toMaterialColor(
    shade50: const Color(0xFFFFF1F2),
    shade100: const Color(0xFFFFE4E6),
    shade400: const Color(0xFFFB7185),
    shade500: learningBase,
    shade700: const Color(0xFFBE123C),
  );

  // ---------------------------------------------------------------------------
  // OLED Dark Surfaces & Neutral Canvas (Low Eye-Strain for Night Sessions)
  // ---------------------------------------------------------------------------
  /// Deep Charcoal Base (Not harsh #000000, preserves contrast & OLED depth)
  static const Color darkCanvas = Color(0xFF090D16);
  static const Color darkSurfaceElevated1 = Color(0xFF111827);
  static const Color darkSurfaceElevated2 = Color(0xFF1F2937);
  static const Color darkSurfaceElevated3 = Color(0xFF374151);
  static const Color darkBorder = Color(0xFF263248);
  static const Color darkBorderHighlight = Color(0xFF3B4861);

  // ---------------------------------------------------------------------------
  // Clean Light Surfaces & Neutral Canvas (High Luminous Clarity)
  // ---------------------------------------------------------------------------
  static const Color lightCanvas = Color(0xFFF8FAFC);
  static const Color lightSurfaceElevated1 = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated2 = Color(0xFFF1F5F9);
  static const Color lightSurfaceElevated3 = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderHighlight = Color(0xFFCBD5E1);

  // ---------------------------------------------------------------------------
  // Typography Hierarchy Colors
  // ---------------------------------------------------------------------------
  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);
  static const Color textDarkMuted = Color(0xFF64748B);

  static const Color textLightPrimary = Color(0xFF0F172A);
  static const Color textLightSecondary = Color(0xFF475569);
  static const Color textLightMuted = Color(0xFF94A3B8);

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
