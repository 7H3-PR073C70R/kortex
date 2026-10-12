import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_answer_matcher.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question progress tag, bookmark/flag toggle, review verdict tag, subtopic pill, and mode caption.
class QuizWorkspaceQuestionHeader extends StatelessWidget {
  const QuizWorkspaceQuestionHeader({
    required this.state,
    required this.question,
    required this.reviewMode,
    required this.reduceMotion,
    super.key,
  });

  final QuizSessionState state;
  final QuizQuestionEntity question;
  final bool reviewMode;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isExam = isExamSession(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuizStaggeredFade(
          reduceMotion: reduceMotion,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  l10n.quizQuestionProgress(
                    state.currentIndex + 1,
                    state.totalQuestions,
                  ),
                  style: typography.footnote.bold.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (isExam && !reviewMode) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context
                        .read<QuizSessionCubit>()
                        .toggleFlagCurrentQuestion(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: state.isCurrentQuestionFlagged
                            ? colors.warning.withValues(alpha: 0.15)
                            : colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.isCurrentQuestionFlagged
                              ? colors.warning
                              : colors.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            state.isCurrentQuestionFlagged
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 13,
                            color: state.isCurrentQuestionFlagged
                                ? colors.warning
                                : colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            state.isCurrentQuestionFlagged
                                ? 'Flagged'
                                : 'Flag',
                            style: typography.caption.bold.copyWith(
                              color: state.isCurrentQuestionFlagged
                                  ? colors.warning
                                  : colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (state.isCurrentQuestionFlagged) ...[
                  const SizedBox(width: 8),
                  QuizTagPill(
                    label: 'Flagged',
                    color: colors.warning,
                    icon: Icons.bookmark_rounded,
                  ),
                ],
                if (reviewMode) ...[
                  const SizedBox(width: 8),
                  if (question.isCorrect ||
                      isSameAnswer(
                        question.userSelectedAnswer ?? '',
                        question.correctAnswer,
                      ))
                    QuizTagPill(
                      label: 'Correct',
                      color: colors.success,
                      icon: Icons.check_circle_rounded,
                    )
                  else if (question.userSelectedAnswer != null &&
                      question.userSelectedAnswer!.isNotEmpty)
                    QuizTagPill(
                      label: 'Incorrect',
                      color: colors.error,
                      icon: Icons.cancel_rounded,
                    )
                  else
                    QuizTagPill(
                      label: 'Unattempted',
                      color: colors.warning,
                      icon: Icons.help_outline_rounded,
                    ),
                ],
                const SizedBox(width: 12),
                QuizTagPill(
                  label: question.subTopic,
                  color: colors.primary,
                  maxWidth: 200,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // The rules for this session, stated once in plain words.
        QuizStaggeredFade(
          reduceMotion: reduceMotion,
          index: 1,
          child: Text(
            reviewMode
                ? 'Review mode. Answers are locked while you look back.'
                : _sessionModeCaption(state),
            style: typography.caption.regular.copyWith(
              color: colors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  String _sessionModeCaption(QuizSessionState state) {
    return switch (state.assessmentMode) {
      AssessmentMode.discoveryMode => 'Practice mode. Check answers as you go.',
      AssessmentMode.examSimulationMode =>
        'Exam mode. Timed, and marks show at the end.',
      AssessmentMode.millionaireMode =>
        'Climb mode. Milestones you reach stay banked.',
    };
  }
}
