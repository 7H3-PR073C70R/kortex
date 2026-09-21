import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Tactile, morphing pill page indicator with spring physics and depth glow.
class AnimatedPageIndicator extends StatelessWidget {
  const AnimatedPageIndicator({
    required this.count,
    required this.currentIndex,
    super.key,
    this.onTap,
    this.activeWidth = 32.0,
    this.inactiveWidth = 8.0,
    this.height = 6.0,
    this.spacing = 8.0,
    this.activeColor,
    this.inactiveColor,
    this.borderRadius = 3.0,
    this.semanticLabelBuilder,
  });

  final int count;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final double activeWidth;
  final double inactiveWidth;
  final double height;
  final double spacing;
  final Color? activeColor;
  final Color? inactiveColor;
  final double borderRadius;
  final String Function(int current, int total)? semanticLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final resolvedActive = activeColor ?? colors.primary;
    final resolvedInactive =
        inactiveColor ??
        (isDark
            ? colors.surfaceBorderHighlight.withAlpha(120)
            : colors.surfaceBorderHighlight);

    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (index) {
          final isSelected = index == currentIndex;

          final label = semanticLabelBuilder != null
              ? semanticLabelBuilder!(index + 1, count)
              : l10n.onboardingPageIndicatorSemantics(index + 1, count);

          return Semantics(
            button: onTap != null,
            label: label,
            selected: isSelected,
            child: PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                final effectiveWidth = isSelected
                    ? (isHovered ? activeWidth + 4 : activeWidth)
                    : (isHovered ? inactiveWidth + 4 : inactiveWidth);
                final effectiveColor = isSelected
                    ? resolvedActive
                    : (isHovered
                          ? (isDark
                                ? colors.textSecondary
                                : colors.textPrimary.withAlpha(160))
                          : resolvedInactive);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap != null ? () => onTap!(index) : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing / 2,
                      vertical: 14,
                    ),
                    child: AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      width: effectiveWidth,
                      height: height,
                      decoration: BoxDecoration(
                        color: effectiveColor,
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
