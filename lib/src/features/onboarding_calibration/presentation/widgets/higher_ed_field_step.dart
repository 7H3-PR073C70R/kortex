import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_option_chip.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question A3: Field of study — expanded to all major faculties.
class HigherEdFieldStep extends StatelessWidget {
  const HigherEdFieldStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final selectedField = context
        .watch<CalibrationCubit>()
        .state
        .profile
        .higherEdField;

    final fields = [
      (
        l10n.calibrationFieldComputerScience,
        'Algorithms, Data Structures, AI/ML, Distributed Systems',
        Icons.memory_rounded,
      ),
      (
        l10n.calibrationFieldMedicine,
        'Anatomy, Biochemistry, Pharmacology, Pathology, Surgery',
        Icons.medical_services_rounded,
      ),
      (
        l10n.calibrationFieldLaw,
        'Case Law, Constitutional Law, Jurisprudence, Legal Writing',
        Icons.gavel_rounded,
      ),
      (
        l10n.calibrationFieldBusiness,
        'Finance, Accounting, Economics, Management, Marketing',
        Icons.business_center_rounded,
      ),
      (
        l10n.calibrationFieldHumanities,
        'Literature, History, Philosophy, Linguistics, Cultural Studies',
        Icons.menu_book_rounded,
      ),
      (
        l10n.calibrationFieldSocialSciences,
        'Sociology, Political Science, Psychology, Geography',
        Icons.groups_rounded,
      ),
      (
        l10n.calibrationFieldMath,
        'Calculus, Linear Algebra, Statistics, Probability Theory',
        Icons.functions_rounded,
      ),
      (
        l10n.calibrationFieldPhysics,
        'Quantum Mechanics, Thermodynamics, Electromagnetism',
        Icons.blur_on_rounded,
      ),
      (
        l10n.calibrationFieldChemEng,
        'Organic Synthesis, Fluid Mechanics, Reaction Kinetics',
        Icons.science_rounded,
      ),
      (
        l10n.calibrationFieldRobotics,
        'Control Theory, Mechatronics, Kinematics, Dynamics',
        Icons.precision_manufacturing_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calibrationQuestionA3,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.calibrationQuestionA3Subtitle,
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        ...fields.map((field) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CalibrationOptionChip(
              title: field.$1,
              subtitle: field.$2,
              icon: field.$3,
              isSelected: selectedField == field.$1,
              onTap: () {
                context.read<CalibrationCubit>().setHigherEdField(field.$1);
              },
            ),
          );
        }),
      ],
    );
  }
}
