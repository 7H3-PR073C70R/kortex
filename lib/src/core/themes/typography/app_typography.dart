import 'package:flutter/material.dart';

abstract class AppTypography {
  const AppTypography({
    required this.regular,
    required this.medium,
    required this.semiBold,
    required this.bold,
  });

  final TextStyle regular;
  final TextStyle medium;
  final TextStyle semiBold;
  final TextStyle bold;

  AppTypography copyWith({
    TextStyle? regular,
    TextStyle? medium,
    TextStyle? semiBold,
    TextStyle? bold,
  });

  AppTypography lerp(covariant AppTypography other, double t);
}
