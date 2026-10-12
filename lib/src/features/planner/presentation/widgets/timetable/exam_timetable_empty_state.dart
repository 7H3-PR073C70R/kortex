import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Clean empty state placeholder displayed when no assessments are scheduled.
class ExamTimetableEmptyState extends StatelessWidget {
  const ExamTimetableEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 40,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Exams Scheduled Yet',
              style: typography.title2.bold.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add quizzes, mid-term exams, or final exams to track your deadlines, '
              'calculate daily pacing targets, and stay calibrated.',
              style: typography.body.regular.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AppButton(
              text: 'Add First Exam',
              onPressed: () => context.router.push(
                AddAcademicAssessmentRoute(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
