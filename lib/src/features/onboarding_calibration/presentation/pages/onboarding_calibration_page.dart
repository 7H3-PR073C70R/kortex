import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/mode_switch_button.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_state.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/academic_focus_step.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_chat_view.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_glass_card.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_step_tracker.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_exam_step.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_subjects_step.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/high_school_timeline_step.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/higher_ed_field_step.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/higher_ed_goals_step.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/higher_ed_level_step.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

@RoutePage()
class OnboardingCalibrationPage extends StatelessWidget {
  const OnboardingCalibrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => locator<CalibrationCubit>()),
        BlocProvider<AuthModeCubit>.value(value: locator<AuthModeCubit>()),
      ],
      child: const _CalibrationView(),
    );
  }
}

class _CalibrationView extends StatelessWidget {
  const _CalibrationView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return BlocListener<CalibrationCubit, CalibrationState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.currentStepIndex != current.currentStepIndex,
      listener: (context, state) {
        if (state.status == CalibrationStatus.completed) {
          unawaited(
            context.router.replaceAll([const OnboardingContentRoute()]),
          );
        } else if (state.status == CalibrationStatus.error &&
            state.errorMessage != null) {
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }

        // Announce step change for screen readers
        final stepTitle = _getStepTitle(state, l10n);
        unawaited(
          // ignore: deprecated_member_use, backward-compatible a11y announcement
          SemanticsService.announce(
            l10n.calibrationStepAnnouncement(
              state.currentStepIndex + 1,
              state.totalSteps,
              stepTitle,
            ),
            TextDirection.ltr,
          ),
        );
      },
      child: Scaffold(
        body: AuraMeshNebula(
          child: SafeArea(
            child: Column(
              children: [
                // Top Bar with Logo, Step Tracker, Skip & Mode Switch Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppAssets.svgs.kortexLogo.svg(
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.appName,
                              style: typography.caption.bold.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 13,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BlocBuilder<CalibrationCubit, CalibrationState>(
                            builder: (ctx, state) {
                              final isChatMode =
                                  context.watch<AuthModeCubit>().state.isChat;
                              if (isChatMode) return const SizedBox.shrink();
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CalibrationStepTracker(
                                    currentStep: state.currentStepIndex,
                                    totalSteps: state.totalSteps,
                                  ),
                                  const SizedBox(width: 8),
                                  Semantics(
                                    button: true,
                                    label: l10n.calibrationSkipSemantics,
                                    child: TextButton(
                                      onPressed: () => unawaited(
                                        ctx
                                            .read<CalibrationCubit>()
                                            .skipCalibration(),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        l10n.calibrationSkip,
                                        style: typography.caption.semiBold
                                            .copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              );
                            },
                          ),
                          ModeSwitchButton(
                            isChatMode:
                                context.watch<AuthModeCubit>().state.isChat,
                            onToggle: () {
                              context.read<AuthModeCubit>().toggleMode();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isChatMode =
                          context.watch<AuthModeCubit>().state.isChat;

                      if (constraints.maxWidth >= 1024) {
                        return _DesktopCalibrationSplitLayout(
                          isChatMode: isChatMode,
                        );
                      } else if (constraints.maxWidth >= 600) {
                        return Center(
                          child: SizedBox(
                            width: 520,
                            child: isChatMode
                                ? const CalibrationChatView()
                                : const _MobileCalibrationLayout(),
                          ),
                        );
                      } else {
                        return isChatMode
                            ? const CalibrationChatView()
                            : const _MobileCalibrationLayout();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStepTitle(CalibrationState state, AppLocalizations l10n) {
    switch (state.currentStepIndex) {
      case 0:
        return l10n.calibrationQuestion1;
      case 1:
        return state.profile.focus == AcademicFocus.higherEducation
            ? l10n.calibrationQuestionA2
            : l10n.calibrationQuestionB2;
      case 2:
        return state.profile.focus == AcademicFocus.higherEducation
            ? l10n.calibrationQuestionA3
            : l10n.calibrationQuestionB3;
      case 3:
        return state.profile.focus == AcademicFocus.higherEducation
            ? l10n.calibrationQuestionA4
            : l10n.calibrationQuestionB4;
      default:
        return l10n.calibrationTitle;
    }
  }
}

class _MobileCalibrationLayout extends StatelessWidget {
  const _MobileCalibrationLayout();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final state = context.watch<CalibrationCubit>().state;
    final isLastStep = state.currentStepIndex == state.totalSteps - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Smooth Physics-Based Transition Container
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: CalibrationGlassCard(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        ?currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final isCurrentChild = child.key ==
                        ValueKey<int>(state.currentStepIndex);
                    final offsetTween = isCurrentChild
                        ? Tween<Offset>(
                            begin: Offset(
                              state.isForwardTrajectory ? 0.05 : -0.05,
                              0,
                            ),
                            end: Offset.zero,
                          ).chain(CurveTween(curve: Curves.easeOutCubic))
                        : Tween<Offset>(
                            begin: Offset(
                              state.isForwardTrajectory ? -0.05 : 0.05,
                              0,
                            ),
                            end: Offset.zero,
                          ).chain(CurveTween(curve: Curves.easeInCubic));

                    return SlideTransition(
                      position: animation.drive(offsetTween),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(state.currentStepIndex),
                    child: _buildActiveStep(state),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Navigation Buttons
          Row(
            children: [
              if (state.currentStepIndex > 0) ...[
                Expanded(
                  flex: 3,
                  child: AppButton(
                    text: l10n.calibrationBack,
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      context.read<CalibrationCubit>().previousStep();
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 5,
                child: AppButton(
                  text: isLastStep
                      ? l10n.calibrationFinish
                      : l10n.calibrationContinue,
                  isLoading: state.isSubmitting,
                  onPressed: state.canProceed
                      ? () {
                          context.read<CalibrationCubit>().nextStep();
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStep(CalibrationState state) {
    switch (state.currentStepIndex) {
      case 0:
        return const AcademicFocusStep();
      case 1:
        return state.profile.focus == AcademicFocus.higherEducation
            ? const HigherEdLevelStep()
            : const HighSchoolExamStep();
      case 2:
        return state.profile.focus == AcademicFocus.higherEducation
            ? const HigherEdFieldStep()
            : const HighSchoolSubjectsStep();
      case 3:
        return state.profile.focus == AcademicFocus.higherEducation
            ? const HigherEdGoalsStep()
            : const HighSchoolTimelineStep();
      default:
        return const AcademicFocusStep();
    }
  }
}

class _DesktopCalibrationSplitLayout extends StatelessWidget {
  const _DesktopCalibrationSplitLayout({required this.isChatMode});

  final bool isChatMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Row(
      children: [
        // Left Column: Syllabot AI Calibration Graphics (60% split)
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      AppAssets.svgs.kortexLogo.path,
                      height: 32,
                      width: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'KORTEXIFY AI',
                      style: typography.headline.bold.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const AppBadge(
                  label: 'NEURAL CALIBRATION IN PROGRESS',
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.calibrationDesktopHeroTitle,
                  style: typography.largeTitle.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 34,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.calibrationDesktopHeroSubtitle,
                  style: typography.body.regular.copyWith(
                    color: colors.textSecondary,
                    height: 1.5,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                _buildMetricCard(
                  icon: Icons.hub_rounded,
                  title: l10n.calibrationDesktopMetric1,
                  colors: colors,
                  typography: typography,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildMetricCard(
                  icon: Icons.code_rounded,
                  title: l10n.calibrationDesktopMetric2,
                  colors: colors,
                  typography: typography,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildMetricCard(
                  icon: Icons.auto_graph_rounded,
                  title: l10n.calibrationDesktopMetric3,
                  colors: colors,
                  typography: typography,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        // Right Column: Interactive Calibration Wizard (40% split)
        Expanded(
          flex: 4,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: isChatMode
                  ? const CalibrationChatView()
                  : const _MobileCalibrationLayout(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? colors.surfaceSecondary.withAlpha(120)
            : colors.surfacePrimary.withAlpha(190),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(70)
              : colors.surfaceBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Text(
            title,
            style: typography.callout.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
