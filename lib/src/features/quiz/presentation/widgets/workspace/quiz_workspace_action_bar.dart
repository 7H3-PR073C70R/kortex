import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_answer_matcher.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Low-weight outlined button for optional offers such as hints.
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.reduceMotion,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 40 : 20),
          borderRadius: AppRadius.radiusCard,
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: typography.caption.bold.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single primary action for the quiz, pinned where thumbs already are.
class QuizActionBar extends StatelessWidget {
  const QuizActionBar({
    required this.state,
    required this.reduceMotion,
    required this.reviewMode,
    required this.onOpenPalette,
    required this.onOpenLadder,
    required this.onReviewAndSubmit,
    required this.onExit,
    super.key,
  });

  final QuizSessionState state;
  final bool reduceMotion;
  final bool reviewMode;
  final VoidCallback onOpenPalette;
  final VoidCallback onOpenLadder;
  final VoidCallback onReviewAndSubmit;
  final VoidCallback onExit;

  /// Next step for the current mode: Check, Continue, Review or Bank.
  ({Color color, String label, VoidCallback? onPressed}) _resolveAction(
    AppThemeColorsExtension colors,
    QuizSessionCubit cubit,
  ) {
    final question = state.currentQuestion;
    final isAnswered = question?.isAnswered ?? false;

    if (reviewMode) {
      if (state.isLastQuestion) {
        return (
          color: colors.primary,
          label: 'Back to results',
          onPressed: onExit,
        );
      }
      return (
        color: colors.primary,
        label: 'Next question',
        onPressed: cubit.nextQuestion,
      );
    }

    if (state.assessmentMode == AssessmentMode.millionaireMode) {
      if (state.isSoftFailed) {
        return (
          color: colors.warning,
          label: 'Bank and see results',
          onPressed: () => unawaited(cubit.submitQuiz()),
        );
      }
      if (!isAnswered) {
        return (
          color: colors.primary,
          label: 'Pick an answer',
          onPressed: null,
        );
      }
      return state.isLastQuestion
          ? (
              color: colors.success,
              label: 'See results',
              onPressed: () => unawaited(cubit.submitQuiz()),
            )
          : (
              color: colors.primary,
              label: 'Next',
              onPressed: cubit.nextQuestion,
            );
    }

    if (isExamSession(state)) {
      if (state.isLastQuestion) {
        return (
          color: colors.success,
          label: state.unansweredCount == 0
              ? 'Review and finish'
              : 'Review (${state.unansweredCount} left blank)',
          onPressed: onReviewAndSubmit,
        );
      }
      return (
        color: colors.primary,
        label: 'Next question',
        onPressed: cubit.nextQuestion,
      );
    }

    if (isAnswered) {
      return state.isLastQuestion
          ? (
              color: colors.success,
              label: 'See results',
              onPressed: () => unawaited(cubit.submitQuiz()),
            )
          : (
              color: colors.primary,
              label: 'Continue',
              onPressed: cubit.nextQuestion,
            );
    }

    return (
      color: colors.primary,
      label: 'Check',
      onPressed: state.hasPendingAnswer ? cubit.checkAnswer : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final cubit = context.read<QuizSessionCubit>();
    final action = _resolveAction(colors, cubit);
    final isMillionaire =
        state.assessmentMode == AssessmentMode.millionaireMode;
    final canStepBack = !isMillionaire && state.canGoPrevious;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        border: Border(top: BorderSide(color: colors.surfaceBorder)),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(context.isDarkMode ? 30 : 6),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Row(
              children: [
                if (!isMillionaire) ...[
                  IconButton.outlined(
                    onPressed: canStepBack ? cubit.previousQuestion : null,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: canStepBack
                          ? colors.textPrimary
                          : colors.textMuted,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.surfaceBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                    tooltip: 'Previous question',
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onOpenPalette,
                    icon: Icon(
                      Icons.grid_view_rounded,
                      color: colors.textPrimary,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.surfaceBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                    tooltip: 'All questions',
                  ),
                  if (isExamSession(state)) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: cubit.toggleFlagCurrentQuestion,
                      icon: Icon(
                        state.isCurrentQuestionFlagged
                            ? Icons.bookmark_added_rounded
                            : Icons.bookmark_border_rounded,
                        color: state.isCurrentQuestionFlagged
                            ? colors.warning
                            : colors.textSecondary,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: state.isCurrentQuestionFlagged
                              ? colors.warning.withAlpha(120)
                              : colors.surfaceBorder,
                        ),
                        backgroundColor: state.isCurrentQuestionFlagged
                            ? colors.warning.withAlpha(20)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusCard,
                        ),
                      ),
                      tooltip: state.isCurrentQuestionFlagged
                          ? 'Question flagged for review'
                          : 'Flag question for review',
                    ),
                  ],
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: reduceMotion ? Duration.zero : AppMotion.standard,
                    switchInCurve: AppMotion.easeOutCubic,
                    switchOutCurve: AppMotion.exitCurve,
                    child: SizedBox(
                      key: ValueKey(action.label),
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: action.onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: action.color,
                          foregroundColor: colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusCard,
                          ),
                        ),
                        child: Text(
                          action.label,
                          style: typography.callout.bold.copyWith(
                            color: colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
