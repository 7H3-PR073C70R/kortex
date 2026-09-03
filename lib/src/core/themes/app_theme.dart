import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/themes/color/app_material_colors.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/enums/theme_preset.dart';
import 'package:kortex/src/core/themes/typography/typography.dart';

/// Central theme configuration for Kortex (Engine: Syllabot).
///
/// Provides factory constructors for Light, Dark, Midnight OLED,
/// and dynamic customizable preset themes.
class AppTheme {
  const AppTheme._();

  // ---------------------------------------------------------------------------
  // Backwards-Compatible Static Getters
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme => getLightTheme();
  static ThemeData get darkTheme => getDarkTheme();

  // ---------------------------------------------------------------------------
  // Clean Light Theme Factory
  // ---------------------------------------------------------------------------
  static ThemeData getLightTheme({Color? customSeedColor}) {
    final colors = AppThemeColorsExtension.light(
      primaryAccent: customSeedColor,
    );
    final typography = TypographyThemeExtension.standard();

    return _buildThemeData(
      brightness: Brightness.light,
      colors: colors,
      typography: typography,
      overlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  // ---------------------------------------------------------------------------
  // Dark Theme Factory (Slate Dark or Midnight OLED)
  // ---------------------------------------------------------------------------
  static ThemeData getDarkTheme({
    Color? customSeedColor,
    bool isOled = false,
  }) {
    final colors = isOled
        ? AppThemeColorsExtension.oled(primaryAccent: customSeedColor)
        : AppThemeColorsExtension.dark(primaryAccent: customSeedColor);
    final typography = TypographyThemeExtension.standard();

    return _buildThemeData(
      brightness: Brightness.dark,
      colors: colors,
      typography: typography,
      overlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ---------------------------------------------------------------------------
  // Theme by Preset Factory
  // ---------------------------------------------------------------------------
  static ThemeData getThemeByPreset(
    ThemePreset preset, {
    Color? customSeedColor,
  }) {
    final colors = AppThemeColorsExtension.fromPreset(
      preset,
      customAccent: customSeedColor,
    );
    final typography = TypographyThemeExtension.standard();

    return _buildThemeData(
      brightness: preset.isDark ? Brightness.dark : Brightness.light,
      colors: colors,
      typography: typography,
      overlayStyle: preset.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  // ---------------------------------------------------------------------------
  // Custom Dynamic Theme Factory
  // ---------------------------------------------------------------------------
  static ThemeData getCustomTheme({
    required Color primaryAccent,
    required bool isDark,
    bool isOled = false,
  }) {
    final colors = isDark
        ? (isOled
              ? AppThemeColorsExtension.oled(primaryAccent: primaryAccent)
              : AppThemeColorsExtension.dark(primaryAccent: primaryAccent))
        : AppThemeColorsExtension.light(primaryAccent: primaryAccent);
    final typography = TypographyThemeExtension.standard();

    return _buildThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      colors: colors,
      typography: typography,
      overlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal Theme Builder
  // ---------------------------------------------------------------------------
  static ThemeData _buildThemeData({
    required Brightness brightness,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required SystemUiOverlayStyle overlayStyle,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.backgroundPrimary,
      canvasColor: colors.backgroundPrimary,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: colors.primary,
              onPrimary: AppMaterialColors.white,
              secondary: colors.syllabotAccent,
              onSecondary: AppMaterialColors.white,
              surface: colors.surfacePrimary,
              onSurface: colors.textPrimary,
              error: colors.error,
              onError: AppMaterialColors.white,
              outline: colors.surfaceBorder,
              outlineVariant: colors.surfaceBorderHighlight,
            )
          : ColorScheme.light(
              primary: colors.primary,
              onPrimary: AppMaterialColors.white,
              secondary: colors.syllabotAccent,
              onSecondary: AppMaterialColors.white,
              surface: colors.surfacePrimary,
              onSurface: colors.textPrimary,
              error: colors.error,
              onError: AppMaterialColors.white,
              outline: colors.surfaceBorder,
              outlineVariant: colors.surfaceBorderHighlight,
            ),
      textTheme: typography.toTextTheme(defaultColor: colors.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfacePrimary,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
        centerTitle: false,
        titleTextStyle: typography.headline.bold.copyWith(
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.surfaceBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSecondary,
        hintStyle: typography.callout.regular.copyWith(
          color: colors.textMuted,
        ),
        errorStyle: typography.caption.regular.copyWith(
          color: colors.error,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.error,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: AppMaterialColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: typography.subhead.semiBold,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: typography.subhead.semiBold,
          side: BorderSide(color: colors.surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: typography.subhead.semiBold,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfacePrimary,
        elevation: 0,
        indicatorColor: colors.primary.withAlpha(40),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? typography.caption.semiBold.copyWith(color: colors.primary)
              : typography.caption.medium.copyWith(color: colors.textMuted),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.surfaceBorder,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfacePrimary,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfacePrimary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.surfaceBorder),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: AppMaterialColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      extensions: [
        typography,
        colors,
      ],
    );
  }
}
