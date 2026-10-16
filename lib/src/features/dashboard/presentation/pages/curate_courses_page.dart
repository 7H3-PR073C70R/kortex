import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/curate_courses/add_custom_course_dialog.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/curate_courses/course_select_tile.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/curate_courses/curate_courses_save_dock.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/curate_courses/curate_courses_search_header.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';

export 'package:kortex/src/features/dashboard/presentation/widgets/curate_courses/add_custom_course_dialog.dart';
export 'package:kortex/src/features/dashboard/presentation/widgets/curate_courses/course_select_tile.dart';
export 'package:kortex/src/features/dashboard/presentation/widgets/curate_courses/curate_courses_save_dock.dart';
export 'package:kortex/src/features/dashboard/presentation/widgets/curate_courses/curate_courses_search_header.dart';

@RoutePage()
class CurateCoursesPage extends StatelessWidget {
  const CurateCoursesPage({
    this.initialEnrolledIds = const [],
    @queryParam this.userTrack,
    this.curateCoursesCubit,
    super.key,
  });

  final List<String> initialEnrolledIds;
  final String? userTrack;
  final CurateCoursesCubit? curateCoursesCubit;

  @override
  Widget build(BuildContext context) {
    var effectiveTrack = userTrack;
    if (effectiveTrack == null || effectiveTrack.isEmpty) {
      try {
        final profile = context.read<AuthBloc?>()?.state.userProfile;
        if (profile != null && profile.targetTrack.isNotEmpty) {
          effectiveTrack = profile.targetTrack;
        }
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }
    effectiveTrack ??= 'WAEC';

    final cubit = curateCoursesCubit ??
        (locator.isRegistered<CurateCoursesCubit>()
            ? locator<CurateCoursesCubit>()
            : null);

    if (cubit != null) {
      if (cubit.state.status == CurateCoursesStatus.initial) {
        unawaited(
          cubit.loadCatalog(
            currentlyEnrolledIds: initialEnrolledIds,
            userTrack: effectiveTrack,
          ),
        );
      }
      return BlocProvider<CurateCoursesCubit>.value(
        value: cubit,
        child: _CurateCoursesView(userTrack: effectiveTrack),
      );
    }

    return _CurateCoursesView(userTrack: effectiveTrack);
  }
}

class _CurateCoursesView extends StatefulWidget {
  const _CurateCoursesView({required this.userTrack});

  final String userTrack;

  @override
  State<_CurateCoursesView> createState() => _CurateCoursesViewState();
}

class _CurateCoursesViewState extends State<_CurateCoursesView> {
  late final TextEditingController _searchController;
  Timer? _searchDebounceTimer;

  static const _categories = [
    'All',
    'Core',
    'Sciences',
    'Commercial',
    'Arts',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openAddCustomCourseDialog(BuildContext context) {
    final cubit = context.read<CurateCoursesCubit>();
    unawaited(
      showAddCustomCourseDialog(
        context: context,
        initialSearchText: _searchController.text,
        cubit: cubit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocConsumer<CurateCoursesCubit, CurateCoursesState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == CurateCoursesStatus.success) {
          context.showSnackBar(
            message: 'Curriculum successfully saved and synced!',
          );
          Navigator.of(context).pop(true);
        } else if (state.status == CurateCoursesStatus.error &&
            state.errorMessage != null) {
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
      },
      builder: (context, state) {
        final filteredCourses = state.filteredCourses;
        final selectedCount = state.selectedCourseIds.length;

        return Scaffold(
          backgroundColor:
              isDark ? colors.backgroundPrimary : colors.surfacePrimary,
          appBar: AppAdaptiveAppBar(
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
                label: 'Curate Curriculum',
              ),
            ],
            titleText: 'Curate Your Curriculum',
            centerTitle: false,
            actions: [
              if (selectedCount > 0)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 30),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(color: colors.primary.withAlpha(100)),
                    ),
                    child: Text(
                      '$selectedCount Selected',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CurateCoursesSearchHeader(
                        userTrack: widget.userTrack,
                        searchController: _searchController,
                        categories: _categories,
                        selectedCategory: state.selectedCategory,
                        searchQuery: state.searchQuery,
                        hasNoMatches: filteredCourses.isEmpty,
                        onSearchChanged: (val) {
                          _searchDebounceTimer?.cancel();
                          _searchDebounceTimer = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              if (mounted) {
                                context
                                    .read<CurateCoursesCubit>()
                                    .setSearchQuery(val);
                              }
                            },
                          );
                        },
                        onClearSearch: () {
                          _searchDebounceTimer?.cancel();
                          _searchController.clear();
                          context
                              .read<CurateCoursesCubit>()
                              .setSearchQuery('');
                        },
                        onSelectCategory: (cat) {
                          context
                              .read<CurateCoursesCubit>()
                              .selectCategory(cat);
                        },
                        onOpenAddCustomCourse: () =>
                            _openAddCustomCourseDialog(context),
                        colors: colors,
                        typography: typography,
                        isDark: isDark,
                      ),
                      Expanded(
                        child: state.isLoading
                            ? const Center(
                                child: AppLogoLoader(size: 56),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  6,
                                  18,
                                  140,
                                ),
                                itemCount: filteredCourses.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final course = filteredCourses[index];
                                  final isSelected = state.selectedCourseIds
                                      .contains(course.id);

                                  return CourseSelectTile(
                                    course: course,
                                    isSelected: isSelected,
                                    colors: colors,
                                    typography: typography,
                                    isDark: isDark,
                                    onToggle: () {
                                      unawaited(HapticFeedback.lightImpact());
                                      context
                                          .read<CurateCoursesCubit>()
                                          .toggleCourseSelection(course.id);
                                    },
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
                  CurateCoursesSaveDock(
                    selectedCount: selectedCount,
                    isSubmitting: state.isSubmitting,
                    onSave: () => context
                        .read<CurateCoursesCubit>()
                        .saveCuratedCourses(),
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
