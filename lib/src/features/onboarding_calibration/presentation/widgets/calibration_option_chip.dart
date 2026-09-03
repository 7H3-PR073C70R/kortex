import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive glass option chip / card with selection state and WCAG semantics.
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
      child: ShrinkableButton(
        shrinkScale: 0.985,
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isSelected
                ? colors.primary.withAlpha(isDark ? 60 : 30)
                : (isDark
                      ? colors.surfaceSecondary.withAlpha(120)
                      : colors.surfacePrimary.withAlpha(200)),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : (isDark
                        ? colors.surfaceBorderHighlight.withAlpha(70)
                        : colors.surfaceBorder),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : colors.primary,
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
                        color: isSelected ? colors.primary : colors.textPrimary,
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
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: isMultiSelect ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isMultiSelect ? BorderRadius.circular(6) : null,
                  color: isSelected ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.textMuted.withAlpha(120),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
