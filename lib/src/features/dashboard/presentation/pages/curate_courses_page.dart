import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_state.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class CurateCoursesPage extends StatelessWidget {
  const CurateCoursesPage({
    this.initialEnrolledIds = const [],
    @queryParam this.userTrack,
    super.key,
  });

  final List<String> initialEnrolledIds;
  final String? userTrack;

  @override
  Widget build(BuildContext context) {
    var effectiveTrack = userTrack;
    if (effectiveTrack == null || effectiveTrack.isEmpty) {
      try {
        final profile = context.read<AuthBloc>().state.userProfile;
        if (profile != null && profile.targetTrack.isNotEmpty) {
          effectiveTrack = profile.targetTrack;
        }
      } on Object catch (_) {}
    }
    effectiveTrack ??= 'WAEC';

    return BlocProvider(
      create: (_) {
        final cubit = locator<CurateCoursesCubit>();
        unawaited(
          cubit.loadCatalog(
            currentlyEnrolledIds: initialEnrolledIds,
            userTrack: effectiveTrack,
          ),
        );
        return cubit;
      },
      child: _CurateCoursesView(userTrack: effectiveTrack),
    );
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

  List<String> get _categories {
    final track = widget.userTrack.toUpperCase();
    if (track.contains('WAEC') || track.contains('WASSCE')) {
      return const [
        'All',
        'Core',
        'Sciences',
        'Commercial',
        'Arts',
      ];
    }
    if (track.contains('JAMB') || track.contains('UTME')) {
      return const [
        'All',
        'Core',
        'Sciences',
        'Commercial',
        'Arts',
      ];
    }
    if (track.contains('NECO') || track.contains('SSCE')) {
      return const [
        'All',
        'Core',
        'Sciences',
        'Commercial',
        'Arts',
      ];
    }
    if (track.contains('SAT')) {
      return const [
        'All',
        'SAT Prep',
        'Math',
        'Reading',
      ];
    }
    return const [
      'All',
      'Computer Science',
      'Medicine & Health',
      'Law & Legal Studies',
      'Engineering',
      'Business & Management',
      'Social Sciences',
      'WAEC',
      'JAMB',
    ];
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddCustomCourseDialog(BuildContext context) {
    final codeController = TextEditingController(text: _searchController.text.trim());
    final titleController = TextEditingController();
    final deptController = TextEditingController();

    unawaited(
      AppDialog.show<void>(
        context: context,
        title: 'Add Custom Subject',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            AppTextField(
              controller: codeController,
              label: 'Course Code / Subject Code',
              hintText: 'e.g. BIO 201, ECN 102, LIT 301',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: titleController,
              label: 'Course Title',
              hintText: 'e.g. Molecular Genetics & Cytology',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: deptController,
              label: 'Faculty / Department (Optional)',
              hintText: 'e.g. Biological Sciences',
            ),
          ],
        ),
        primaryActionText: 'Add to Curriculum',
        onPrimaryAction: () {
          final code = codeController.text.trim();
          final title = titleController.text.trim();
          if (code.isEmpty && title.isEmpty) return;

          context.read<CurateCoursesCubit>().addCustomCourse(
            courseCode: code.isNotEmpty ? code : title,
            title: title.isNotEmpty ? title : code,
            department: deptController.text.trim(),
          );
          Navigator.of(context).pop();
        },
        secondaryActionText: 'Cancel',
        onSecondaryAction: () => Navigator.of(context).pop(),
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
          backgroundColor: isDark
              ? colors.backgroundPrimary
              : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Curate Your Curriculum',
              style: typography.title3.bold.copyWith(color: colors.textPrimary),
            ),
            centerTitle: false,
            actions: [
              if (selectedCount > 0)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 30),
                      borderRadius: BorderRadius.circular(12),
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
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Track Indicator Badge
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 35 : 20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 70 : 40),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.track_changes_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Active Academic Track: ${widget.userTrack}',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1. Search Bar & Add Custom Course Action
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary.withAlpha(140)
                                  : colors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.surfaceBorder.withAlpha(80),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: typography.callout.regular.copyWith(
                                color: colors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search course code or title...',
                                hintStyle: typography.callout.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: colors.textSecondary,
                                  size: 20,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          color: colors.textSecondary,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          context
                                              .read<CurateCoursesCubit>()
                                              .setSearchQuery('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (val) => context
                                  .read<CurateCoursesCubit>()
                                  .setSearchQuery(val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Add custom subject',
                          child: ShrinkableButton(
                            onTap: () => _openAddCustomCourseDialog(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withAlpha(80),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Category Filter Chips
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = cat == state.selectedCategory;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: colors.primary.withAlpha(isDark ? 60 : 35),
                          backgroundColor: isDark
                              ? colors.surfaceSecondary.withAlpha(120)
                              : colors.surfaceSecondary,
                          labelStyle: typography.caption.bold.copyWith(
                            color: isSelected
                                ? colors.primary
                                : colors.textSecondary,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? colors.primary
                                  : colors.surfaceBorder.withAlpha(80),
                            ),
                          ),
                          onSelected: (_) {
                            unawaited(HapticFeedback.lightImpact());
                            context
                                .read<CurateCoursesCubit>()
                                .selectCategory(cat);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 3. Quick-Add Banner when search has no exact match
                  if (state.searchQuery.trim().isNotEmpty &&
                      filteredCourses.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: ShrinkableButton(
                        onTap: () => _openAddCustomCourseDialog(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary.withAlpha(isDark ? 40 : 25),
                                colors.syllabotAccent.withAlpha(isDark ? 30 : 15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withAlpha(90),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: colors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add "${state.searchQuery}" to Curriculum',
                                      style: typography.callout.bold.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to provision and track this subject.',
                                      style: typography.caption.regular.copyWith(
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
                    ),
                  ],

                  // 4. Course Cards List
                  Expanded(
                    child: state.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: colors.primary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 100),
                            itemCount: filteredCourses.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final course = filteredCourses[index];
                              final isSelected = state.selectedCourseIds
                                  .contains(course.id);

                              return _CourseSelectTile(
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
                              );
                            },
                          ),
                  ),
                ],
              ),

              // 5. Floating Bottom Save Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.backgroundPrimary.withAlpha(200)
                            : colors.surfacePrimary.withAlpha(220),
                        border: Border(
                          top: BorderSide(
                            color: colors.surfaceBorder.withAlpha(100),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: ShrinkableButton(
                          onTap: state.isSubmitting
                              ? null
                              : () => context
                                  .read<CurateCoursesCubit>()
                                  .saveCuratedCourses(),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withAlpha(90),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: state.isSubmitting
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: colors.white,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: colors.white,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          selectedCount == 0
                                              ? 'Save Curriculum'
                                              : 'Save $selectedCount Course${selectedCount == 1 ? '' : 's'}',
                                          style: typography.callout.bold
                                              .copyWith(
                                            color: colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CourseSelectTile extends StatelessWidget {
  const _CourseSelectTile({
    required this.course,
    required this.isSelected,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onToggle,
  });

  final CuratedCourseEntity course;
  final bool isSelected;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${course.courseCode} ${course.title}. ${isSelected ? "Selected" : "Not selected"}',
      child: ShrinkableButton(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withAlpha(isDark ? 40 : 25)
                : (isDark
                    ? colors.surfaceSecondary.withAlpha(120)
                    : colors.surfaceSecondary),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.surfaceBorder.withAlpha(80),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Course Code Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary
                      : (isDark
                          ? colors.surfacePrimary.withAlpha(200)
                          : colors.surfacePrimary),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.surfaceBorder.withAlpha(100),
                  ),
                ),
                child: Text(
                  course.courseCode,
                  style: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Department
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: typography.callout.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.department,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Selection Checkmark Circle
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colors.primary : colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.surfaceBorderHighlight,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
