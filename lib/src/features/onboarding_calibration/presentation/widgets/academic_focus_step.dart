import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_option_chip.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question 1: Universal Branching Step (University vs High School).
class AcademicFocusStep extends StatelessWidget {
  const AcademicFocusStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final selectedFocus = context.watch<CalibrationCubit>().state.profile.focus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calibrationQuestion1,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.calibrationSubtitle,
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        CalibrationOptionChip(
          title: l10n.calibrationOptionUniversity,
          subtitle: 'Higher research, thesis support & undergraduate degrees',
          icon: Icons.account_balance_rounded,
          isSelected: selectedFocus == AcademicFocus.higherEducation,
          onTap: () {
            context.read<CalibrationCubit>().setAcademicFocus(
              AcademicFocus.higherEducation,
            );
          },
        ),
        const SizedBox(height: 14),
        CalibrationOptionChip(
          title: l10n.calibrationOptionHighSchool,
          subtitle: 'Standardized exams, syllabus revision & mock test drills',
          icon: Icons.school_rounded,
          isSelected: selectedFocus == AcademicFocus.highSchool,
          onTap: () {
            context.read<CalibrationCubit>().setAcademicFocus(
              AcademicFocus.highSchool,
            );
          },
        ),
      ],
    );
  }
}
