import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/course_overview_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_test_config_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Desktop practice workspace panel displaying the active subject header and stream of questions.
class BoardDesktopWorkspace extends StatelessWidget {
  const BoardDesktopWorkspace({
    required this.activeCourse,
    required this.courseQuestions,
    required this.state,
    super.key,
  });

  final CourseSummary activeCourse;
  final List<PastQuestionEntity> courseQuestions;
  final PastQuestionsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
        ),
      ),
      child: state.status == PastQuestionsStatus.loading
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerPlaceholder(
                          width: 160,
                          height: 24,
                          borderRadius: AppRadius.badge,
                        ),
                        SizedBox(height: 6),
                        ShimmerPlaceholder(
                          width: 240,
                          height: 14,
                          borderRadius: AppRadius.micro,
                        ),
                      ],
                    ),
                    ShimmerPlaceholder(
                      width: 110,
                      height: 40,
                      borderRadius: AppRadius.card,
                    ),
                  ],
                ),
                const Divider(height: 28),
                Expanded(
                  child: ListView.separated(
                    itemCount: 3,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) =>
                        const ShimmerPlaceholder(
                      height: 160,
                      borderRadius: AppRadius.panel,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject Header & Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeCourse.title,
                            style: typography.title2.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${state.selectedExam.displayName} • ${courseQuestions.length} questions • Years: ${activeCourse.yearRange}',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ShrinkableButton(
                      onTap: () {
                        AppFeedback.medium();
                        showPastQuestionsTestConfigSheet(context, state);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Start Test',
                              style: typography.caption.bold.copyWith(
                                color: colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Questions Stream / List
                Expanded(
                  child: courseQuestions.isEmpty
                      ? QuizEmptyState(
                          icon: Icons.assignment_outlined,
                          headline:
                              'No questions loaded for ${activeCourse.title}',
                          message:
                              'Click "Start Test" to launch a practice session or select another year.',
                        )
                      : ListView.builder(
                          itemCount: courseQuestions.length,
                          itemBuilder: (context, index) {
                            return PastQuestionCard(
                              question: courseQuestions[index],
                              isInstantFeedback: state.isInstantFeedbackMode,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
