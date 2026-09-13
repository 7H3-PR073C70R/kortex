import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/lonely_teddy_bear_widget.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// A standardized, reusable empty state presentation component.
///
/// Displays an animated mascot illustration (sad or happy/celebratory), header title,
/// descriptive subtitle, and primary/secondary call-to-action buttons.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustrationSize = 130,
    this.isHappy = false,
    this.customIllustration,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final double illustrationSize;
  final bool isHappy;
  final Widget? customIllustration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Animated Mascot (Sad or Happy Celebratory)
            customIllustration ??
                LonelyTeddyBearWidget(
                  size: illustrationSize,
                  isHappy: isHappy,
                ),
            const SizedBox(height: 24),

            // 2. Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),

            // 3. Subtitle Description
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 4. Primary CTA Button
            if (primaryActionLabel != null && onPrimaryAction != null) ...[
              ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  onPrimaryAction!();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 80 : 50),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHappy
                            ? Icons.explore_rounded
                            : Icons.add_rounded,
                        color: colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        primaryActionLabel!,
                        style: typography.callout.bold.copyWith(
                          color: colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 5. Secondary Action Link
            if (secondaryActionLabel != null &&
                onSecondaryAction != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onSecondaryAction!();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Text(
                    secondaryActionLabel!,
                    style: typography.callout.medium.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
