import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/guided_tour/tour_step_model.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating guide card displayed adjacent to spotlighted features.
class TourGuideCard extends StatelessWidget {
  const TourGuideCard({
    required this.step,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.isLastStep,
    required this.cardMaxWidth,
    required this.cardMaxHeight,
    required this.onFinishTour,
    required this.onNextStep,
    required this.onPreviousStep,
    super.key,
  });

  final TourStep step;
  final int currentStepIndex;
  final int totalSteps;
  final bool isLastStep;
  final double cardMaxWidth;
  final double cardMaxHeight;
  final VoidCallback onFinishTour;
  final VoidCallback onNextStep;
  final VoidCallback onPreviousStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: cardMaxWidth,
        maxHeight: cardMaxHeight,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfacePrimary.withAlpha(245)
              : colors.surfacePrimary.withAlpha(252),
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          border: Border.all(
            color: step.accentColor.withAlpha(isDark ? 100 : 70),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 80 : 25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge & Skip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: step.accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                        border: Border.all(
                          color: step.accentColor.withAlpha(90),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: step.accentColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              step.badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.caption.bold.copyWith(
                                color: step.accentColor,
                                fontSize: 10.5,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PlatformHoverBuilder(
                    builder: (context, isHovered, child) {
                      return AnimatedScale(
                        scale: isHovered ? 1.05 : 1.0,
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        child: child,
                      );
                    },
                    child: TextButton(
                      onPressed: onFinishTour,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: Text(
                        'Skip Tour',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title and Icon Row
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: step.accentColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: step.accentColor.withAlpha(80),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      step.icon,
                      color: step.accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: typography.headline.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.subtitle,
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                step.description,
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 10),

              // Pro-Tip Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: step.accentColor.withAlpha(16),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: step.accentColor.withAlpha(50),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: step.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.proTip,
                        style: typography.caption.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Navigation Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Step dots
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(totalSteps, (idx) {
                          final isSelected = idx == currentStepIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 3),
                            width: isSelected ? 12 : 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? step.accentColor
                                  : colors.surfaceBorderHighlight,
                              borderRadius: BorderRadius.circular(
                                AppRadius.micro,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Back + Next/Finish buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentStepIndex > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: PlatformHoverBuilder(
                            builder: (context, isHovered, child) {
                              return AnimatedScale(
                                scale: isHovered ? 1.05 : 1.0,
                                duration: AppMotion.snappy,
                                curve: AppMotion.easeOutCubic,
                                child: child,
                              );
                            },
                            child: TextButton(
                              onPressed: onPreviousStep,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Back',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ShrinkableButton(
                        onTap: onNextStep,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: step.accentColor,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isLastStep ? 'Start Learning' : 'Next Step',
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isLastStep
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.arrow_forward_rounded,
                                color: colors.white,
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
