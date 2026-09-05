import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_option_chip.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/curriculum_icon_resolver.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question A2: Academic degree level for higher institution users.
class HigherEdLevelStep extends StatelessWidget {
  const HigherEdLevelStep({super.key});

  HigherEdLevel? _parseHigherEdLevel(String code) {
    switch (code.toLowerCase()) {
      case 'bsc':
        return HigherEdLevel.bsc;
      case 'msc':
        return HigherEdLevel.msc;
      case 'phd':
        return HigherEdLevel.phd;
      case 'ond':
        return HigherEdLevel.ond;
      case 'hnd':
        return HigherEdLevel.hnd;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final state = context.watch<CalibrationCubit>().state;
    final selectedLevel = state.profile.higherEdLevel;
    final backendLevels = state.higherEdLevels;

    final levelItems = backendLevels.isNotEmpty
        ? backendLevels
            .map((e) {
              final level = _parseHigherEdLevel(
                (e.metadata['code'] as String?) ?? e.key,
              );
              if (level == null) return null;
              return (
                e.displayName,
                resolveCurriculumIcon(e.iconName, Icons.history_edu_rounded),
                level,
              );
            })
            .whereType<(String, IconData, HigherEdLevel)>()
            .toList()
        : [
            (l10n.calibrationOptionBSc, Icons.history_edu_rounded, HigherEdLevel.bsc),
            (l10n.calibrationOptionMSc, Icons.workspace_premium_rounded, HigherEdLevel.msc),
            (l10n.calibrationOptionPhD, Icons.psychology_alt_rounded, HigherEdLevel.phd),
            (l10n.calibrationOptionOND, Icons.menu_book_rounded, HigherEdLevel.ond),
            (l10n.calibrationOptionHND, Icons.auto_stories_rounded, HigherEdLevel.hnd),
          ];

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
        ...levelItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CalibrationOptionChip(
              title: item.$1,
              icon: item.$2,
              isSelected: selectedLevel == item.$3,
              onTap: () {
                context.read<CalibrationCubit>().setHigherEdLevel(item.$3);
              },
            ),
          );
        }),
      ],
    );
  }
}
