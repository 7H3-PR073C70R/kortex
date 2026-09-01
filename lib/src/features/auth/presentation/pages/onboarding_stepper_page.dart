import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/onboarding_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/goal_calibration_slider.dart';
import 'package:kortex/src/features/auth/presentation/widgets/track_selector_card.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class OnboardingStepperPage extends StatelessWidget {
  const OnboardingStepperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingCubit(
        completeOnboardingUseCase: locator<CompleteOnboardingUseCase>(),
      ),
      child: const _OnboardingStepperView(),
    );
  }
}

class _OnboardingStepperView extends StatelessWidget {
  const _OnboardingStepperView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        if (state.isCompleted) {
          // Synchronize Dashboard Bloc
          locator<DashboardBloc>().add(const DashboardStarted());
          unawaited(context.router.replace(const MainRoute()));
        } else if (state.status == OnboardingStatus.error &&
            state.errorMessage != null) {
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();

        return Scaffold(
          backgroundColor:
              isDark ? colors.backgroundPrimary : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: state.currentStep > 0
                ? IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: colors.textPrimary,
                    ),
                    onPressed: cubit.previousStep,
                  )
                : null,
            title: Text(
              l10n.onboardingStepIndicator(state.currentStep + 1, 3),
              style: typography.footnote.bold.copyWith(
                color: colors.textSecondary,
              ),
            ),
            centerTitle: true,
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
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
                      width: double.infinity,
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
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.currentStep == 2
                                        ? l10n.completeOnboardingButton
                                        : l10n.continueButton,
                                    style: typography.body.bold.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Bar Header
                      Row(
                        children: List.generate(3, (index) {
                          final isActive = index <= state.currentStep;
                          return Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.only(
                                right: index < 2 ? 8 : 0,
                              ),
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
                      const SizedBox(height: 28),

                      // Step Content Views
                      if (state.currentStep == 0) ...[
                        Text(
                          l10n.selectCourseTrackPrompt,
                          style: typography.title1.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.selectCourseTrackDesc,
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
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
                          'Calibrate Daily Pace',
                          style: typography.title1.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select your target daily active recall workload '
                          'to keep your memory curves primed.',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GoalCalibrationSlider(
                          dailyTarget: state.dailyTarget,
                          retentionBenchmark: state.retentionBenchmark,
                          onTargetChanged: cubit.updateDailyTarget,
                          onRetentionChanged: cubit.updateRetentionBenchmark,
                        ),
                      ] else ...[
                        // Step 2: Confirmation & Summary
                        Text(
                          'Ready to Excel',
                          style: typography.title1.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your personalized study curriculum is configured.',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary.withAlpha(isDark ? 50 : 30),
                                colors.syllabotAccent
                                    .withAlpha(isDark ? 40 : 20),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colors.primary
                                  .withAlpha(isDark ? 60 : 35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withAlpha(40),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.verified_rounded,
                                      color: colors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          state.currentTrackEntity.name,
                                          style: typography.title3.bold
                                              .copyWith(
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Focus Track',
                                          style: typography.caption.medium
                                              .copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Divider(),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Daily Card Target',
                                    style: typography.footnote.regular
                                        .copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${state.dailyTarget} cards/day',
                                    style: typography.footnote.bold
                                        .copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final pct =
                                      (state.retentionBenchmark * 100).round();
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Expected Retention Rate',
                                        style: typography.footnote.regular
                                            .copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '$pct%',
                                        style: typography.footnote.bold
                                            .copyWith(
                                          color: colors.syllabotAccent,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
