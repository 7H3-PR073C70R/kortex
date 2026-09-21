import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

class McqOptionCard extends StatelessWidget {
  const McqOptionCard({
    required this.optionText,
    required this.index,
    required this.isSelected,
    required this.isAnswered,
    required this.isCorrect,
    required this.onTap,
    super.key,
  });

  final String optionText;
  final int index;
  final bool isSelected;
  final bool isAnswered;
  final bool isCorrect;
  final VoidCallback onTap;

  String get _letterPrefix => String.fromCharCode(65 + index); // A, B, C, D

  String get _displayOptionText =>
      QuizContentSanitizer.cleanOptionText(optionText);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    var borderColor = isDark
        ? colors.surfaceBorderHighlight.withAlpha(50)
        : colors.surfaceBorder;
    var bgColor = isDark ? colors.surfaceSecondary : colors.cardBackground;
    var badgeBgColor = colors.surfaceSecondary;
    var badgeBorderColor = colors.surfaceBorder;
    var badgeTextColor = colors.textPrimary;
    Widget? trailingIcon;

    if (isAnswered) {
      if (isCorrect) {
        borderColor = colors.success;
        bgColor = colors.success.withAlpha(isDark ? 50 : 20);
        badgeBgColor = colors.success.withAlpha(isDark ? 75 : 35);
        badgeBorderColor = colors.success.withAlpha(130);
        badgeTextColor = colors.success;
        trailingIcon = Icon(
          Icons.check_circle_rounded,
          color: colors.success,
          size: 20,
        );
      } else if (isSelected) {
        borderColor = colors.error;
        bgColor = colors.error.withAlpha(isDark ? 50 : 20);
        badgeBgColor = colors.error.withAlpha(isDark ? 75 : 35);
        badgeBorderColor = colors.error.withAlpha(130);
        badgeTextColor = colors.error;
        trailingIcon = Icon(
          Icons.cancel_rounded,
          color: colors.error,
          size: 20,
        );
      }
    } else if (isSelected) {
      borderColor = colors.primary;
      bgColor = colors.primary.withAlpha(isDark ? 50 : 20);
      badgeBgColor = colors.primary.withAlpha(isDark ? 75 : 35);
      badgeBorderColor = colors.primary.withAlpha(130);
      badgeTextColor = colors.primary;
    }

    return Semantics(
      button: true,
      enabled: !isAnswered,
      label: 'Option $_letterPrefix: $_displayOptionText',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            final effectiveBorderColor = (!isAnswered && !isSelected && isHovered)
                ? colors.primary.withAlpha(isDark ? 140 : 100)
                : borderColor;
            final effectiveBgColor = (!isAnswered && !isSelected && isHovered)
                ? (isDark
                    ? colors.surfaceSecondary.withAlpha(220)
                    : colors.surfacePrimary)
                : bgColor;

            return InkWell(
              onTap: isAnswered ? null : onTap,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: AnimatedContainer(
                duration: AppMotion.standard,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: effectiveBgColor,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: effectiveBorderColor,
                    width: isSelected || (isAnswered && isCorrect) ? 1.8 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isHovered && !isAnswered
                          ? colors.primary.withAlpha(isDark ? 25 : 12)
                          : colors.black.withAlpha(isDark ? 25 : 6),
                      blurRadius: isHovered ? 12 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Prefix Badge
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                        border: Border.all(
                          color: badgeBorderColor,
                        ),
                      ),
                      child: Text(
                        _letterPrefix,
                        style: typography.footnote.bold.copyWith(
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LatexRichViewer(
                        text: _displayOptionText,
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      trailingIcon,
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
