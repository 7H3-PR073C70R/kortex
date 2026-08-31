import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// Elevated glassmorphic container with 28px backdrop blur
/// and gradient borders.
class CalibrationGlassCard extends StatelessWidget {
  const CalibrationGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: isDark
                ? colors.surfaceSecondary.withAlpha(140)
                : colors.surfacePrimary.withAlpha(210),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(90)
                  : Colors.white.withAlpha(220),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(isDark ? 30 : 12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
