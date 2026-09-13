import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';

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

    var borderColor = colors.surfaceBorder;
    var bgColor = isDark ? colors.surfaceSecondary : colors.cardBackground;
    var badgeBgColor = colors.surfaceSecondary;
    var badgeBorderColor = colors.surfaceBorder;
    var badgeTextColor = colors.textPrimary;
    Widget? trailingIcon;

    if (isAnswered) {
      if (isCorrect) {
        borderColor = colors.success;
        bgColor = colors.success.withValues(alpha: isDark ? 0.2 : 0.08);
        badgeBgColor = colors.success.withValues(alpha: isDark ? 0.3 : 0.15);
        badgeBorderColor = colors.success.withValues(alpha: 0.5);
        badgeTextColor = colors.success;
        trailingIcon = Icon(
          Icons.check_circle_rounded,
          color: colors.success,
          size: 20,
        );
      } else if (isSelected) {
        borderColor = colors.error;
        bgColor = colors.error.withValues(alpha: isDark ? 0.2 : 0.08);
        badgeBgColor = colors.error.withValues(alpha: isDark ? 0.3 : 0.15);
        badgeBorderColor = colors.error.withValues(alpha: 0.5);
        badgeTextColor = colors.error;
        trailingIcon = Icon(
          Icons.cancel_rounded,
          color: colors.error,
          size: 20,
        );
      }
    } else if (isSelected) {
      borderColor = colors.primary;
      bgColor = colors.primary.withValues(alpha: isDark ? 0.2 : 0.08);
      badgeBgColor = colors.primary.withValues(alpha: isDark ? 0.3 : 0.15);
      badgeBorderColor = colors.primary.withValues(alpha: 0.5);
      badgeTextColor = colors.primary;
    }

    return Semantics(
      button: true,
      enabled: !isAnswered,
      label: 'Option $_letterPrefix: $_displayOptionText',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: isAnswered ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: isSelected || (isAnswered && isCorrect) ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 25 : 6),
                  blurRadius: 8,
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
                    borderRadius: BorderRadius.circular(8),
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
        ),
      ),
    );
  }
}
