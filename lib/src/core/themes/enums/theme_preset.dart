// ignore_for_file: deprecated_member_use_from_same_package -- Retained for legacy theme preset compatibility.

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

  /// Deep STEM Alpine Moss green focus preset.
  alpineMoss,

  /// Academic Sandstone / Warm Ochre preset.
  warmOchre,

  /// Editorial Amber / Deep Bronze preset.
  deepBronze,

  /// Slate Terracotta / Contrast Warmth preset.
  slateTerracotta,

  /// Quartz Cyan / Muted LaTeX Ink preset.
  quartzCyan,

  /// STEM-inspired Emerald / Mint active focus theme (Legacy alias).
  @Deprecated('Use alpineMoss instead')
  emeraldStem,

  /// Royal Amethyst theme (Legacy alias).
  @Deprecated('Use deepBronze instead')
  royalAmethyst,
  ;

  /// User-friendly label for settings UI.
  String get displayName {
    switch (this) {
      case ThemePreset.cleanLight:
        return 'Clean Light';
      case ThemePreset.slateDark:
        return 'Slate Dark';
      case ThemePreset.midnightOled:
        return 'Midnight OLED';
      case ThemePreset.alpineMoss:
        return 'Alpine Moss';
      case ThemePreset.warmOchre:
        return 'Warm Ochre';
      case ThemePreset.deepBronze:
        return 'Deep Bronze';
      case ThemePreset.slateTerracotta:
        return 'Slate Terracotta';
      case ThemePreset.quartzCyan:
        return 'Quartz Cyan';
      case ThemePreset.emeraldStem:
        return 'Emerald Focus';
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
      case ThemePreset.alpineMoss:
      case ThemePreset.warmOchre:
      case ThemePreset.deepBronze:
      case ThemePreset.slateTerracotta:
      case ThemePreset.quartzCyan:
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
        return AppMaterialColors.primaryBase;
      case ThemePreset.alpineMoss:
      case ThemePreset.emeraldStem:
        return AppMaterialColors.alpineMoss;
      case ThemePreset.warmOchre:
        return AppMaterialColors.warmOchre;
      case ThemePreset.deepBronze:
      case ThemePreset.royalAmethyst:
        return AppMaterialColors.deepBronze;
      case ThemePreset.slateTerracotta:
        return AppMaterialColors.slateTerracotta;
      case ThemePreset.quartzCyan:
        return AppMaterialColors.quartzCyan;
    }
  }
}
