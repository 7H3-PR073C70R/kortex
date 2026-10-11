import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Subscription tier selector offering Annual (best value) and Monthly plans.
class PaywallTierPlansSelector extends StatelessWidget {
  const PaywallTierPlansSelector({
    required this.selectedPlanIndex,
    required this.onSelectPlan,
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    this.offerings,
    super.key,
  });

  final int selectedPlanIndex;
  final ValueChanged<int> onSelectPlan;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;
  final Offerings? offerings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Annual Plan Card (Featured & Best Value)
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            final isSelected = selectedPlanIndex == 0;
            return ShrinkableButton(
              onTap: () => onSelectPlan(0),
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withAlpha(
                          isDark
                              ? (isHovered ? 60 : 45)
                              : (isHovered ? 32 : 22),
                        )
                      : (isHovered
                            ? (isDark
                                  ? colors.surfaceSecondary.withAlpha(220)
                                  : colors.surfacePrimary)
                            : (isDark
                                  ? colors.surfaceSecondary.withAlpha(180)
                                  : colors.surfacePrimary.withAlpha(200))),
                  borderRadius: AppRadius.radiusPanel,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : (isHovered
                              ? colors.primary.withAlpha(140)
                              : colors.surfaceBorder.withAlpha(80)),
                    width: isSelected ? 2 : (isHovered ? 1.4 : 1.0),
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: colors.primary.withAlpha(
                          isDark
                              ? (isHovered ? 65 : 45)
                              : (isHovered ? 35 : 20),
                        ),
                        blurRadius: isHovered ? 18 : 14,
                        offset: Offset(0, isHovered ? 5 : 3),
                      )
                    else if (isHovered)
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 50 : 15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.08 : 1.0,
                      duration: AppMotion.snappy,
                      curve: Curves.easeOutBack,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected ? colors.primary : colors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.paywallAnnualPlanTitle,
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Pulsing "SAVE 45%" Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.success,
                                      colors.success.withAlpha(200),
                                    ],
                                  ),
                                  borderRadius: AppRadius.radiusBadge,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.success.withAlpha(60),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  l10n.paywallAnnualSaveBadge,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 9,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              )
                                  .animate(
                                    onPlay: (controller) =>
                                        controller.repeat(reverse: true),
                                  )
                                  .scale(
                                    begin: const Offset(1, 1),
                                    end: const Offset(1.06, 1.06),
                                    duration: 1400.ms,
                                    curve: Curves.easeInOut,
                                  ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.paywallAnnualPlanSubtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.paywallAnnualWeeklyNote,
                            style: typography.footnote.medium.copyWith(
                              color: colors.primary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              r'$4.99',
                              style: typography.title3.bold.copyWith(
                                color: colors.primary,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              l10n.paywallPerMonth,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          r'$8.99/mo',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary.withAlpha(120),
                            decoration: TextDecoration.lineThrough,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Monthly Plan Card
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            final isSelected = selectedPlanIndex == 1;
            return ShrinkableButton(
              onTap: () => onSelectPlan(1),
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withAlpha(
                          isDark
                              ? (isHovered ? 60 : 45)
                              : (isHovered ? 32 : 22),
                        )
                      : (isHovered
                            ? (isDark
                                  ? colors.surfaceSecondary.withAlpha(220)
                                  : colors.surfacePrimary)
                            : (isDark
                                  ? colors.surfaceSecondary.withAlpha(180)
                                  : colors.surfacePrimary.withAlpha(200))),
                  borderRadius: AppRadius.radiusPanel,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : (isHovered
                              ? colors.primary.withAlpha(140)
                              : colors.surfaceBorder.withAlpha(80)),
                    width: isSelected ? 2 : (isHovered ? 1.4 : 1.0),
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: colors.primary.withAlpha(
                          isDark
                              ? (isHovered ? 60 : 40)
                              : (isHovered ? 30 : 15),
                        ),
                        blurRadius: isHovered ? 18 : 14,
                        offset: Offset(0, isHovered ? 5 : 3),
                      )
                    else if (isHovered)
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 50 : 15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.08 : 1.0,
                      duration: AppMotion.snappy,
                      curve: Curves.easeOutBack,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected ? colors.primary : colors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.paywallMonthlyPlanTitle,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.paywallMonthlyPlanSubtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          r'$8.99',
                          style: typography.title3.bold.copyWith(
                            color: isSelected
                                ? colors.primary
                                : colors.textPrimary,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          l10n.paywallPerMonth,
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
