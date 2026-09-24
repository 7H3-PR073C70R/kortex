import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CourseModuleQuickSheet extends StatelessWidget {
  const CourseModuleQuickSheet({
    required this.course,
    super.key,
  });

  final CuratedCourseEntity course;

  static Future<void> show(
    BuildContext context, {
    required CuratedCourseEntity course,
  }) {
    AppFeedback.light();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withAlpha(160),
      builder: (_) => CourseModuleQuickSheet(course: course),
    );
  }

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final coveragePercent = (course.syllabusCoverage * 100).toInt();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.dialog),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? neural.obsidian850.withAlpha(245)
                : colors.surfacePrimary.withAlpha(245),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            border: Border.all(
              color: neural.hairline,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handlebar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: neural.slate400.withAlpha(100),
                    borderRadius: BorderRadius.circular(AppRadius.micro),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header: Course Code chip & Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: neural.emerald.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: neural.emerald400.withAlpha(80),
                      ),
                    ),
                    child: Text(
                      course.courseCode,
                      style: typography.code.bold.copyWith(
                        color: neural.emerald400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (course.hasActivePastPapers)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: neural.amber400.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: neural.amber400.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 12,
                            color: neural.amber400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Q-Bank Available',
                            style: typography.caption.bold.copyWith(
                              color: neural.amber400,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                course.title,
                style: typography.title2.bold.copyWith(
                  color: neural.slate100,
                  fontSize: 18,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                course.department,
                style: typography.caption.regular.copyWith(
                  color: neural.slate400,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),

              // Syllabus Progress Bar Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: neural.obsidian800.withAlpha(150),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neural.hairlineSoft),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Syllabus Mastery',
                          style: typography.caption.semiBold.copyWith(
                            color: neural.slate300,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$coveragePercent%',
                          style: typography.code.bold.copyWith(
                            color: neural.emerald400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 6,
                        child: ColoredBox(
                          color: neural.obsidian850,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: course.syllabusCoverage.clamp(0.0, 1.0),
                              child: ColoredBox(color: neural.emerald),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Actions List
              Text(
                'QUICK ACTIONS',
                style: typography.caption.bold.copyWith(
                  color: neural.slate400,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              // Action 1: Full Course Module
              _QuickSheetActionTile(
                icon: Icons.auto_stories_rounded,
                iconColor: neural.cyan400,
                title: 'Open Full Course Module',
                subtitle: 'Explore syllabus subtopics, decks, and past papers',
                onTap: () {
                  Navigator.pop(context);
                  unawaited(
                    context.router.push(
                      CourseModuleRoute(
                        courseId: course.id,
                        courseCode: course.courseCode,
                        courseTitle: course.title,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Action 2: Past Questions / Q-Bank
              if (course.hasActivePastPapers) ...[
                _QuickSheetActionTile(
                  icon: Icons.quiz_rounded,
                  iconColor: neural.amber400,
                  title: 'Practice Past Exam Questions',
                  subtitle: 'Launch CBT timed questions for ${course.courseCode}',
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(
                      context.router.push(
                        PastQuestionsBoardRoute(
                          initialExamCode: course.courseCode,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              // Action 3: Ingest Notes
              _QuickSheetActionTile(
                icon: Icons.upload_file_rounded,
                iconColor: neural.emerald400,
                title: 'Ingest Course Notes or PDF',
                subtitle: 'Auto-generate active recall cards with Syllabot AI',
                onTap: () {
                  Navigator.pop(context);
                  unawaited(
                    context.router.push(DocumentIngestionRoute()),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Dismiss button
              ShrinkableButton(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: neural.obsidian800,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neural.hairlineSoft),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Close',
                    style: typography.callout.medium.copyWith(
                      color: neural.slate300,
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
}

class _QuickSheetActionTile extends StatelessWidget {
  const _QuickSheetActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    return ShrinkableButton(
      onTap: () {
        AppFeedback.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: neural.obsidian850.withAlpha(180),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: neural.hairlineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.callout.bold.copyWith(
                      color: neural.slate100,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: neural.slate400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: neural.slate400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
