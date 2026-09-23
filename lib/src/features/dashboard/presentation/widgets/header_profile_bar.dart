import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
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
    final neural = context.neural;
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

    final trimmedName = effectiveName?.trim() ?? '';
    final initials = trimmedName.isEmpty
        ? 'KO'
        : trimmedName.substring(0, 2).toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Bar with Identity Chip, Greeting & Quick Status Metrics
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
                  children:
                      <Widget>[
                            Semantics(
                              label: l10n.dashboardHeyUser(displayName),
                              image: true,
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            neural.amber200.withAlpha(51),
                                            neural.emerald.withAlpha(26),
                                            context.colors.transparent,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: neural.glowEmerald,
                                            blurRadius: 20,
                                            spreadRadius: -5,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: neural.obsidian850,
                                            border: Border.all(
                                              color: neural.hairlineStrong,
                                            ),
                                          ),
                                          child: effectivePhoto != null
                                              ? AppAvatar(
                                                  customDimension: 45,
                                                  imageUrl: effectivePhoto,
                                                  name:
                                                      effectiveName ??
                                                      displayName,
                                                  borderWidth: 0,
                                                  backgroundColor:
                                                      neural.obsidian850,
                                                  foregroundColor:
                                                      neural.amber300,
                                                )
                                              : Center(
                                                  child: Text(
                                                    initials,
                                                    style: typography
                                                        .caption
                                                        .bold
                                                        .copyWith(
                                                          color:
                                                              neural.amber300,
                                                          fontSize: 14,
                                                          letterSpacing: 0.5,
                                                        ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -1,
                                      right: -1,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: neural.emerald,
                                          border: Border.all(
                                            color: neural.obsidian950,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          l10n.dashboardHeyUser(displayName),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typography.headline.bold
                                              .copyWith(
                                                color: neural.slate100,
                                                fontSize: 16,
                                                height: 1.15,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 14,
                                        color: neural.amber400,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: neural.emerald400,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          analytics.academicRank,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typography.footnote.medium
                                              .copyWith(
                                                color: neural.slate400,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: neural.emerald.withAlpha(26),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: neural.emerald.withAlpha(51),
                                          ),
                                        ),
                                        child: Text(
                                          'LVL ${authProfile?.level ?? 1}',
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: neural.emerald400,
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ]
                          .animate(interval: 60.ms)
                          .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
                          .slideX(begin: -0.05, end: 0),
                ),
              ),
            ),

            // Right: Streak Counter & Analytics Shortcut
            Row(
              children:
                  <Widget>[
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
                                    context.router.push(
                                      const AnalyticsDetailRoute(),
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  curve: AppMotion.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: neural.obsidian850.withAlpha(
                                      230,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: neural.amber.withAlpha(
                                        isHovered ? 140 : 77,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: neural.glowAmber,
                                        blurRadius: 20,
                                        spreadRadius: -5,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 16,
                                        color: neural.amber400,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$effectiveStreak',
                                        style: typography.callout.bold.copyWith(
                                          color: neural.amber300,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Discovery / Walkthrough Shortcut (compass)
                        _HeaderIconButton(
                          icon: Icons.explore_rounded,
                          color: neural.cyan400,
                          tooltip: 'Feature Walkthrough',
                          borderHighlightColor: neural.cyan,
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
                        const SizedBox(width: 6),

                        // Analytics Shortcut (activity pulse)
                        _HeaderIconButton(
                          icon: Icons.show_chart_rounded,
                          color: neural.emerald400,
                          tooltip: l10n.dashboardViewAnalyticsSemantics,
                          borderHighlightColor: neural.emerald,
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(
                              context.router.push(const AnalyticsDetailRoute()),
                            );
                          },
                        ),
                      ]
                      .animate(interval: 50.ms)
                      .fadeIn(duration: 300.ms)
                      .scaleXY(
                        begin: 0.9,
                        end: 1,
                        curve: Curves.easeOutCubic,
                      ),
            ),
          ],
        ),

        // 2. Sticky Uncalibrated Profile Banner (If user skipped calibration)
        if (isProfileUncalibrated) ...[
          const SizedBox(height: 14),
          Semantics(
            container: true,
            label: l10n.dashboardUncalibratedSemantics,
            child:
                ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadius.panel,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                colors.primary.withAlpha(isDark ? 55 : 30),
                                colors.syllabotAccent.withAlpha(
                                  isDark ? 35 : 18,
                                ),
                              ],
                            ),
                            border: Border.all(
                              color: colors.primary.withAlpha(
                                isDark ? 100 : 70,
                              ),
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
                                      style: typography.footnote.regular
                                          .copyWith(
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
                    )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.1, end: 0, curve: Curves.easeOutQuint),
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
    final neural = context.neural;

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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: neural.obsidian850.withAlpha(
                    isHovered ? 255 : 230,
                  ),
                  border: Border.all(
                    color: isHovered
                        ? (borderHighlightColor ?? neural.emerald).withAlpha(
                            110,
                          )
                        : neural.hairlineStrong,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
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
