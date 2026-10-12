import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';

class CourseModuleDeleteDialog {
  const CourseModuleDeleteDialog._();

  static void confirmDelete({
    required BuildContext context,
    required String courseId,
    required String courseCode,
    required String courseTitle,
    required int deckCount,
    CurateCoursesCubit? curateCoursesCubit,
    DashboardBloc? dashboardBloc,
  }) {
    unawaited(
      AppDialog.show<bool>(
        context: context,
        title: 'Delete Curated Course?',
        description:
            'Are you sure you want to remove "$courseCode - $courseTitle"?\n\n'
            'This action is destructive and will delete the course along with its $deckCount associated study deck(s), flashcards, and uploaded documents.',
        primaryActionText: 'Delete Course',
        isDestructive: true,
        onPrimaryAction: () async {
          AppFeedback.heavy();
          final effectiveCubit = curateCoursesCubit ??
              (locator.isRegistered<CurateCoursesCubit>()
                  ? locator<CurateCoursesCubit>()
                  : null);
          if (effectiveCubit != null) {
            await effectiveCubit.deleteCourse(courseId);
          }
        },
        secondaryActionText: 'Cancel',
      ).then((didDelete) {
        if (didDelete == true && context.mounted) {
          final effectiveBloc = dashboardBloc ??
              (locator.isRegistered<DashboardBloc>()
                  ? locator<DashboardBloc>()
                  : null);
          effectiveBloc?.add(const DashboardRefreshed());
          context.showSnackBar(
            message: '$courseCode deleted successfully',
            type: SnackBarType.success,
          );
          context.router.pop();
        }
      }),
    );
  }
}
