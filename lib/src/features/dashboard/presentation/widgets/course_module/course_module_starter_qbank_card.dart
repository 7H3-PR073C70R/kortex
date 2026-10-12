import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_past_question_modal_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/cbt_practice_config_modal_sheet.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CourseModuleStarterQBankCard extends StatelessWidget {
  const CourseModuleStarterQBankCard({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.mappedSubject,
    required this.examCategory,
    required this.fallbackQuestions,
    required this.isDark,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String mappedSubject;
  final ExamCategory examCategory;
  final List<PastQuestionEntity> fallbackQuestions;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withAlpha(isDark ? 40 : 18),
            colors.surfaceSecondary.withAlpha(isDark ? 160 : 210),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.dialog),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 70 : 40),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 40 : 15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 12,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${examCategory.displayName} • $mappedSubject',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.menu_book_rounded,
                size: 20,
                color: colors.primary.withAlpha(160),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Official $mappedSubject Q-Bank',
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Practice verified past questions, drill by specific year, or simulate a timed CBT exam.',
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ShrinkableButton(
                  onTap: () {
                    AppFeedback.light();
                    final questions = fallbackQuestions.isNotEmpty
                        ? fallbackQuestions
                        : CbtPracticeConfigModalSheet.generateCourseQuestions(
                            courseId: courseId,
                            courseCode: courseCode,
                            courseTitle: courseTitle,
                          );
                    unawaited(
                      CbtPracticeConfigModalSheet.show(
                        context,
                        title: 'Practice $mappedSubject Past Questions',
                        courseId: courseId,
                        courseCode: courseCode,
                        courseTitle: courseTitle,
                        allQuestions: questions,
                        isMockExam: false,
                      ),
                    );
                  },
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 50 : 25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_filled_rounded,
                          size: 16,
                          color: colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Launch CBT Practice',
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ShrinkableButton(
                onTap: () {
                  AppFeedback.light();
                  unawaited(
                    context.router.push(
                      SyllabotChatRoute(
                        initialPrompt:
                            'Please generate 5 official-style ${examCategory.displayName} practice questions for $mappedSubject right now. '
                            'For each question, provide 4 options labeled A, B, C, and D, clearly indicate the correct answer, and explain the step-by-step solution.',
                        initialMode: SocraticMode.examSim,
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: colors.syllabotAccent.withAlpha(isDark ? 80 : 50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: colors.syllabotAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'AI Drill',
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 75 : 45),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Upload or Add Past Questions',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
