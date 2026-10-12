import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CourseModuleDocumentIngestionCard extends StatelessWidget {
  const CourseModuleDocumentIngestionCard({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.isDark,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Course Materials & Document Processing',
          style: typography.callout.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ShrinkableButton(
          onTap: () {
            AppFeedback.medium();
            unawaited(
              context.router.push(
                DocumentIngestionRoute(
                  courseId: courseId,
                  courseCode: courseCode,
                  courseTitle: courseTitle,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 28 : 16),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 70 : 45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 55 : 30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    size: 22,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Study Materials / Notes',
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Upload PDF documents, lecture slides, or camera snapshots to generate flashcards and study decks.',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
