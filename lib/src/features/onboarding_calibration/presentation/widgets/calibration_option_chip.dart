import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive glass option chip / card with selection state, desktop hover states, and WCAG semantics.
class CalibrationOptionChip extends StatelessWidget {
  const CalibrationOptionChip({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.isMultiSelect = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool isSelected;
  final bool isMultiSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final semanticLabel = isSelected
        ? l10n.calibrationSelectedOptionSemantics(title)
        : l10n.calibrationSelectOptionSemantics(title);

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            shrinkScale: 0.97,
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onTap();
            },
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: AppRadius.radiusPanel,
                color: isSelected
                    ? colors.primary.withAlpha(
                        isDark ? (isHovered ? 80 : 60) : (isHovered ? 45 : 30),
                      )
                    : (isHovered
                          ? (isDark
                                ? colors.surfaceSecondary.withAlpha(180)
                                : colors.surfacePrimary)
                          : (isDark
                                ? colors.surfaceSecondary.withAlpha(120)
                                : colors.surfacePrimary.withAlpha(200))),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : (isHovered
                            ? colors.primary.withAlpha(120)
                            : (isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(70)
                                  : colors.surfaceBorder)),
                  width: isSelected ? 1.5 : (isHovered ? 1.2 : 1.0),
                ),
                boxShadow: [
                  if (isSelected || isHovered)
                    BoxShadow(
                      color: colors.black.withAlpha(
                        isDark
                            ? (isSelected ? 50 : 35)
                            : (isSelected ? 20 : 10),
                      ),
                      blurRadius: isHovered ? 12 : 8,
                      offset: Offset(0, isHovered ? 3 : 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : (isDark
                                  ? colors.surfacePrimary.withAlpha(150)
                                  : colors.surfaceSecondary),
                        borderRadius: AppRadius.radiusCard,
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: isSelected ? colors.white : colors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: typography.callout.bold.copyWith(
                            color: isSelected
                                ? colors.primary
                                : colors.textPrimary,
                            fontSize: 14.5,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: isMultiSelect
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                      borderRadius: isMultiSelect
                          ? BorderRadius.circular(6)
                          : null,
                      color: isSelected ? colors.primary : colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : (isHovered
                                  ? colors.textSecondary
                                  : colors.textMuted.withAlpha(120)),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
