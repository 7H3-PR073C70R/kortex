import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';

/// Shows a confirmation dialog to delete a curated course and cascade deletions.
Future<void> confirmDeleteCuratedCourse({
  required BuildContext context,
  required CuratedCourseEntity course,
  required int deckCount,
  CurateCoursesCubit? curateCoursesCubit,
  DashboardBloc? dashboardBloc,
}) async {
  final resolvedCurateCoursesCubit = curateCoursesCubit ??
      (locator.isRegistered<CurateCoursesCubit>()
          ? locator<CurateCoursesCubit>()
          : null);
  final resolvedDashboardBloc = dashboardBloc ??
      (locator.isRegistered<DashboardBloc>()
          ? locator<DashboardBloc>()
          : null);

  final didDelete = await AppDialog.show<bool>(
    context: context,
    title: 'Delete Curated Course?',
    description:
        'Are you sure you want to remove "${course.courseCode} - ${course.title}"? '
        'This will delete the course from your curriculum along with its $deckCount associated study deck(s), flashcards, and uploaded documents.',
    primaryActionText: 'Delete Course',
    isDestructive: true,
    onPrimaryAction: () async {
      AppFeedback.heavy();
      if (resolvedCurateCoursesCubit != null) {
        await resolvedCurateCoursesCubit.deleteCourse(course.id);
      }
    },
    secondaryActionText: 'Cancel',
  );

  if (didDelete == true && context.mounted) {
    resolvedDashboardBloc?.add(const DashboardRefreshed());
    context.showSnackBar(
      message: '${course.courseCode} deleted successfully',
      type: SnackBarType.success,
    );
  }
}
