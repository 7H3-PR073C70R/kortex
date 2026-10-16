import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Single registered course card within the CBT readiness breakdown list.
class ReadinessBreakdownCourseCard extends StatelessWidget {
  const ReadinessBreakdownCourseCard({
    required this.sub,
    required this.examCategory,
    required this.examTitle,
    required this.hasPastQuestions,
    super.key,
  });

  final SubjectReadinessBreakdown sub;
  final ExamCategory examCategory;
  final String examTitle;
  final bool hasPastQuestions;

  String _cleanSlug(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfacePrimary.withAlpha(isDark ? 80 : 220),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top line: Subject name & Status/Grade pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.subjectName,
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                      ),
                    ),
                    if (sub.courseCode.isNotEmpty &&
                        sub.courseCode.toLowerCase() !=
                            sub.subjectName.toLowerCase()) ...[
                      const SizedBox(height: 1),
                      Text(
                        sub.courseCode,
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: sub.isCalibrated
                      ? (sub.statusColor ?? colors.primary).withAlpha(20)
                      : (hasPastQuestions
                          ? colors.primary.withAlpha(20)
                          : colors.warning.withAlpha(20)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: sub.isCalibrated
                        ? (sub.statusColor ?? colors.primary).withAlpha(80)
                        : (hasPastQuestions
                            ? colors.primary.withAlpha(80)
                            : colors.warning.withAlpha(80)),
                  ),
                ),
                child: Text(
                  sub.isCalibrated
                      ? (sub.projectedGrade.isNotEmpty
                          ? (sub.projectedGrade.endsWith('pts')
                              ? '${sub.projectedScore} / ${sub.maxScore} pts'
                              : '${sub.projectedScore}% · ${sub.projectedGrade}')
                          : '${sub.projectedScore} / ${sub.maxScore}')
                      : (hasPastQuestions
                          ? 'Mock Ready'
                          : 'Pending Diagnostic'),
                  style: typography.caption.bold.copyWith(
                    color: sub.isCalibrated
                        ? (sub.statusColor ?? colors.primary)
                        : (hasPastQuestions
                            ? colors.primary
                            : colors.warning),
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Calibrated vs Uncalibrated State
          if (sub.isCalibrated) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Syllabus: ${(sub.coveragePercent * 100).round()}%',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Accuracy: ${(sub.accuracyPercent * 100).round()}%${sub.questionsAnswered > 0 ? ' (${sub.questionsAnswered} items)' : ''}',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${sub.readinessPercent}% Readiness',
                  style: typography.caption.bold.copyWith(
                    color: sub.statusColor ?? colors.primary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.micro),
              child: LinearProgressIndicator(
                value: sub.readinessPercent / 100.0,
                minHeight: 6,
                backgroundColor: colors.surfaceBorder.withAlpha(50),
                valueColor: AlwaysStoppedAnimation<Color>(
                  sub.statusColor ?? colors.primary,
                ),
              ),
            ),
            if (hasPastQuestions) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      context.router.push(
                        MockExamLobbyRoute(
                          examId: 'cbt_mock_${_cleanSlug(sub.subjectName)}',
                          examName: sub.subjectName,
                          subjectTrack: examTitle,
                          courseCode: sub.courseCode.isNotEmpty
                              ? sub.courseCode
                              : sub.subjectName,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 13,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Retake Mock Exam',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ] else ...[
            Text(
              hasPastQuestions
                  ? 'Official past questions available. Take a mock exam to calibrate your readiness index.'
                  : 'No quiz or study activity recorded yet. Complete a 10-item diagnostic to unlock readiness.',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),

            // Action buttons: Mock Exam for courses with past questions, Diagnostic for courses without
            if (hasPastQuestions) ...[
              Row(
                children: [
                  Expanded(
                    child: ShrinkableButton(
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(
                          context.router.push(
                            MockExamLobbyRoute(
                              examId: 'cbt_mock_${_cleanSlug(sub.subjectName)}',
                              examName: sub.subjectName,
                              subjectTrack: examTitle,
                              courseCode: sub.courseCode.isNotEmpty
                                  ? sub.courseCode
                                  : sub.subjectName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(
                            AppRadius.badge,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary
                                  .withAlpha(isDark ? 50 : 25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Start Mock Exam',
                              style: typography.caption.bold.copyWith(
                                color: colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    tooltip: 'Browse Past Questions',
                    style: IconButton.styleFrom(
                      backgroundColor: colors.primary.withAlpha(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppRadius.badge,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(38, 38),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      unawaited(
                        context.router.push(
                          CourseQuestionsRoute(
                            courseTitle: sub.subjectName,
                            courseCode: sub.courseCode.isNotEmpty
                                ? sub.courseCode
                                : null,
                            examCategory: examCategory,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ] else ...[
              ShrinkableButton(
                onTap: () {
                  Navigator.pop(context);
                  unawaited(
                    context.router.push(
                      QuizWorkspaceRoute(
                        deckId:
                            'cbt_diagnostic_${_cleanSlug(sub.courseCode.isNotEmpty ? sub.courseCode : sub.subjectName)}',
                        deckTitle: '${sub.subjectName} Diagnostic Quiz',
                        subject: sub.subjectName,
                        courseCode: sub.courseCode.isNotEmpty
                            ? sub.courseCode
                            : sub.subjectName,
                        durationMinutes: 10,
                        assessmentMode: AssessmentMode.examSimulationMode,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: colors.primary.withAlpha(120),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Take 10-Item Diagnostic Quiz',
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
          ],
        ],
      ),
    );
  }
}
