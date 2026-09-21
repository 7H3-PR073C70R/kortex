import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/app_guided_tour_overlay.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

class HeaderProfileBar extends StatelessWidget {
  const HeaderProfileBar({
    required this.analytics,
    required this.isProfileUncalibrated,
    this.userName,
    this.userPhotoUrl,
    super.key,
  });

  final AnalyticsSummaryEntity analytics;
  final bool isProfileUncalibrated;
  final String? userName;
  final String? userPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final authState = context.watch<AuthBloc?>()?.state;
    final authProfile = authState?.userProfile;
    final effectiveName =
        userName ?? authProfile?.displayName ?? authState?.user?.displayName;
    final effectivePhoto =
        userPhotoUrl ?? authProfile?.photoUrl ?? authState?.user?.photoUrl;

    final displayName =
        (effectiveName != null && effectiveName.trim().isNotEmpty)
        ? effectiveName.trim().split(' ').first
        : l10n.dashboardScholarFallback;

    final effectiveStreak =
        (authProfile?.streakDays != null && authProfile!.streakDays > 0)
        ? authProfile.streakDays
        : analytics.currentStreakDays;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Bar with User Avatar, Name Greeting & Streak Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: User Greeting & Rank
            Expanded(
              child: ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  unawaited(
                    context.navigateTo(
                      const MainRoute(children: [ProfileRoute()]),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Semantics(
                      label: l10n.dashboardHeyUser(displayName),
                      image: true,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 160 : 200),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.black.withAlpha(isDark ? 50 : 20),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AppAvatar(
                          customDimension: 42,
                          imageUrl: effectivePhoto,
                          name: effectiveName ?? displayName,
                          borderWidth: 0,
                          backgroundColor: colors.primary.withAlpha(25),
                          foregroundColor: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.dashboardHeyUser(displayName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.headline.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.success,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  analytics.academicRank,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.footnote.medium.copyWith(
                                    color: isDark
                                        ? colors.textSecondary
                                        : colors.textPrimary.withAlpha(190),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right: Streak Counter & Analytics Shortcut
            Row(
              children: [
                // Study Streak Pill
                Semantics(
                  label: l10n.dashboardStreakTooltip(
                    effectiveStreak,
                  ),
                  button: true,
                  child: PlatformHoverBuilder(
                    builder: (context, isHovered, child) {
                      return ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          unawaited(
                            context.router.push(const AnalyticsDetailRoute()),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.panel),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: AppMotion.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.panel,
                                ),
                                color: isDark
                                    ? (isHovered
                                          ? colors.surfaceSecondary.withAlpha(
                                              200,
                                            )
                                          : colors.surfaceSecondary.withAlpha(
                                              150,
                                            ))
                                    : (isHovered
                                          ? colors.surfacePrimary
                                          : colors.surfacePrimary.withAlpha(
                                              210,
                                            )),
                                border: Border.all(
                                  color: isHovered
                                      ? colors.warning.withAlpha(
                                          isDark ? 120 : 90,
                                        )
                                      : colors.surfaceBorder.withAlpha(
                                          isDark ? 60 : 35,
                                        ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 18,
                                    color: colors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$effectiveStreak',
                                    style: typography.callout.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Millionaire Ascent Arcade Shortcut
                _HeaderIconButton(
                  icon: Icons.military_tech_rounded,
                  color: colors.warning,
                  tooltip: 'Millionaire Ascent Arcade',
                  borderHighlightColor: colors.warning,
                  onTap: () {
                    unawaited(HapticFeedback.mediumImpact());
                    unawaited(
                      context.router.push(
                        QuizWorkspaceRoute(
                          deckId: 'arcade_global',
                          deckTitle: 'Daily Dopamine Arcade',
                          assessmentMode: AssessmentMode.millionaireMode,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Walkthrough Tour Shortcut
                _HeaderIconButton(
                  icon: Icons.explore_rounded,
                  color: colors.syllabotAccent,
                  tooltip: 'Feature Walkthrough',
                  borderHighlightColor: colors.syllabotAccent,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    unawaited(
                      showDialog<void>(
                        context: context,
                        builder: (_) => WelcomeWalkthroughDialog(
                          onEnterWorkspace: () {
                            if (context.mounted) {
                              unawaited(
                                AppGuidedTourOverlay.start(
                                  context,
                                  force: true,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Analytics Shortcut
                _HeaderIconButton(
                  icon: Icons.insights_rounded,
                  color: colors.primary,
                  tooltip: l10n.dashboardViewAnalyticsSemantics,
                  borderHighlightColor: colors.primary,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    unawaited(
                      context.router.push(const AnalyticsDetailRoute()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // 2. Sticky Uncalibrated Profile Banner (If user skipped calibration)
        if (isProfileUncalibrated) ...[
          const SizedBox(height: 14),
          Semantics(
            container: true,
            label: l10n.dashboardUncalibratedSemantics,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.panel),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.panel),
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withAlpha(isDark ? 55 : 30),
                        colors.syllabotAccent.withAlpha(isDark ? 35 : 18),
                      ],
                    ),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 100 : 70),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SyllabotAvatar(size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.dashboardUncalibratedTitle,
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.dashboardUncalibratedSubtitle,
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          unawaited(
                            context.router.push(
                              const OnboardingCalibrationRoute(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                          ),
                          child: Text(
                            l10n.dashboardCalibrateButton,
                            style: typography.caption.bold.copyWith(
                              color: colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.borderHighlightColor,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final Color? borderHighlightColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return ShrinkableButton(
              onTap: onTap,
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? (isHovered
                            ? colors.surfaceSecondary.withAlpha(220)
                            : colors.surfaceSecondary.withAlpha(150))
                      : (isHovered
                            ? colors.surfacePrimary
                            : colors.surfacePrimary.withAlpha(210)),
                  border: Border.all(
                    color: isHovered
                        ? (borderHighlightColor ?? colors.primary).withAlpha(
                            isDark ? 140 : 100,
                          )
                        : colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
