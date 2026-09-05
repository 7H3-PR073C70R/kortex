import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_option_chip.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/curriculum_icon_resolver.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question A4: Multiselect support goals — covers STEM & non-STEM.
class HigherEdGoalsStep extends StatelessWidget {
  const HigherEdGoalsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final state = context.watch<CalibrationCubit>().state;
    final selectedGoals = state.profile.higherEdGoals;
    final backendGoals = state.studyGoals;

    final goals = backendGoals.isNotEmpty
        ? backendGoals.map((e) {
            return (
              e.displayName,
              e.subtitle,
              resolveCurriculumIcon(e.iconName, Icons.article_rounded),
            );
          }).toList()
        : [
            (
              l10n.calibrationGoalThesis,
              'Literature citations, methodology synthesis, paper drafting',
              Icons.article_rounded,
            ),
            (
              l10n.calibrationGoalCaseLaw,
              'Case briefs, statute analysis, essay argument structure',
              Icons.gavel_rounded,
            ),
            (
              l10n.calibrationGoalSocratic,
              'Interactive step-by-step problem solving without spoilers',
              Icons.psychology_rounded,
            ),
            (
              l10n.calibrationGoalSpacedRep,
              'Automated SM-2 review scheduling for lecture decks',
              Icons.schedule_rounded,
            ),
            (
              l10n.calibrationGoalMockExams,
              'Timed exam simulation calibrated to course syllabi',
              Icons.timer_outlined,
            ),
            (
              l10n.calibrationGoalEssayPrep,
              'Structured essay outlines, argument mapping, citation help',
              Icons.edit_note_rounded,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calibrationQuestionA4,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.calibrationQuestionA4Subtitle,
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        ...goals.map((goal) {
          final isSelected = selectedGoals.contains(goal.$1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CalibrationOptionChip(
              title: goal.$1,
              subtitle: goal.$2,
              icon: goal.$3,
              isMultiSelect: true,
              isSelected: isSelected,
              onTap: () {
                context.read<CalibrationCubit>().toggleHigherEdGoal(goal.$1);
              },
            ),
          );
        }),
      ],
    );
  }
}
