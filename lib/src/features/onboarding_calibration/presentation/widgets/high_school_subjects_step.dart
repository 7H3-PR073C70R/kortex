import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/constants/subject_catalog.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/curriculum_icon_resolver.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Question B3: Universal subject selection powered directly by Kortex's
/// curated academic catalog, with 1-tap combination presets, real-time search,
/// horizontal stream filtering, and high-density responsive subject cards.
class HighSchoolSubjectsStep extends StatefulWidget {
  const HighSchoolSubjectsStep({super.key});

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

  String _cleanStream(String department) {
    if (department.contains('Core')) return 'Core';
    if (department.contains('Science')) return 'Sciences';
    if (department.contains('Commercial')) return 'Commercial';
    if (department.contains('Art')) return 'Arts';
    if (department.contains('SAT')) return 'SAT Prep';
    final parts = department.split('-');
    return parts.last.trim();
  }

  Color _parseHexColor(String hex, Color fallback) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } on Object catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final cubit = context.watch<CalibrationCubit>();
    final state = cubit.state;
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
      streamSet.add(_cleanStream(course.department));
    }
    final streams = ['All', ...streamSet];

    // Filter courses by selected stream and search query
    final filteredCourses = allCourses.where((course) {
      final matchesStream =
          _selectedStream == 'All' ||
          _cleanStream(course.department).toLowerCase() ==
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
          Row(
            children: [
              Text(
                'QUICK PRESETS',
                style: typography.caption.semiBold.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  '1-Tap',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = presets[index];
                final isPresetActive = preset.subjectTitles.every(
                  selectedSubjects.contains,
                );

                return PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return ShrinkableButton(
                      onTap: () {
                        unawaited(HapticFeedback.mediumImpact());
                        if (isPresetActive) {
                          // Deselect subjects in this preset
                          final updated = selectedSubjects
                              .where((s) => !preset.subjectTitles.contains(s))
                              .toList();
                          cubit.setHighSchoolSubjects(updated);
                        } else {
                          // Merge all subjects in this preset into selection
                          final updated = <String>{
                            ...selectedSubjects,
                            ...preset.subjectTitles,
                          }.toList();
                          cubit.setHighSchoolSubjects(updated);
                        }
                      },
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isPresetActive
                              ? colors.primary.withAlpha(
                                  isDark
                                      ? (isHovered ? 80 : 65)
                                      : (isHovered ? 50 : 35),
                                )
                              : isHovered
                              ? (isDark
                                    ? colors.surfaceSecondary.withAlpha(140)
                                    : colors.surfacePrimary)
                              : (isDark
                                    ? colors.surfaceSecondary.withAlpha(100)
                                    : colors.surfacePrimary.withAlpha(190)),
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(
                            color: isPresetActive
                                ? colors.primary
                                : isHovered
                                ? (isDark
                                      ? colors.surfaceBorderHighlight
                                      : colors.primary.withAlpha(90))
                                : (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          70,
                                        )
                                      : colors.surfaceBorder),
                            width: isPresetActive ? 1.4 : 1,
                          ),
                          boxShadow: isPresetActive || isHovered
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withAlpha(
                                      isPresetActive
                                          ? (isHovered ? 55 : 40)
                                          : 20,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPresetActive
                                  ? Icons.check_circle_rounded
                                  : preset.icon,
                              size: 15,
                              color: isPresetActive
                                  ? colors.primary
                                  : (isHovered
                                        ? colors.textPrimary
                                        : colors.textSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              preset.title,
                              style: typography.caption.bold.copyWith(
                                color: isPresetActive
                                    ? colors.primary
                                    : colors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
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

        // ── 4. Selection Counter & Clear All Bar ─────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: selectedSubjects.isNotEmpty
                    ? colors.primary.withAlpha(25)
                    : colors.surfaceSecondary.withAlpha(80),
                borderRadius: AppRadius.radiusBadge,
                border: Border.all(
                  color: selectedSubjects.isNotEmpty
                      ? colors.primary.withAlpha(80)
                      : colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selectedSubjects.isNotEmpty
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 12,
                    color: selectedSubjects.isNotEmpty
                        ? colors.primary
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${selectedSubjects.length} of ${allCourses.length} selected',
                    style: typography.caption.bold.copyWith(
                      color: selectedSubjects.isNotEmpty
                          ? colors.primary
                          : colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedSubjects.isNotEmpty)
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return GestureDetector(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      cubit.clearHighSchoolSubjects();
                    },
                    child: AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? colors.error.withAlpha(20)
                            : colors.transparent,
                        borderRadius: AppRadius.radiusBadge,
                      ),
                      child: Text(
                        'Clear all',
                        style: typography.caption.semiBold.copyWith(
                          color: isHovered
                              ? colors.error
                              : colors.error.withAlpha(220),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 5. Stream Filter Tabs ────────────────────────────────────────────
        if (streams.length > 2) ...[
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: streams.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final stream = streams[index];
                final isSelected = _selectedStream == stream;

                final count = stream == 'All'
                    ? allCourses.length
                    : allCourses
                          .where(
                            (c) =>
                                _cleanStream(c.department).toLowerCase() ==
                                stream.toLowerCase(),
                          )
                          .length;

                return PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return ShrinkableButton(
                      shrinkScale: 0.95,
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        setState(() {
                          _selectedStream = stream;
                        });
                      },
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : isHovered
                              ? (isDark
                                    ? colors.surfaceSecondary.withAlpha(130)
                                    : colors.surfacePrimary)
                              : (isDark
                                    ? colors.surfaceSecondary.withAlpha(90)
                                    : colors.surfacePrimary.withAlpha(180)),
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : isHovered
                                ? (isDark
                                      ? colors.surfaceBorderHighlight
                                      : colors.primary.withAlpha(90))
                                : (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          60,
                                        )
                                      : colors.surfaceBorder),
                          ),
                        ),
                        child: Text(
                          '$stream ($count)',
                          style: typography.caption.bold.copyWith(
                            color: isSelected
                                ? colors.white
                                : (isHovered
                                      ? colors.textPrimary
                                      : colors.textSecondary),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── 6. Subject Cards / Empty State ───────────────────────────────────
        if (filteredCourses.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(60)
                  : colors.surfacePrimary.withAlpha(150),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(40)
                    : colors.surfaceBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: colors.textSecondary.withAlpha(140),
                ),
                const SizedBox(height: 10),
                Text(
                  'No subjects found matching "$_searchQuery"',
                  textAlign: TextAlign.center,
                  style: typography.subhead.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedStream = 'All';
                    });
                  },
                  child: Text(
                    'Reset search & filters',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredCourses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final course = filteredCourses[index];
              final isSelected = selectedSubjects.contains(course.title);
              final streamName = _cleanStream(course.department);
              final accentColor = _parseHexColor(
                course.colorHex,
                colors.primary,
              );

              return _SubjectCard(
                course: course,
                streamName: streamName,
                accentColor: accentColor,
                isSelected: isSelected,
                onTap: () => cubit.toggleHighSchoolSubject(course.title),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Compact high-density subject card with dynamic stream accent,
/// code badge, and smooth animated checkmark.
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.course,
    required this.streamName,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  final CuratedCourseEntity course;
  final String streamName;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final resolvedIcon = resolveCurriculumIcon(course.iconName);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${course.title}, ${course.courseCode}, $streamName',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onTap();
            },
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: AppRadius.radiusPanel,
                color: isSelected
                    ? colors.primary.withAlpha(
                        isDark ? (isHovered ? 72 : 55) : (isHovered ? 40 : 28),
                      )
                    : isHovered
                    ? (isDark
                          ? colors.surfaceSecondary.withAlpha(130)
                          : colors.surfacePrimary)
                    : (isDark
                          ? colors.surfaceSecondary.withAlpha(90)
                          : colors.surfacePrimary.withAlpha(190)),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : isHovered
                      ? (isDark
                            ? colors.surfaceBorderHighlight
                            : colors.primary.withAlpha(90))
                      : (isDark
                            ? colors.surfaceBorderHighlight.withAlpha(60)
                            : colors.surfaceBorder),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected || isHovered
                    ? [
                        BoxShadow(
                          color: colors.primary.withAlpha(
                            isSelected ? (isHovered ? 50 : 35) : 18,
                          ),
                          blurRadius: isHovered ? 12 : 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Subject Icon Container
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(isDark ? 45 : 30),
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: accentColor.withAlpha(80),
                      ),
                    ),
                    child: Icon(
                      resolvedIcon,
                      size: 19,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and Code Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                course.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.subhead.bold.copyWith(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceBorderHighlight.withAlpha(
                                        50,
                                      )
                                    : colors.surfaceBorder.withAlpha(100),
                                borderRadius: AppRadius.radiusMicro,
                              ),
                              child: Text(
                                course.courseCode,
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              streamName,
                              style: typography.caption.semiBold.copyWith(
                                color: accentColor,
                                fontSize: 11.5,
                              ),
                            ),
                            Text(
                              ' • ${course.totalMaterials} materials',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Animated Checkbox
                  AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : colors.transparent,
                      borderRadius: AppRadius.radiusMicro,
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : (isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(120)
                                  : colors.surfaceBorder),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colors.primary.withAlpha(60),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
