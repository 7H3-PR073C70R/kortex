import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/all_curated_courses/course_detailed_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/all_curated_courses/curated_courses_department_filter_bar.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/all_curated_courses/curated_courses_metrics_banner.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/all_curated_courses/delete_course_dialog.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

@RoutePage()
class AllCuratedCoursesPage extends HookWidget {
  const AllCuratedCoursesPage({
    super.key,
    this.dashboardBloc,
    this.decksBloc,
    this.curateCoursesCubit,
  });

  final DashboardBloc? dashboardBloc;
  final DecksBloc? decksBloc;
  final CurateCoursesCubit? curateCoursesCubit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final searchQuery = useState<String>('');
    final selectedFilter = useState<String>('All');
    final searchController = useTextEditingController();

    final resolvedDashboardBloc = dashboardBloc ??
        (context.read<DashboardBloc?>() ??
            (locator.isRegistered<DashboardBloc>()
                ? locator<DashboardBloc>()
                : null));

    final resolvedDecksBloc = decksBloc ??
        (context.read<DecksBloc?>() ??
            (locator.isRegistered<DecksBloc>()
                ? locator<DecksBloc>()
                : null));

    final resolvedCurateCoursesCubit = curateCoursesCubit ??
        (context.read<CurateCoursesCubit?>() ??
            (locator.isRegistered<CurateCoursesCubit>()
                ? locator<CurateCoursesCubit>()
                : null));

    Widget buildContent(DashboardState dashState) {
      final feed = dashState.feed;
      final allCourses =
          feed?.curatedCourses ?? const <CuratedCourseEntity>[];

      // Access decks for counting associated decks per course
      final allDecks = resolvedDecksBloc?.state.allDecks ?? const <DeckEntity>[];

      // Extract available departments/streams
      final departments = <String>{'All'};
      for (final c in allCourses) {
        if (c.department.isNotEmpty) {
          departments.add(c.department);
        }
      }

      final filteredCourses = allCourses.where((c) {
        final matchesQuery =
            searchQuery.value.isEmpty ||
            c.title.toLowerCase().contains(
              searchQuery.value.toLowerCase(),
            ) ||
            c.courseCode.toLowerCase().contains(
              searchQuery.value.toLowerCase(),
            );
        final matchesFilter =
            selectedFilter.value == 'All' ||
            c.department == selectedFilter.value;
        return matchesQuery && matchesFilter;
      }).toList();

      final totalDecksCount = allCourses.fold<int>(0, (sum, c) {
        return sum +
            allDecks
                .where(
                  (d) =>
                      d.courseId == c.id ||
                      (d.courseCode != null &&
                          d.courseCode == c.courseCode) ||
                      d.subject.toLowerCase() == c.title.toLowerCase(),
                )
                .length;
      });

      return Scaffold(
        backgroundColor: colors.backgroundPrimary,
        appBar: AppAdaptiveAppBar(
          backgroundColor: colors.backgroundPrimary,
          breadcrumbs: [
            AppBreadcrumbItem(
              label: 'Dashboard',
              onTap: () {
                if (context.router.canPop()) {
                  context.router.pop();
                }
              },
            ),
            const AppBreadcrumbItem(
              label: 'Enrolled Courses',
            ),
          ],
          titleText: 'Enrolled Curated Courses',
          actions: [
            IconButton(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: colors.primary,
                size: 22,
              ),
              tooltip: 'Curate Courses',
              onPressed: () async {
                AppFeedback.light();
                final result = await context.router.push(
                  CurateCoursesRoute(
                    initialEnrolledIds: allCourses
                        .map((c) => c.id)
                        .toList(),
                  ),
                );
                if (result == true && context.mounted) {
                  resolvedDashboardBloc?.add(const DashboardRefreshed());
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SafeArea(
              child: Column(
                children: [
                  CuratedCoursesMetricsBanner(
                    activeCoursesCount: allCourses.length,
                    studyDecksCount: totalDecksCount,
                    qBanksCount:
                        allCourses.where((c) => c.hasActivePastPapers).length,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: searchController,
                            hintText: 'Search enrolled courses or codes...',
                            onChanged: (val) => searchQuery.value = val,
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: colors.textSecondary,
                              size: 18,
                            ),
                            suffixIcon: searchQuery.value.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: colors.textSecondary,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      searchController.clear();
                                      searchQuery.value = '';
                                    },
                                  )
                                : null,
                            isDense: true,
                            borderRadius: AppRadius.card,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CuratedCoursesDepartmentFilterBar(
                    departments: departments,
                    selectedFilter: selectedFilter.value,
                    onSelectFilter: (dept) => selectedFilter.value = dept,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredCourses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: colors.textSecondary.withAlpha(100),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No courses match your filter',
                                  style: typography.callout.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: filteredCourses.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final course = filteredCourses[index];
                              final courseDecks = allDecks
                                  .where(
                                    (d) =>
                                        d.courseId == course.id ||
                                        (d.courseCode != null &&
                                            d.courseCode ==
                                                course.courseCode) ||
                                        d.subject.toLowerCase() ==
                                            course.title.toLowerCase(),
                                  )
                                  .toList();

                              return CourseDetailedCard(
                                course: course,
                                decks: courseDecks,
                                colors: colors,
                                typography: typography,
                                isDark: isDark,
                                onDelete: () => confirmDeleteCuratedCourse(
                                  context: context,
                                  course: course,
                                  deckCount: courseDecks.length,
                                  curateCoursesCubit:
                                      resolvedCurateCoursesCubit,
                                  dashboardBloc: resolvedDashboardBloc,
                                ),
                              )
                                  .animate(
                                    delay: (index < 10 ? index * 60 : 0).ms,
                                  )
                                  .fadeIn(
                                    duration: 400.ms,
                                    curve: Curves.easeOutCubic,
                                  )
                                  .slideY(
                                    begin: 0.04,
                                    end: 0,
                                    curve: Curves.easeOutQuint,
                                  );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (resolvedDashboardBloc != null) {
      return BlocProvider<DashboardBloc>.value(
        value: resolvedDashboardBloc,
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, dashState) => buildContent(dashState),
        ),
      );
    }

    return buildContent(const DashboardState());
  }
}
