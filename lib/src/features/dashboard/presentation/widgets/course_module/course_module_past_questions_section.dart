import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_cbt_paper_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_starter_qbank_card.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_past_question_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CourseModulePastQuestionsSection extends StatelessWidget {
  const CourseModulePastQuestionsSection({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.mappedSubject,
    required this.examCategory,
    required this.isDark,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String mappedSubject;
  final ExamCategory examCategory;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, pqState) {
        final questions = pqState.questions;
        final hasQuestions = questions.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Past Questions & Q-Bank',
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ShrinkableButton(
                  onTap: () {
                    AppFeedback.light();
                    unawaited(
                      AddPastQuestionModalSheet.show(
                        context,
                        courseId: courseId,
                        courseCode: courseCode,
                        defaultSubject: mappedSubject,
                        onAdded: (newQuestions) {
                          context.read<PastQuestionsBloc>().add(
                            AddPastQuestionsEvent(newQuestions),
                          );
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 45 : 25),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 80 : 50),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add Question',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (hasQuestions) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                    ),
                    child: Text(
                      '${pqState.officialQuestions.length} Official',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  if (pqState.userAddedQuestions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 45 : 22),
                        borderRadius: BorderRadius.circular(AppRadius.micro),
                        border: Border.all(
                          color: colors.primary.withAlpha(60),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${pqState.userAddedQuestions.length} User Added',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  if (pqState.theoryQuestions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.syllabotAccent.withAlpha(
                          isDark ? 40 : 20,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.micro),
                        border: Border.all(
                          color: colors.syllabotAccent.withAlpha(60),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${pqState.theoryQuestions.length} Theory',
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),

            if (pqState.status == PastQuestionsStatus.loading)
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(100)
                      : colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                ),
                child: const Center(
                  child: AppLogoLoader(size: 36, showMessage: false),
                ),
              )
            else if (hasQuestions) ...[
              // Practice CBT Drill Card
              CourseModuleCbtPaperCard(
                title: 'Full CBT Mock Examination',
                subtitle:
                    'Timed mock with ${questions.length.clamp(1, 40)} verified past questions',
                badgeText: 'MOCK EXAM',
                icon: Icons.timer_outlined,
                accentColor: colors.primary,
                courseId: courseId,
                courseCode: courseCode,
                courseTitle: courseTitle,
                questions: questions,
                isTimed: true,
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              // Practice Drill Card (Instant feedback)
              CourseModuleCbtPaperCard(
                title: 'Quick Practice Drill',
                subtitle:
                    'Untimed drill with instant step-by-step explanations',
                badgeText: 'DRILL',
                icon: Icons.bolt_rounded,
                accentColor: colors.syllabotAccent,
                courseId: courseId,
                courseCode: courseCode,
                courseTitle: courseTitle,
                questions: questions,
                isTimed: false,
                isDark: isDark,
              ),

              // User Added Past Questions Card (if any)
              if (pqState.userAddedQuestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                CourseModuleCbtPaperCard(
                  title: 'User Added Questions',
                  subtitle:
                      'Practice ${pqState.userAddedQuestions.length} custom / uploaded questions for $courseCode',
                  badgeText: 'USER ADDED',
                  icon: Icons.person_pin_rounded,
                  accentColor: colors.primary,
                  courseId: courseId,
                  courseCode: courseCode,
                  courseTitle: courseTitle,
                  questions: pqState.userAddedQuestions,
                  isTimed: false,
                  isDark: isDark,
                ),
              ],
            ] else ...[
              CourseModuleStarterQBankCard(
                courseId: courseId,
                courseCode: courseCode,
                courseTitle: courseTitle,
                mappedSubject: mappedSubject,
                examCategory: examCategory,
                fallbackQuestions: pqState.questions,
                isDark: isDark,
              ),
            ],
          ],
        );
      },
    );
  }
}
