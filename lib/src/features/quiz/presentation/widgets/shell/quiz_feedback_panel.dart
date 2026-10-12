import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/shell/quiz_chrome_primitives.dart';

/// Whether the staged practice answer was right.
enum QuizVerdict { correct, incorrect }

/// Calm, inline answer feedback.
///
/// Replaces the old "everything is a modal" approach: the verdict slides up
/// under the options, states the answer in plain words, and offers the
/// explanation plus one optional route to the class.
class QuizVerdictPanel extends StatelessWidget {
  const QuizVerdictPanel({
    required this.verdict,
    required this.question,
    this.hintText,
    this.askClassLabel,
    this.onAskClass,
    this.reduceMotion = false,
    super.key,
  });

  final QuizVerdict verdict;
  final QuizQuestionEntity question;

  /// Shown after a miss, when a hint was on the table for this question.
  final String? hintText;
  final String? askClassLabel;
  final VoidCallback? onAskClass;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isCorrect = verdict == QuizVerdict.correct;
    final hasUserAnswer = question.userSelectedAnswer != null &&
        question.userSelectedAnswer!.trim().isNotEmpty;
    final accent = isCorrect
        ? colors.success
        : (hasUserAnswer ? colors.error : colors.warning);

    return QuizStaggeredFade(
      reduceMotion: reduceMotion,
      distance: 16,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: accent.withAlpha(isDark ? 40 : 22),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: accent.withAlpha(100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : (hasUserAnswer
                            ? Icons.cancel_rounded
                            : Icons.help_outline_rounded),
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCorrect)
                        LatexRichViewer(
                          text: 'Nice, you got it! Correct answer: ${question.correctAnswer}',
                          style: typography.footnote.bold.copyWith(
                            color: colors.success,
                          ),
                        )
                      else ...[
                        if (hasUserAnswer) ...[
                          LatexRichViewer(
                            text: 'Your answer: ${question.userSelectedAnswer}',
                            style: typography.footnote.bold.copyWith(
                              color: colors.error,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ] else ...[
                          Text(
                            'You did not attempt this question',
                            style: typography.footnote.bold.copyWith(
                              color: colors.warning,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        LatexRichViewer(
                          text: 'Correct answer: ${question.correctAnswer}',
                          style: typography.footnote.bold.copyWith(
                            color: colors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (question.explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              LatexRichViewer(
                text: question.explanation,
                style: typography.footnote.regular.copyWith(
                  color: colors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
            if (!isCorrect && hintText != null) ...[
              const SizedBox(height: 8),
              Text(
                hintText!,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (!isCorrect &&
                question.latexFormula != null &&
                question.latexFormula!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              LatexFormulaBlock(formula: question.latexFormula!),
            ],
            if (!isCorrect && onAskClass != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onAskClass,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    askClassLabel ?? 'Ask the class about this',
                    style: typography.caption.bold,
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
