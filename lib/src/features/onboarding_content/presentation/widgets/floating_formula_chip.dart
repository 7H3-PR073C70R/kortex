import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// Ambient floating formula / status badge floating on the graphic canvas.
class FloatingFormulaChip extends StatelessWidget {
  const FloatingFormulaChip({
    required this.label,
    this.icon,
    super.key,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(210),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(90)
                  : colors.white.withAlpha(220),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: colors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: isDark ? colors.textPrimary : colors.textPrimary,
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
