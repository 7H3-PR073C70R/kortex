import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_material_colors.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        fontFamily: 'WorkSans',
        primaryColor: AppMaterialColors.primary,
        scaffoldBackgroundColor: AppMaterialColors.gray,
        appBarTheme: AppBarTheme(
          backgroundColor: AppMaterialColors.white,
          foregroundColor: AppMaterialColors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppMaterialColors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: AppMaterialColors.black),
        ),
        textTheme: const TextTheme().apply(
          displayColor: AppMaterialColors.black,
          bodyColor: AppMaterialColors.black,
          decorationColor: AppMaterialColors.black,
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: AppMaterialColors.gray,
          filled: true,
          hintStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppMaterialColors.gray,
          ),
          errorStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppMaterialColors.error,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 21, horizontal: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(27.5),
            borderSide: BorderSide(
              color: AppMaterialColors.gray,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(27.5),
            borderSide: BorderSide(
              color: AppMaterialColors.gray,
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(27.5),
            borderSide: BorderSide(
              color: AppMaterialColors.gray,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(27.5),
            borderSide: BorderSide(
              color: AppMaterialColors.error,
              width: 2,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: AppMaterialColors.black),
        colorScheme: ColorScheme.light(
          primary: AppMaterialColors.primary,
          secondary: AppMaterialColors.button,
          error: AppMaterialColors.error,
          onSecondary: AppMaterialColors.success,
          outline: AppMaterialColors.gray,
        ),
        extensions: [
          TypographyThemeExtension(
            body: Body(),
            callout: Callout(),
            caption: Caption(),
            footnote: Footnote(),
            headline: Headline(),
            largeTitle: LargeTitle(),
            subhead: Subhead(),
            title1: Title1(),
            title2: Title2(),
            title3: Title3(),
          ),
          AppThemeColorsExtension(
            gray: AppMaterialColors.gray,
            success: AppMaterialColors.success,
            error: AppMaterialColors.error,
            primary: AppMaterialColors.primary,
            white: AppMaterialColors.white,
            disable: AppMaterialColors.disable,
            button: AppMaterialColors.button,
            darkBlueBG: AppMaterialColors.darkBlueBG,
            offWhite: AppMaterialColors.offWhite,
            text: AppMaterialColors.text,
            darkText: AppMaterialColors.darkText,
            lightModeGray: AppMaterialColors.lightModeGray,
            black: AppMaterialColors.black,
            darkBorder: AppMaterialColors.darkBorder,
            successSecondary: AppMaterialColors.successSecondary,
            accent: AppMaterialColors.accent,
          ),
        ],
      );

  static ThemeData get darkTheme => ThemeData(
        fontFamily: 'WorkSans',
        primaryColor: AppMaterialColors.primary,
        scaffoldBackgroundColor: AppMaterialColors.gray,
        appBarTheme: AppBarTheme(
          backgroundColor: AppMaterialColors.white,
          foregroundColor: AppMaterialColors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppMaterialColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: AppMaterialColors.white),
        ),
        textTheme: const TextTheme().apply(
          displayColor: AppMaterialColors.white,
          bodyColor: AppMaterialColors.white,
          decorationColor: AppMaterialColors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: AppMaterialColors.gray,
          filled: true,
          hintStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppMaterialColors.gray,
          ),
          errorStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppMaterialColors.error,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 21, horizontal: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(27.5),
            borderSide: BorderSide(
              color: AppMaterialColors.gray,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(27.5),
            borderSide: BorderSide(
              color: AppMaterialColors.gray,
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(27.5),
            borderSide: BorderSide(
              color: AppMaterialColors.gray,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(27.5),
            borderSide: BorderSide(
              color: AppMaterialColors.error,
              width: 2,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: AppMaterialColors.white),
        colorScheme: ColorScheme.light(
          primary: AppMaterialColors.primary,
          secondary: AppMaterialColors.button,
          error: AppMaterialColors.error,
          onSecondary: AppMaterialColors.success,
          outline: AppMaterialColors.gray,
        ),
        extensions: [
          TypographyThemeExtension(
            body: Body(),
            callout: Callout(),
            caption: Caption(),
            footnote: Footnote(),
            headline: Headline(),
            largeTitle: LargeTitle(),
            subhead: Subhead(),
            title1: Title1(),
            title2: Title2(),
            title3: Title3(),
          ),
          AppThemeColorsExtension(
            gray: AppMaterialColors.gray,
            success: AppMaterialColors.success,
            error: AppMaterialColors.error,
            primary: AppMaterialColors.primary,
            white: AppMaterialColors.white,
            disable: AppMaterialColors.disable,
            button: AppMaterialColors.button,
            darkBlueBG: AppMaterialColors.darkBlueBG,
            offWhite: AppMaterialColors.offWhite,
            text: AppMaterialColors.text,
            darkText: AppMaterialColors.darkText,
            lightModeGray: AppMaterialColors.lightModeGray,
            black: AppMaterialColors.black,
            darkBorder: AppMaterialColors.darkBorder,
            successSecondary: AppMaterialColors.successSecondary,
            accent: AppMaterialColors.accent,
          ),
        ],
      );
}
