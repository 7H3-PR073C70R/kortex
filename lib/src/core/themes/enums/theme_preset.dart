import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_material_colors.dart';

/// Available theme presets in Kortex.
enum ThemePreset {
  /// Clean high-contrast light mode with slate accents.
  cleanLight,

  /// Deep slate/charcoal dark mode engineered for low eye-strain.
  slateDark,

  /// Pure #000000 true black dark mode for OLED screens.
  midnightOled,

  /// STEM-inspired Emerald / Mint active focus theme.
  emeraldStem,

  /// Royal Amethyst / Syllabot AI electric violet theme.
  royalAmethyst;

  /// User-friendly label for settings UI.
  String get displayName {
    switch (this) {
      case ThemePreset.cleanLight:
        return 'Clean Light';
      case ThemePreset.slateDark:
        return 'Slate Dark';
      case ThemePreset.midnightOled:
        return 'Midnight OLED';
      case ThemePreset.emeraldStem:
        return 'Emerald STEM';
      case ThemePreset.royalAmethyst:
        return 'Royal Amethyst';
    }
  }

  /// Whether this preset is fundamentally a dark mode.
  bool get isDark {
    switch (this) {
      case ThemePreset.cleanLight:
        return false;
      case ThemePreset.slateDark:
      case ThemePreset.midnightOled:
      case ThemePreset.emeraldStem:
      case ThemePreset.royalAmethyst:
        return true;
    }
  }

  /// Whether this preset utilizes true OLED black surfaces.
  bool get isOled => this == ThemePreset.midnightOled;

  /// Default accent color associated with this preset.
  Color get defaultAccent {
    switch (this) {
      case ThemePreset.cleanLight:
      case ThemePreset.slateDark:
      case ThemePreset.midnightOled:
        return AppMaterialColors.academicBlue;
      case ThemePreset.emeraldStem:
        return AppMaterialColors.emeraldStem;
      case ThemePreset.royalAmethyst:
        return AppMaterialColors.royalAmethyst;
    }
  }
}
