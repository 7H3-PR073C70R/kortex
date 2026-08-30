import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/themes/enums/theme_preset.dart';

/// Immutable state encapsulating user theme preferences and computed ThemeData.
class ThemeState extends Equatable {
  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.preset = ThemePreset.slateDark,
    this.customAccentColor,
  });

  final ThemeMode themeMode;
  final ThemePreset preset;
  final Color? customAccentColor;

  /// Returns the configured light [ThemeData].
  ThemeData get lightTheme {
    return AppTheme.getLightTheme(
      customSeedColor: customAccentColor ?? preset.defaultAccent,
    );
  }

  /// Returns the configured dark [ThemeData] based on active preset.
  ThemeData get darkTheme {
    return AppTheme.getThemeByPreset(
      preset.isDark ? preset : ThemePreset.slateDark,
      customSeedColor: customAccentColor,
    );
  }

  /// Computes the active [ThemeData] for a given platform brightness.
  ThemeData currentTheme(Brightness platformBrightness) {
    switch (themeMode) {
      case ThemeMode.light:
        return lightTheme;
      case ThemeMode.dark:
        return darkTheme;
      case ThemeMode.system:
        return platformBrightness == Brightness.dark ? darkTheme : lightTheme;
    }
  }

  ThemeState copyWith({
    ThemeMode? themeMode,
    ThemePreset? preset,
    Color? Function()? customAccentColor,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      preset: preset ?? this.preset,
      customAccentColor: customAccentColor != null
          ? customAccentColor()
          : this.customAccentColor,
    );
  }

  @override
  List<Object?> get props => [themeMode, preset, customAccentColor];
}
