import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class AllCuratedCoursesPage extends HookWidget {
  const AllCuratedCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final searchQuery = useState<String>('');
    final selectedFilter = useState<String>('All');
    final searchController = useTextEditingController();

    return BlocProvider<DashboardBloc>.value(
      value: locator<DashboardBloc>(),
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, dashState) {
        final feed = dashState.feed;
        final allCourses = feed?.curatedCourses ?? const <CuratedCourseEntity>[];

        // Access decks for counting associated decks per course
        final allDecks = locator.isRegistered<DecksBloc>()
            ? locator<DecksBloc>().state.allDecks
            : const <DeckEntity>[];

        // Extract available departments/streams
        final departments = <String>{'All'};
        for (final c in allCourses) {
          if (c.department.isNotEmpty) {
            departments.add(c.department);
          }
        }

        final filteredCourses = allCourses.where((c) {
          final matchesQuery = searchQuery.value.isEmpty ||
              c.title.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
              c.courseCode.toLowerCase().contains(searchQuery.value.toLowerCase());
          final matchesFilter = selectedFilter.value == 'All' ||
              c.department == selectedFilter.value;
          return matchesQuery && matchesFilter;
        }).toList();

        final totalDecksCount = allCourses.fold<int>(0, (sum, c) {
          return sum +
              allDecks
                  .where((d) =>
                      d.courseId == c.id ||
                      (d.courseCode != null && d.courseCode == c.courseCode) ||
                      d.subject.toLowerCase() == c.title.toLowerCase())
                  .length;
        });

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.textPrimary,
                size: 18,
              ),
              onPressed: () => context.router.pop(),
            ),
            title: Text(
              'Enrolled Curated Courses',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
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
                      initialEnrolledIds: allCourses.map((c) => c.id).toList(),
                    ),
                  );
                  if (result == true && context.mounted) {
                    locator<DashboardBloc>().add(const DashboardRefreshed());
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Metrics Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary.withAlpha(140)
                              : colors.surfacePrimary.withAlpha(210),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? colors.surfaceBorderHighlight.withAlpha(60)
                                : colors.surfaceBorder.withAlpha(130),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              label: 'Active Courses',
                              value: '${allCourses.length}',
                              icon: Icons.school_rounded,
                              colors: colors,
                              typography: typography,
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(60)
                                  : colors.surfaceBorder.withAlpha(120),
                            ),
                            _buildStatItem(
                              label: 'Study Decks',
                              value: '$totalDecksCount',
                              icon: Icons.style_rounded,
                              colors: colors,
                              typography: typography,
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(60)
                                  : colors.surfaceBorder.withAlpha(120),
                            ),
                            _buildStatItem(
                              label: 'Available',
                              value: '${allCourses.where((c) => c.hasActivePastPapers).length} Q-Banks',
                              icon: Icons.verified_rounded,
                              colors: colors,
                              typography: typography,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Search & Filter Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: TextField(
                              controller: searchController,
                              style: typography.callout.regular.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                              ),
                              onChanged: (val) => searchQuery.value = val,
                              decoration: InputDecoration(
                                hintText: 'Search enrolled courses or codes...',
                                hintStyle: typography.callout.regular.copyWith(
                                  color: colors.textSecondary.withAlpha(140),
                                  fontSize: 13,
                                ),
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
                                filled: true,
                                fillColor: isDark
                                    ? colors.surfaceSecondary.withAlpha(120)
                                    : colors.surfacePrimary.withAlpha(180),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? colors.surfaceBorderHighlight.withAlpha(50)
                                        : colors.surfaceBorder.withAlpha(120),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? colors.surfaceBorderHighlight.withAlpha(50)
                                        : colors.surfaceBorder.withAlpha(120),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: colors.primary,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Department Filter Horizontal List
                if (departments.length > 1)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: departments.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final dept = departments.elementAt(index);
                        final isSelected = selectedFilter.value == dept;
                        return ShrinkableButton(
                          onTap: () {
                            AppFeedback.selection();
                            selectedFilter.value = dept;
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.primary
                                  : (isDark
                                      ? colors.surfaceSecondary.withAlpha(100)
                                      : colors.surfacePrimary.withAlpha(160)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : (isDark
                                        ? colors.surfaceBorderHighlight.withAlpha(50)
                                        : colors.surfaceBorder.withAlpha(120)),
                              ),
                            ),
                            child: Text(
                              dept,
                              style: typography.caption.bold.copyWith(
                                color: isSelected
                                    ? colors.white
                                    : colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),

                // Course List or Empty State
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
                            final courseDecks = allDecks.where((d) =>
                                d.courseId == course.id ||
                                (d.courseCode != null &&
                                    d.courseCode == course.courseCode) ||
                                d.subject.toLowerCase() ==
                                    course.title.toLowerCase()).toList();

                            return _CourseDetailedCard(
                              course: course,
                              decks: courseDecks,
                              colors: colors,
                              typography: typography,
                              isDark: isDark,
                              onDelete: () => _confirmDeleteCourse(
                                context,
                                course,
                                courseDecks.length,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  static Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: typography.callout.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDeleteCourse(
    BuildContext context,
    CuratedCourseEntity course,
    int deckCount,
  ) {
    unawaited(
      AppDialog.show<void>(
        context: context,
        title: 'Delete Curated Course?',
        description:
            'Are you sure you want to remove "${course.courseCode} - ${course.title}"? '
            'This will delete the course from your curriculum along with its $deckCount associated study deck(s), flashcards, and uploaded documents.',
        primaryActionText: 'Delete Course',
        isDestructive: true,
        onPrimaryAction: () async {
          AppFeedback.heavy();
          if (locator.isRegistered<CurateCoursesCubit>()) {
            await locator<CurateCoursesCubit>().deleteCourse(
              course.id,
            );
          }
          if (context.mounted) {
            locator<DashboardBloc>().add(const DashboardRefreshed());
          }
        },
        secondaryActionText: 'Cancel',
      ),
    );
  }
}

class _CourseDetailedCard extends StatelessWidget {
  const _CourseDetailedCard({
    required this.course,
    required this.decks,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onDelete,
  });

  final CuratedCourseEntity course;
  final List<DeckEntity> decks;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasDecks = decks.isNotEmpty;
    final realCoverage = hasDecks
        ? (decks.fold<double>(0, (s, d) => s + d.masteryRate) / decks.length).clamp(0.0, 1.0)
        : 0.0;
    final coveragePercent = (realCoverage * 100).toInt();
    final totalCards = decks.fold<int>(0, (s, d) => s + d.totalCards);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(140)
                : colors.surfacePrimary.withAlpha(210),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(60)
                  : colors.surfaceBorder.withAlpha(130),
              width: 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Code Pill + Department + Delete
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 50 : 25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          course.courseCode,
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        course.department,
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: colors.error.withAlpha(180),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Remove Course',
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                course.title,
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 10),

              // Deck & Card Metadata Pills
              Row(
                children: [
                  _buildMetaPill(
                    icon: Icons.layers_outlined,
                    label: '${decks.length} Decks',
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildMetaPill(
                    icon: Icons.style_outlined,
                    label: '$totalCards Cards',
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildMetaPill(
                    icon: Icons.access_time_rounded,
                    label: '${decks.where((d) => d.dueCards > 0).length} Due',
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Coverage Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Syllabus & Material Coverage',
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '$coveragePercent%',
                    style: typography.footnote.bold.copyWith(
                      color: colors.primary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 4,
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(50)
                      : colors.surfaceBorder.withAlpha(100),
                  child: FractionallySizedBox(
                    widthFactor: realCoverage.clamp(0.0, 1.0),
                    child: Container(color: colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ShrinkableButton(
                      onTap: () {
                        AppFeedback.light();
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Open Course',
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (decks.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    ShrinkableButton(
                      onTap: () {
                        AppFeedback.light();
                        unawaited(
                          context.router.push(
                            StudySessionRoute(deckId: decks.first.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 30 : 16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 70 : 40),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Study',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaPill({
    required IconData icon,
    required String label,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(80)
            : colors.surfacePrimary.withAlpha(160),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(40)
              : colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
