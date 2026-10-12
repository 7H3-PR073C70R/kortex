import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Confirmation dialog for removing an assessment countdown from the timetable.
class ExamTimetableDeleteDialog {
  static Future<bool?> show(BuildContext context, ExamEventEntity exam) {
    final colors = context.colors;
    final typography = context.typography;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDarkMode
            ? colors.surfaceSecondary
            : colors.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusDialog),
        title: Text(
          'Delete Assessment Countdown?',
          style: typography.headline.bold.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${exam.examName}" from your '
          'academic timetable? This action cannot be undone.',
          style: typography.body.regular.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: typography.body.bold.copyWith(color: colors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusCard,
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.plannerDeleteAssessment),
          ),
        ],
      ),
    );
  }
}
