import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_option_chip.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question B2: Target standardized examination.
class HighSchoolExamStep extends StatelessWidget {
  const HighSchoolExamStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final selectedExam =
        context.watch<CalibrationCubit>().state.profile.highSchoolExam;

    final exams = [
      (
        l10n.calibrationExamJAMB,
        'Unified Tertiary Matriculation Examination',
        Icons.quiz_rounded,
      ),
      (
        l10n.calibrationExamWAEC,
        'West African Senior School Certificate Examination',
        Icons.school_rounded,
      ),
      (
        l10n.calibrationExamNECO,
        'National Examination Council Senior School Certificate',
        Icons.assignment_turned_in_rounded,
      ),
      (
        l10n.calibrationExamSAT,
        'College Board SAT Reasoning & Subject Tests',
        Icons.public_rounded,
      ),
      (
        l10n.calibrationExamIGCSE,
        'Cambridge IGCSE, AS & A-Levels Syllabus',
        Icons.military_tech_rounded,
      ),
      (
        l10n.calibrationExamIELTS,
        'English Language Proficiency Certification',
        Icons.translate_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calibrationQuestionB2,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your primary target to load past paper question banks',
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        ...exams.map((exam) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CalibrationOptionChip(
              title: exam.$1,
              subtitle: exam.$2,
              icon: exam.$3,
              isSelected: selectedExam == exam.$1,
              onTap: () {
                context.read<CalibrationCubit>().setHighSchoolExam(exam.$1);
              },
            ),
          );
        }),
      ],
    );
  }
}
