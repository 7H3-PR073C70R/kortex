import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

class HeaderProfileBar extends StatelessWidget {
  const HeaderProfileBar({
    required this.analytics,
    required this.isProfileUncalibrated,
    this.userName,
    super.key,
  });

  final AnalyticsSummaryEntity analytics;
  final bool isProfileUncalibrated;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final displayName = (userName != null && userName!.trim().isNotEmpty)
        ? userName!.trim().split(' ').first
        : 'Scholar';

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
              child: Row(
                children: [
                  Semantics(
                    label: 'User profile avatar for $displayName',
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
                            color: colors.primary.withAlpha(isDark ? 80 : 30),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image(
                          image: AppAssets.images.syllabotAvatar.provider(),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hey, $displayName 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.syllabotAccent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                analytics.academicRank,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.footnote.medium.copyWith(
                                  color: colors.textSecondary,
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

            // Right: Streak Counter & XP Badge
            Row(
              children: [
                // Study Streak Pill
                Semantics(
                  label: '${analytics.currentStreakDays} day study streak',
                  container: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isDark
                              ? colors.surfaceSecondary.withAlpha(160)
                              : colors.surfacePrimary.withAlpha(210),
                          border: Border.all(
                            color: isDark
                                ? colors.surfaceBorderHighlight.withAlpha(80)
                                : colors.surfaceBorder.withAlpha(140),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 18,
                              color: Color(0xFFF97316),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${analytics.currentStreakDays}',
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
                ),
                const SizedBox(width: 8),

                // Notifications or Profile Shortcut
                Semantics(
                  button: true,
                  label: 'View detailed study analytics and streaks',
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        context.router.push(const AnalyticsDetailRoute()),
                      );
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? colors.surfaceSecondary.withAlpha(160)
                            : colors.surfacePrimary.withAlpha(210),
                        border: Border.all(
                          color: isDark
                              ? colors.surfaceBorderHighlight.withAlpha(70)
                              : colors.surfaceBorder.withAlpha(130),
                        ),
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                  ),
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
            label:
                'Profile is not calibrated. '
                'Tap to configure your academic track.',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withAlpha(isDark ? 60 : 35),
                        colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                      ],
                    ),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 120 : 90),
                      width: 1.2,
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
                              'Calibrate Your Neural Workspace',
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tailor past papers, flashcards & exam '
                              'simulator to your exact course.',
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
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withAlpha(80),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Calibrate',
                            style: typography.caption.bold.copyWith(
                              color: Colors.white,
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
