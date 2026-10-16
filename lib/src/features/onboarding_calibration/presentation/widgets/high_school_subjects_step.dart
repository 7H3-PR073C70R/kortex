import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/constants/subject_catalog.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_state.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_stream_filter_bar.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_subject_card.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_subject_helpers.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_subject_presets_bar.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_subjects_empty_view.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

export 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_stream_filter_bar.dart';
export 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_subject_card.dart';
export 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_subject_helpers.dart';
export 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_subject_presets_bar.dart';
export 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects/high_school_subjects_empty_view.dart';

/// Question B3: Universal subject selection powered directly by Kortex's
/// curated academic catalog, with 1-tap combination presets, real-time search,
/// horizontal stream filtering, and high-density responsive subject cards.
class HighSchoolSubjectsStep extends StatefulWidget {
  const HighSchoolSubjectsStep({
    super.key,
    this.calibrationCubit,
  });

  /// Optional injected cubit for testing and decoupling.
  final CalibrationCubit? calibrationCubit;

  @override
  State<HighSchoolSubjectsStep> createState() => _HighSchoolSubjectsStepState();
}

class _HighSchoolSubjectsStepState extends State<HighSchoolSubjectsStep> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedStream = 'All';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        final query = _searchController.text.trim();
        if (_searchQuery != query) {
          setState(() {
            _searchQuery = query;
          });
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _selectedStream = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalibrationCubit, CalibrationState>(
      bloc: widget.calibrationCubit,
      builder: (context, state) {
        final colors = context.colors;
        final typography = context.typography;
        final l10n = context.l10n;

        final cubit =
            widget.calibrationCubit ?? context.read<CalibrationCubit>();
        final selectedSubjects = state.profile.highSchoolSubjects;
        final allCourses = state.highSchoolCatalogCourses;

    final exam = (state.profile.highSchoolExam ?? '').toUpperCase();
    final isSat = exam.contains('SAT');

    // Filter combination presets relevant to this exam
    final presets = isSat
        ? kCuratedSubjectPresets.where((p) => p.id.startsWith('sat')).toList()
        : kCuratedSubjectPresets.where((p) => !p.id.startsWith('sat')).toList();

    // Dynamically identify available streams for tab filter
    final streamSet = <String>{};
    for (final course in allCourses) {
      streamSet.add(HighSchoolSubjectHelpers.cleanStream(course.department));
    }
    final streams = ['All', ...streamSet];

    // Filter courses by selected stream and search query
    final filteredCourses = allCourses.where((course) {
      final matchesStream = _selectedStream == 'All' ||
          HighSchoolSubjectHelpers.cleanStream(course.department)
                  .toLowerCase() ==
              _selectedStream.toLowerCase();
      if (!matchesStream) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      return course.title.toLowerCase().contains(query) ||
          course.courseCode.toLowerCase().contains(query) ||
          course.department.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Title & Subtitle ──────────────────────────────────────────────
        Text(
          l10n.calibrationQuestionB3,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.calibrationQuestionB3Subtitle,
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 13.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),

        // ── 2. Quick-Select Combination Presets ──────────────────────────────
        if (presets.isNotEmpty) ...[
          HighSchoolSubjectPresetsBar(
            presets: presets,
            selectedSubjects: selectedSubjects,
            onPresetTapped: (preset, {required isPresetActive}) {
              if (isPresetActive) {
                final updated = selectedSubjects
                    .where((s) => !preset.subjectTitles.contains(s))
                    .toList();
                cubit.setHighSchoolSubjects(updated);
              } else {
                final updated = <String>{
                  ...selectedSubjects,
                  ...preset.subjectTitles,
                }.toList();
                cubit.setHighSchoolSubjects(updated);
              }
            },
          ),
          const SizedBox(height: 16),
        ],

        // ── 3. Search Bar ───────────────────────────────────────────────────
        AppTextField(
          controller: _searchController,
          hintText: isSat
              ? 'Search SAT modules...'
              : 'Search 35+ subjects (e.g. Physics, Economics)...',
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: colors.textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                )
              : null,
          isDense: true,
          borderRadius: 14,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        const SizedBox(height: 10),

        // ── 4. Selection Counter & Stream Filter Tabs ────────────────────────
        HighSchoolStreamFilterBar(
          selectedSubjectsCount: selectedSubjects.length,
          totalCoursesCount: allCourses.length,
          onClearAll: cubit.clearHighSchoolSubjects,
          streams: streams,
          selectedStream: _selectedStream,
          onStreamSelected: (stream) {
            setState(() {
              _selectedStream = stream;
            });
          },
          streamCourseCount: (stream) => stream == 'All'
              ? allCourses.length
              : allCourses
                  .where(
                    (c) =>
                        HighSchoolSubjectHelpers.cleanStream(c.department)
                            .toLowerCase() ==
                        stream.toLowerCase(),
                  )
                  .length,
        ),

        // ── 5. Subject Cards / Empty State ───────────────────────────────────
        if (filteredCourses.isEmpty)
          HighSchoolSubjectsEmptyView(
            searchQuery: _searchQuery,
            onReset: _resetSearchAndFilters,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredCourses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final course = filteredCourses[index];
              final isSelected = selectedSubjects.contains(course.title);
              final streamName =
                  HighSchoolSubjectHelpers.cleanStream(course.department);
              final accentColor = HighSchoolSubjectHelpers.parseHexColor(
                course.colorHex,
                colors.primary,
              );

              return HighSchoolSubjectCard(
                course: course,
                streamName: streamName,
                accentColor: accentColor,
                isSelected: isSelected,
                onTap: () => cubit.toggleHighSchoolSubject(course.title),
              );
            },
          ),
        const SizedBox(height: 24),
      ]
          .animate(interval: 80.ms)
          .fadeIn(duration: 200.ms, curve: Curves.easeOutQuint)
          .slideY(
            begin: 0.04,
            end: 0,
            duration: 200.ms,
            curve: Curves.easeOutQuint,
          ),
        );
      },
    );
  }
}
