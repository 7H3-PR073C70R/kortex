import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';

/// Compact hint banner shown when the student has not enrolled in any university courses or decks.
class DefaultSubjectsBanner extends StatelessWidget {
  const DefaultSubjectsBanner({
    this.dashboardBloc,
    super.key,
  });

  final DashboardBloc? dashboardBloc;

  DashboardBloc? _resolveDashboardBloc(BuildContext context) =>
      dashboardBloc ??
      context.read<DashboardBloc?>() ??
      (locator.isRegistered<DashboardBloc>()
          ? locator<DashboardBloc>()
          : null);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withValues(alpha: 0.8)
            : colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 15,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Default Foundational Subjects',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  AppFeedback.selection();
                  final dashboardBloc = _resolveDashboardBloc(context);
                  Navigator.of(context).pop();
                  final result = await context.router.push(
                    CurateCoursesRoute(),
                  );
                  if (result == true) {
                    dashboardBloc?.add(const DashboardRefreshed());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Add Courses',
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text:
                  'Showing foundational subjects because you have no enrolled courses. You can also ',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () {
                      AppFeedback.selection();
                      Navigator.of(context).pop();
                      unawaited(context.router.push(CreateDeckRoute()));
                    },
                    child: Text(
                      'create a deck',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.primary,
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                  text: ' to duel offline with your course materials.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Action chip enabling students to quickly curate and enroll in courses.
class AddCourseChip extends StatelessWidget {
  const AddCourseChip({
    this.dashboardBloc,
    super.key,
  });

  final DashboardBloc? dashboardBloc;

  DashboardBloc? _resolveDashboardBloc(BuildContext context) =>
      dashboardBloc ??
      context.read<DashboardBloc?>() ??
      (locator.isRegistered<DashboardBloc>()
          ? locator<DashboardBloc>()
          : null);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ActionChip(
      avatar: Icon(
        Icons.add_rounded,
        size: 16,
        color: colors.primary,
      ),
      label: const Text('Add Course'),
      backgroundColor: colors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.badge),
        side: BorderSide(
          color: colors.primary.withValues(alpha: 0.35),
        ),
      ),
      labelStyle: context.typography.body.semiBold.copyWith(
        color: colors.primary,
        fontSize: 13,
      ),
      onPressed: () async {
        AppFeedback.selection();
        final dashboardBloc = _resolveDashboardBloc(context);
        Navigator.of(context).pop();
        final result = await context.router.push(
          CurateCoursesRoute(),
        );
        if (result == true) {
          dashboardBloc?.add(const DashboardRefreshed());
        }
      },
    );
  }
}
