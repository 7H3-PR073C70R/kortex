import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive filter pill for decks overview.
class DeckFilterChip extends StatelessWidget {
  const DeckFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.isDueBadge = false,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final bool isDueBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      selected: isSelected,
      button: true,
      label: label,
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.snappyCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary
                : (isDark
                    ? colors.surfaceSecondary.withAlpha(150)
                    : colors.surfacePrimary.withAlpha(200)),
            borderRadius: BorderRadius.circular(AppRadius.badge),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : (isDark
                      ? colors.surfaceBorderHighlight.withAlpha(70)
                      : colors.surfaceBorder.withAlpha(120)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: isSelected ? colors.white : colors.textPrimary,
                  fontSize: 12,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: AppMotion.snappy,
                  switchInCurve: AppMotion.snappyCurve,
                  switchOutCurve: AppMotion.exitCurve,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Container(
                    key: ValueKey('$count-$isDueBadge-$isSelected'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDueBadge
                          ? colors.error
                          : (isSelected
                              ? colors.white.withAlpha(40)
                              : colors.primary.withAlpha(30)),
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                    ),
                    child: Text(
                      '$count',
                      style: typography.footnote.bold.copyWith(
                        color: colors.white,
                        fontSize: 10.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
