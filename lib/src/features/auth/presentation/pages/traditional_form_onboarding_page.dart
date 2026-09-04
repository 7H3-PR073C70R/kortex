import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/onboarding_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/goal_calibration_slider.dart';
import 'package:kortex/src/features/auth/presentation/widgets/track_selector_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Stepper form onboarding page synchronized with the AI chat state.
class TraditionalFormOnboardingPage extends StatelessWidget {
  const TraditionalFormOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();

        return Column(
          children: [
            // Stepper Header Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: List.generate(3, (index) {
                  final isActive = index <= state.currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colors.primary
                            : colors.surfaceTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Stepper Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.currentStep == 0) ...[
                      Text(
                        l10n.onboardingStepTrackTitle,
                        style: typography.title1.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.selectCourseTrackDesc,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...state.tracks.map((track) {
                        final isSelected = state.selectedTrack == track.id;
                        return TrackSelectorCard(
                          track: track,
                          isSelected: isSelected,
                          onTap: () => cubit.selectTrack(track.id),
                        );
                      }),
                    ] else if (state.currentStep == 1) ...[
                      Text(
                        l10n.onboardingStepGoalTitle,
                        style: typography.title1.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.dailyTargetCardGoalDesc,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GoalCalibrationSlider(
                        dailyTarget: state.dailyTarget,
                        retentionBenchmark: state.retentionBenchmark,
                        onTargetChanged: cubit.updateDailyTarget,
                        onRetentionChanged: cubit.updateRetentionBenchmark,
                      ),
                    ] else ...[
                      Text(
                        'Curriculum Confirmation',
                        style: typography.title1.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Review your calibrated academic parameters before '
                        'launching.',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 60 : 30),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Curriculum Track',
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  state.currentTrackEntity.name,
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daily Flashcard Target',
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${state.dailyTarget} cards / day',
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Retention Benchmark',
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${(state.retentionBenchmark * 100).round()}'
                                  '%',
                                  style: typography.body.bold.copyWith(
                                    color: colors.syllabotAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Navigation Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                border: Border(
                  top: BorderSide(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (state.currentStep > 0) ...[
                      IconButton(
                        onPressed: cubit.previousStep,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ShrinkableButton(
                        onTap: state.isLoading
                            ? null
                            : () {
                                if (state.currentStep < 2) {
                                  cubit.nextStep();
                                } else {
                                  unawaited(cubit.completeOnboarding());
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary,
                                colors.primary.withAlpha(220),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: state.isLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.white,
                                    ),
                                  )
                                : Text(
                                    state.currentStep == 2
                                        ? l10n.completeAndGoToDashboard
                                        : l10n.continueButton,
                                    style: typography.body.bold.copyWith(
                                      color: colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
