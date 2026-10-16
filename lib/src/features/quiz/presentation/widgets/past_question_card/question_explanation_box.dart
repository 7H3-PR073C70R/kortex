import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';

/// Callout box displaying step-by-step solution and explanation for answered questions.
class QuestionExplanationBox extends StatelessWidget {
  const QuestionExplanationBox({
    required this.explanation,
    super.key,
  });

  final String explanation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 30 : 15),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 70 : 40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: colors.syllabotAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Explanation & Solution',
                style: typography.footnote.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LatexRichViewer(
            text: explanation,
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
