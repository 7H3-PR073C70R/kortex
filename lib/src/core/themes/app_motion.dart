import 'package:flutter/material.dart';

/// Emil Kowalski Organic Motion Tokens for Kortex.
/// Banishes standard linear animations in favor of natural cubic deceleration
/// and tactile spring physics.
class AppMotion {
  const AppMotion._();

  // ---------------------------------------------------------------------------
  // Custom Curves
  // ---------------------------------------------------------------------------
  /// Smooth, natural cubic deceleration curve for entries and state shifts
  static const Curve easeOutCubic = Curves.easeOutCubic;

  /// High-velocity snap curve (cubic-bezier(0.2, 0.0, 0.0, 1.0)) for instant tactile response
  static const Curve snappyCurve = Cubic(0.2, 0, 0, 1);

  /// Smooth exit curve (gentle deceleration for softer departures)
  static const Curve exitCurve = Curves.easeOut;

  // ---------------------------------------------------------------------------
  // Spring Descriptions
  // ---------------------------------------------------------------------------
  /// Gentle, non-bouncy spring for modal appearances and panels (bounce = 0)
  static const SpringDescription gentleSpring = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 30,
  );

  /// Snappy spring for button presses and micro-interactions
  static const SpringDescription quickSpring = SpringDescription(
    mass: 0.8,
    stiffness: 450,
    damping: 26,
  );

  // ---------------------------------------------------------------------------
  // Standard Durations
  // ---------------------------------------------------------------------------
  /// 120–150ms: Micro-interactions, button presses, focus rings, hover highlights
  static const Duration snappy = Duration(milliseconds: 150);

  /// 200–250ms: Sheet reveals, tab switches, navigation drawer transitions
  static const Duration standard = Duration(milliseconds: 250);

  /// 300–350ms: Workstation bento panel resize, orientation shifts, layout expansions
  static const Duration expressive = Duration(milliseconds: 320);

  /// 80–100ms: Stagger delay between sequential chunk entrances
  static const Duration staggerDelay = Duration(milliseconds: 80);
}
