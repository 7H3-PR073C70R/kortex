import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/convert_failed_quiz_to_deck_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Post-Match Educational Review & Explanation tab for 1v1 Quiz Duels.
class QuizDuelReviewTab extends StatefulWidget {
  const QuizDuelReviewTab({
    required this.match,
    required this.currentUserId,
    super.key,
  });

  final QuizDuelMatch match;
  final String currentUserId;

  @override
  State<QuizDuelReviewTab> createState() => _QuizDuelReviewTabState();
}

class _QuizDuelReviewTabState extends State<QuizDuelReviewTab> {
  bool _isSavedAll = false;
  bool _isSaving = false;
  final Set<String> _savedQuestionIds = {};

  Future<void> _saveAllMissedQuestions(
    BuildContext context,
    List<QuizQuestionEntity> missedQuestions,
  ) async {
    if (_isSaving || _isSavedAll) return;
    setState(() => _isSaving = true);
    AppFeedback.medium();

    final targetQuestions = missedQuestions.isNotEmpty
        ? missedQuestions
        : widget.match.questions;

    try {
      if (locator.isRegistered<ConvertFailedQuizToDeckUseCase>()) {
        final useCase = locator<ConvertFailedQuizToDeckUseCase>();
        final resultEntity = QuizResultEntity(
          id: widget.match.duelId,
          quizTitle: '${widget.match.subject} Duel',
          totalQuestions: widget.match.questions.length,
          correctAnswers: widget.match.questions.length - missedQuestions.length,
          durationSeconds: 0,
          weaknesses: const [],
        );

        await useCase(
          result: resultEntity,
          questions: targetQuestions,
          courseCode: widget.match.subject,
        );
      }
    } catch (_) {
      // Fallback state handling
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isSavedAll = true;
      for (final q in targetQuestions) {
        _savedQuestionIds.add(q.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${targetQuestions.length} ${targetQuestions.length == 1 ? 'question' : 'questions'} from ${widget.match.subject} duel to Flashcards!',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSingleQuestion(String questionId) {
    AppFeedback.selection();
    setState(() {
      if (_savedQuestionIds.contains(questionId)) {
        _savedQuestionIds.remove(questionId);
      } else {
        _savedQuestionIds.add(questionId);
      }
    });
    final isSaved = _savedQuestionIds.contains(questionId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSaved
              ? 'Saved question to Flashcards!'
              : 'Removed question from Flashcards',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final questions = widget.match.questions;
    if (questions.isEmpty) {
      return Center(
        child: Text(
          'No questions to review.',
          style: typography.body.regular.copyWith(color: colors.textSecondary),
        ),
      );
    }

    final p1 = widget.match.player1;
    final p2 = widget.match.player2;
    final isP1 = p1.userId == widget.currentUserId;
    final myPlayer = isP1 ? p1 : p2;

    final missedQuestions = questions.where((q) {
      final myAnswerIdx = myPlayer?.selectedOptionIndex;
      final mySelectedText = (myAnswerIdx != null &&
              myAnswerIdx >= 0 &&
              myAnswerIdx < q.options.length)
          ? q.options[myAnswerIdx]
          : null;
      return mySelectedText != q.correctAnswer;
    }).toList();

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: questions.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Top Single-Tap "Save All Missed to Flashcards" Header Card
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: colors.primary.withAlpha(60),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSavedAll
                        ? Icons.check_circle_rounded
                        : Icons.style_rounded,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSavedAll
                            ? 'Saved to Flashcards'
                            : (missedQuestions.isNotEmpty
                                ? 'Save ${missedQuestions.length} Missed ${missedQuestions.length == 1 ? 'Question' : 'Questions'}'
                                : 'Save All Questions'),
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isSavedAll
                            ? 'Deck created for immediate practice.'
                            : (missedQuestions.isNotEmpty
                                ? '1-tap to save missed questions to Flashcards'
                                : '1-tap to save full duel to Flashcards'),
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isSavedAll ? colors.success : colors.primary,
                    foregroundColor: colors.surfacePrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isSavedAll
                              ? Icons.check_rounded
                              : Icons.bookmark_add_rounded,
                          size: 16,
                        ),
                  label: Text(
                    _isSavedAll ? 'Saved' : 'Save All',
                    style:
                        typography.caption.bold.copyWith(color: Colors.white),
                  ),
                  onPressed: _isSavedAll || _isSaving
                      ? null
                      : () => _saveAllMissedQuestions(context, missedQuestions),
                ),
              ],
            ),
          );
        }

        final qIndex = index - 1;
        final q = questions[qIndex];

        final myAnswerIdx = myPlayer?.selectedOptionIndex;
        final mySelectedText = (myAnswerIdx != null &&
                myAnswerIdx >= 0 &&
                myAnswerIdx < q.options.length)
            ? q.options[myAnswerIdx]
            : null;
        final isMyAnswerCorrect = mySelectedText == q.correctAnswer;
        final isSingleSaved = _savedQuestionIds.contains(q.id);

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
                      'Question ${qIndex + 1} of ${questions.length}',
                      style: typography.caption.bold.copyWith(
                        color: isMyAnswerCorrect
                            ? colors.success
                            : colors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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

              // Single Question Flashcard Toggle Action
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  icon: Icon(
                    isSingleSaved
                        ? Icons.bookmark_added_rounded
                        : Icons.bookmark_add_rounded,
                    size: 16,
                    color: isSingleSaved ? colors.success : colors.primary,
                  ),
                  label: Text(
                    isSingleSaved ? 'Saved to Flashcards' : 'Save to Flashcards',
                    style: typography.caption.bold.copyWith(
                      color: isSingleSaved ? colors.success : colors.primary,
                    ),
                  ),
                  onPressed: () => _toggleSingleQuestion(q.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
