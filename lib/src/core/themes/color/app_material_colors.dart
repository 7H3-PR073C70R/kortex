import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/color_extension.dart';

class AppMaterialColors {
  const AppMaterialColors._();
  static MaterialColor gray = const Color(0xFF101928).toMaterialColor(
    shade100: const Color(0xFFF0F2F5),
  );
  static MaterialColor success = const Color(0xFF027A48).toMaterialColor();
  static MaterialColor error = const Color(0xFFD61E34).toMaterialColor();
  static MaterialColor primary = const Color(0xFF3A5EFB).toMaterialColor();
  static MaterialColor white = const Color(0xFFFFFFFF).toMaterialColor();
  static MaterialColor disable = const Color(0xFFDDDDDD).toMaterialColor();
  static MaterialColor button = const Color(0xFF5B79FC).toMaterialColor();
  static MaterialColor darkBlueBG = const Color(0xFFE8EFFD).toMaterialColor();
  static MaterialColor offWhite = const Color(0xFFF7F7F7).toMaterialColor();
  static MaterialColor text = const Color(0xFF222222).toMaterialColor();
  static MaterialColor darkText = const Color(0xFF717171).toMaterialColor();
  static MaterialColor lightModeGray =
      const Color(0xFF1F2937).toMaterialColor();
  static MaterialColor black = const Color(0xFF000000).toMaterialColor();
  static MaterialColor darkBorder = const Color(0xFFEFEFEF).toMaterialColor();
  static MaterialColor successSecondary =
      const Color(0xFFC7EAD4).toMaterialColor();
  static MaterialColor accent = const Color(0xFFD68539).toMaterialColor();
}
