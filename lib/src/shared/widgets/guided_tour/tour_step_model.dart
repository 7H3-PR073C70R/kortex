import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';

/// Representation of a granular step in the interactive app walkthrough.
class TourStep {
  const TourStep({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.proTip,
    required this.icon,
    required this.accentColor,
    required this.targetTabIndex,
    required this.targetKey,
    this.fallbackKey,
    this.onStepActivated,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String description;
  final String proTip;
  final IconData icon;
  final Color accentColor;
  final int targetTabIndex;
  final GlobalKey targetKey;
  final GlobalKey? fallbackKey;
  final VoidCallback? onStepActivated;

  /// Resolves the spotlight target rectangle accurately based on bound keys
  /// or dynamic responsive screen layout breakpoints.
  Rect resolveTarget(BuildContext context, Size screenSize, EdgeInsets insets) {
    // 1. Primary granular target key check
    final primaryRect = AppTourKeys.getTargetRect(targetKey);
    if (primaryRect != null && primaryRect.width > 0 && primaryRect.height > 0) {
      return primaryRect.inflate(6);
    }

    // 2. Secondary fallback section key check
    if (fallbackKey != null) {
      final fallbackRect = AppTourKeys.getTargetRect(fallbackKey!);
      if (fallbackRect != null && fallbackRect.width > 0 && fallbackRect.height > 0) {
        return fallbackRect.inflate(6);
      }
    }

    // 3. Dynamic Responsive Breakpoint Geometry
    final isDesktop = screenSize.width >= 900;
    final isTablet = screenSize.width >= 600 && screenSize.width < 900;

    final contentWidth = isDesktop
        ? math.min<double>(screenSize.width - 280, 840)
        : isTablet
            ? math.min<double>(screenSize.width - 64, 680)
            : math.min<double>(screenSize.width - 32, 540);

    final left = isDesktop
        ? 240 + (screenSize.width - 240 - contentWidth) / 2
        : (screenSize.width - contentWidth) / 2;

    final top = insets.top + 24;
    return Rect.fromLTWH(left, top, contentWidth, 120);
  }
}
