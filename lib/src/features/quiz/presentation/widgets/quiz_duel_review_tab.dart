import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Post-Match Educational Review & Explanation tab for 1v1 Quiz Duels.
class QuizDuelReviewTab extends StatelessWidget {
  const QuizDuelReviewTab({
    required this.match,
    required this.currentUserId,
    super.key,
  });

  final QuizDuelMatch match;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final questions = match.questions;
    if (questions.isEmpty) {
      return Center(
        child: Text(
          'No questions to review.',
          style: typography.body.regular.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: questions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final q = questions[index];
        final p1 = match.player1;
        final p2 = match.player2;

        final isP1 = p1.userId == currentUserId;
        final myPlayer = isP1 ? p1 : p2;

        final myAnswerIdx = myPlayer?.selectedOptionIndex;
        final mySelectedText = (myAnswerIdx != null &&
                myAnswerIdx >= 0 &&
                myAnswerIdx < q.options.length)
            ? q.options[myAnswerIdx]
            : null;
        final isMyAnswerCorrect = mySelectedText == q.correctAnswer;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(
              color: isMyAnswerCorrect
                  ? colors.success.withAlpha(isDark ? 80 : 40)
                  : colors.error.withAlpha(isDark ? 80 : 40),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Question # & Subtopic Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMyAnswerCorrect
                          ? colors.success.withAlpha(30)
                          : colors.error.withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                    ),
                    child: Text(
                      'Question ${index + 1} of ${questions.length}',
                      style: typography.caption.bold.copyWith(
                        color: isMyAnswerCorrect
                            ? colors.success
                            : colors.error,
                      ),
                    ),
                  ),
                  if (q.subTopic.isNotEmpty)
                    Flexible(
                      child: AppBadge(
                        label: q.subTopic,
                        variant: AppBadgeVariant.secondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Question Prompt
              LatexRichViewer(
                text: q.prompt,
                style: typography.body.bold.copyWith(
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
              ),
              if (q.latexFormula != null && q.latexFormula!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                LatexFormulaBlock(formula: q.latexFormula!),
              ],
              const SizedBox(height: 14),

              // Answer Comparison Cards
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary
                      : colors.surfaceSecondary.withAlpha(120),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  children: [
                    // Your Answer
                    Row(
                      children: [
                        Icon(
                          isMyAnswerCorrect
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isMyAnswerCorrect
                              ? colors.success
                              : colors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your Answer: ',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            mySelectedText ?? 'No Answer',
                            style: typography.caption.bold.copyWith(
                              color: isMyAnswerCorrect
                                  ? colors.success
                                  : colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Correct Answer
                    Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: colors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Correct Answer: ',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            q.correctAnswer,
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Explanation Box
              if (q.explanation.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 25 : 15),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: colors.primary.withAlpha(40),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        color: colors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LatexRichViewer(
                          text: q.explanation,
                          style: typography.caption.regular.copyWith(
                            color: colors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Save to Flashcards Action
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                  label: const Text('Save to Flashcards'),
                  onPressed: () {
                    AppFeedback.selection();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Saved question from ${match.subject} duel for review!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
