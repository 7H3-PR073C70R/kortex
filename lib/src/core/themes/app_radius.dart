import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Standardized concentric radius design tokens adhering to Better-UI principles:
/// Outer radius = inner radius + padding.
class AppRadius {
  const AppRadius._();

  /// 4dp: Micro-indicators, progress bar ticks, nested tags
  static const double micro = 4;

  /// 8dp: Inner pills, metric chips, status badges, compact action tags
  static const double badge = 8;

  /// 12dp: Interactive cards, buttons, text fields, search bars
  static const double card = 12;

  /// 16dp: Bento workstation panels, macro-containers, nav items
  static const double panel = 16;

  /// 20dp: Modal sheets, dialog windows, hero banners
  static const double dialog = 20;

  // BorderRadius helpers
  static final BorderRadius radiusMicro = BorderRadius.circular(micro);
  static final BorderRadius radiusBadge = BorderRadius.circular(badge);
  static final BorderRadius radiusCard = BorderRadius.circular(card);
  static final BorderRadius radiusPanel = BorderRadius.circular(panel);
  static final BorderRadius radiusDialog = BorderRadius.circular(dialog);

  /// Computes a concentric inner radius given the container's [outerRadius] and [padding].
  ///
  /// Prevents radius mismatch visually breaking nested rounded containers.
  static double concentric(double outerRadius, double padding) {
    return math.max(micro, outerRadius - padding);
  }

  /// Computes a concentric [BorderRadius] for nested children.
  static BorderRadius concentricBorderRadius(double outerRadius, double padding) {
    return BorderRadius.circular(concentric(outerRadius, padding));
  }
}
