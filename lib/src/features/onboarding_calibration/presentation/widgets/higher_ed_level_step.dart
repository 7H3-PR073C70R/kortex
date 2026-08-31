import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_option_chip.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question A2: Academic degree level for higher institution users.
class HigherEdLevelStep extends StatelessWidget {
  const HigherEdLevelStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final selectedLevel =
        context.watch<CalibrationCubit>().state.profile.higherEdLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calibrationQuestionA2,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your degree or certification program',
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        CalibrationOptionChip(
          title: l10n.calibrationOptionBSc,
          icon: Icons.history_edu_rounded,
          isSelected: selectedLevel == HigherEdLevel.bsc,
          onTap: () {
            context
                .read<CalibrationCubit>()
                .setHigherEdLevel(HigherEdLevel.bsc);
          },
        ),
        const SizedBox(height: 12),
        CalibrationOptionChip(
          title: l10n.calibrationOptionMSc,
          icon: Icons.workspace_premium_rounded,
          isSelected: selectedLevel == HigherEdLevel.msc,
          onTap: () {
            context
                .read<CalibrationCubit>()
                .setHigherEdLevel(HigherEdLevel.msc);
          },
        ),
        const SizedBox(height: 12),
        CalibrationOptionChip(
          title: l10n.calibrationOptionPhD,
          icon: Icons.psychology_alt_rounded,
          isSelected: selectedLevel == HigherEdLevel.phd,
          onTap: () {
            context
                .read<CalibrationCubit>()
                .setHigherEdLevel(HigherEdLevel.phd);
          },
        ),
        const SizedBox(height: 12),
        CalibrationOptionChip(
          title: l10n.calibrationOptionOND,
          icon: Icons.menu_book_rounded,
          isSelected: selectedLevel == HigherEdLevel.ond,
          onTap: () {
            context
                .read<CalibrationCubit>()
                .setHigherEdLevel(HigherEdLevel.ond);
          },
        ),
        const SizedBox(height: 12),
        CalibrationOptionChip(
          title: l10n.calibrationOptionHND,
          icon: Icons.auto_stories_rounded,
          isSelected: selectedLevel == HigherEdLevel.hnd,
          onTap: () {
            context
                .read<CalibrationCubit>()
                .setHigherEdLevel(HigherEdLevel.hnd);
          },
        ),
      ],
    );
  }
}
