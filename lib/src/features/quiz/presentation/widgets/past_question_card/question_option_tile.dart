import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Single selectable option tile for multiple-choice questions in `PastQuestionCard`.
class QuestionOptionTile extends StatelessWidget {
  const QuestionOptionTile({
    required this.letter,
    required this.optionText,
    required this.isSelected,
    required this.isCorrect,
    required this.isAnswered,
    required this.isInstantFeedback,
    required this.onTap,
    super.key,
  });

  final String letter;
  final String optionText;
  final bool isSelected;
  final bool isCorrect;
  final bool isAnswered;
  final bool isInstantFeedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    var baseBgColor = isDark
        ? colors.backgroundPrimary
        : colors.surfaceSecondary.withAlpha(50);
    var baseBorderColor = colors.surfaceBorder.withAlpha(90);
    var optionTextColor = colors.textPrimary;

    if (isAnswered && isInstantFeedback) {
      if (isCorrect) {
        baseBgColor = colors.success.withAlpha(isDark ? 50 : 25);
        baseBorderColor = colors.success.withAlpha(180);
        optionTextColor = colors.success;
      } else if (isSelected) {
        baseBgColor = colors.error.withAlpha(isDark ? 50 : 25);
        baseBorderColor = colors.error.withAlpha(180);
        optionTextColor = colors.error;
      }
    } else if (isSelected) {
      baseBgColor = colors.primary.withAlpha(isDark ? 50 : 25);
      baseBorderColor = colors.primary;
      optionTextColor = colors.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PlatformHoverBuilder(
        builder: (context, isHovered, _) {
          final optionBgColor = isHovered && !isSelected && !isAnswered
              ? colors.primary.withAlpha(isDark ? 20 : 10)
              : baseBgColor;
          final optionBorderColor = isHovered && !isSelected && !isAnswered
              ? colors.primary.withAlpha(isDark ? 80 : 60)
              : baseBorderColor;

          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onTap();
            },
            child: AnimatedContainer(
              duration: AppMotion.standard,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: optionBgColor,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: optionBorderColor,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? colors.primary
                          : colors.surfaceSecondary,
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: typography.caption.bold.copyWith(
                          color: isSelected
                              ? colors.white
                              : colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LatexRichViewer(
                      text: optionText,
                      style: typography.subhead.medium.copyWith(
                        color: optionTextColor,
                      ),
                    ),
                  ),
                  if (isAnswered && isInstantFeedback) ...[
                    if (isCorrect)
                      Icon(
                        Icons.check_circle_rounded,
                        color: colors.success,
                        size: 20,
                      )
                    else if (isSelected)
                      Icon(
                        Icons.cancel_rounded,
                        color: colors.error,
                        size: 20,
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
