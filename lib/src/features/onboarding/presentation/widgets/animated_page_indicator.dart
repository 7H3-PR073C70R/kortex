import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Smooth expanding pill page indicator tracking onboarding active index.
class AnimatedPageIndicator extends StatelessWidget {
  const AnimatedPageIndicator({
    required this.count,
    required this.currentIndex,
    super.key,
    this.onTap,
    this.activeWidth = 26.0,
    this.inactiveWidth = 8.0,
    this.height = 8.0,
    this.spacing = 6.0,
    this.activeColor,
    this.inactiveColor,
    this.borderRadius = 4.0,
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
    final resolvedActive = activeColor ?? colors.primary;
    final resolvedInactive =
        inactiveColor ?? colors.surfaceBorderHighlight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isSelected = index == currentIndex;
        final targetWidth = isSelected ? activeWidth : inactiveWidth;
        final targetColor = isSelected ? resolvedActive : resolvedInactive;

        final label = semanticLabelBuilder != null
            ? semanticLabelBuilder!(index + 1, count)
            : l10n.onboardingPageIndicatorSemantics(index + 1, count);

        return Semantics(
          button: onTap != null,
          label: label,
          selected: isSelected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap != null ? () => onTap!(index) : null,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing / 2,
                vertical: 12,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: targetWidth,
                height: height,
                decoration: BoxDecoration(
                  color: targetColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
