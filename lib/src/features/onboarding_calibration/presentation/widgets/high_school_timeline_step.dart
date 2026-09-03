import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_option_chip.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question B4: Exam timeline for study scheduling.
class HighSchoolTimelineStep extends StatelessWidget {
  const HighSchoolTimelineStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final selectedTimeline = context
        .watch<CalibrationCubit>()
        .state
        .profile
        .highSchoolTimeline;

    final timelines = [
      (
        l10n.calibrationTimeline1Month,
        'Intensive daily cramming & high-yield revision mode',
        Icons.local_fire_department_rounded,
      ),
      (
        l10n.calibrationTimeline3Months,
        'Balanced SM-2 interval pacing & weekly mock exams',
        Icons.speed_rounded,
      ),
      (
        l10n.calibrationTimeline6Months,
        'Comprehensive syllabus breakdown & deep concept mastery',
        Icons.calendar_month_rounded,
      ),
      (
        l10n.calibrationTimelineNextYear,
        'Long-term mastery & foundation building',
        Icons.hourglass_top_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calibrationQuestionB4,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Syllabot will adjust your spaced repetition intervals to fit your '
          'exam deadline',
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        ...timelines.map((timeline) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CalibrationOptionChip(
              title: timeline.$1,
              subtitle: timeline.$2,
              icon: timeline.$3,
              isSelected: selectedTimeline == timeline.$1,
              onTap: () {
                context.read<CalibrationCubit>().setHighSchoolTimeline(
                  timeline.$1,
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
