import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_answer_matcher.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Bottom sheet listing every question and how far along it is.
class QuestionPaletteSheet extends StatelessWidget {
  const QuestionPaletteSheet({
    required this.state,
    required this.onJump,
    this.onSubmit,
    super.key,
  });

  final QuizSessionState state;
  final ValueChanged<int> onJump;

  /// Null in review mode: there is nothing left to submit.
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final reduceMotion = quizReduceMotion(context);
    final isExam = isExamSession(state);
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, isDesktop ? 20 : 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDesktop) ...[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.surfaceBorder,
                      borderRadius: AppRadius.radiusMicro,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All questions',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: QuizStatChip(
                      label: 'Answered',
                      value: '${state.answeredCount}',
                      color: colors.primary,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuizStatChip(
                      label: 'Flagged',
                      value: '${state.flaggedCount}',
                      color: colors.warning,
                      reduceMotion: reduceMotion,
                      staggerIndex: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuizStatChip(
                      label: 'Left blank',
                      value: '${state.unansweredCount}',
                      color: colors.textMuted,
                      reduceMotion: reduceMotion,
                      staggerIndex: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: state.totalQuestions,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.15,
                      ),
                  itemBuilder: (gridCtx, index) {
                    return QuizStaggeredFade(
                      distance: 8,
                      index: (index % 10) ~/ 2,
                      reduceMotion: reduceMotion,
                      child: PaletteTile(
                        number: index + 1,
                        status: _tileStatus(state, index),
                        onTap: () => onJump(index),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (onSubmit != null)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                    child: Text(
                      isExam
                          ? 'Submit mock exam (${state.answeredCount} of '
                                '${state.totalQuestions} answered)'
                          : 'Finish practice quiz (${state.answeredCount} '
                                'of ${state.totalQuestions} answered)',
                      style: typography.callout.bold.copyWith(
                        color: colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PaletteTileStatus _tileStatus(QuizSessionState state, int index) {
    final question = state.questions[index];
    if (index == state.currentIndex) return PaletteTileStatus.current;
    if (state.isQuestionFlagged(question.id)) {
      return PaletteTileStatus.flagged;
    }
    return question.isAnswered
        ? PaletteTileStatus.answered
        : PaletteTileStatus.blank;
  }
}

enum PaletteTileStatus { current, flagged, answered, blank }

class PaletteTile extends StatelessWidget {
  const PaletteTile({
    required this.number,
    required this.status,
    required this.onTap,
    super.key,
  });

  final int number;
  final PaletteTileStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final decoration = switch (status) {
      PaletteTileStatus.current => BoxDecoration(
        color: colors.primary.withValues(alpha: 0.2),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: colors.primary, width: 2),
      ),
      PaletteTileStatus.flagged => BoxDecoration(
        color: colors.warning.withValues(alpha: 0.15),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
      ),
      PaletteTileStatus.answered => BoxDecoration(
        color: colors.primary,
        borderRadius: AppRadius.radiusBadge,
      ),
      PaletteTileStatus.blank => BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: colors.surfaceBorder),
      ),
    };
    final textColor = switch (status) {
      PaletteTileStatus.current => colors.primary,
      PaletteTileStatus.flagged => colors.warning,
      PaletteTileStatus.answered => colors.white,
      PaletteTileStatus.blank => colors.textPrimary,
    };

    return Semantics(
      button: true,
      label: 'Question $number',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusBadge,
        child: AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          decoration: decoration,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$number',
                style: typography.callout.bold.copyWith(color: textColor),
              ),
              if (status == PaletteTileStatus.flagged)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Icon(
                    Icons.bookmark_rounded,
                    size: 11,
                    color: textColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
