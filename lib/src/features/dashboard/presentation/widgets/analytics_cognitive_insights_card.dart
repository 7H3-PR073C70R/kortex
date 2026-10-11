import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

/// Syllabot Cognitive Insights & Action Recommendations.
class AnalyticsCognitiveInsightsCard extends StatelessWidget {
  const AnalyticsCognitiveInsightsCard({
    required this.insightText,
    required this.hasData,
    required this.colors,
    required this.isDark,
    this.activityService,
    this.subscriptionGuard,
    super.key,
  });

  final String? insightText;
  final bool hasData;
  final AppThemeColorsExtension colors;
  final bool isDark;
  final UserActivityService? activityService;
  final SubscriptionGuard? subscriptionGuard;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final breakdown = activityService?.getSubjectBreakdown() ?? const {};
    final weakEntry = breakdown.entries
        .where((e) => e.value.avgRetention < 0.80)
        .firstOrNull;
    final guard = subscriptionGuard ?? SubscriptionGuard();
    final isPro = guard.canAccessAiDiagnostics();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withAlpha(isDark ? 40 : 20),
                (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
                    .withAlpha(isDark ? 160 : 220),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 80 : 50),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SyllabotAvatar(size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Syllabot Cognitive Diagnostics',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (!isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withAlpha(200),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Text(
                        'PRO',
                        style: typography.caption.bold.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (!isPro) ...[
                InsightRow(
                  icon: Icons.psychology_rounded,
                  iconColor: colors.primary,
                  title: 'Cognitive Retention Spaced Tracking',
                  description:
                      'Daily spaced reviews protect against memory fade and promote long-term recall. '
                      'Upgrade to Kortex Pro to unlock automated subject decay alerts, personalized cram targets, and deep Ebbinghaus synthesis.',
                  colors: colors,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 30 : 16),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 80 : 50),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unlock Deep AI Diagnostics',
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Targeted subject intervention & exam cram forecasting.',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          AppFeedback.selection();
                          unawaited(
                            guard.requirePro(
                              context,
                              featureName: 'AI Cognitive Diagnostics',
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                          ),
                        ),
                        child: const Text('Unlock'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                if (insightText != null && insightText!.isNotEmpty) ...[
                  InsightRow(
                    icon: Icons.psychology_rounded,
                    iconColor: colors.primary,
                    title: 'Daily AI Synthesis',
                    description: insightText!,
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                ],
                if (weakEntry != null) ...[
                  InsightRow(
                    icon: Icons.warning_amber_rounded,
                    iconColor: colors.error,
                    title: 'Subject Decay Alert: ${weakEntry.key}',
                    description:
                        'Memory recall chance is currently at ${(weakEntry.value.avgRetention * 100).toInt()}%. '
                        'Syllabot recommends a 15-minute targeted review session today.',
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                ],
                if (hasData) ...[
                  InsightRow(
                    icon: Icons.lightbulb_outline_rounded,
                    iconColor: colors.warning,
                    title: 'Peak Recall Focus Window',
                    description:
                        'Active recall retention is highest during morning '
                        'study sessions. Review cards early for maximum '
                        'consolidation.',
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  InsightRow(
                    icon: Icons.alarm_rounded,
                    iconColor: colors.success,
                    title: 'Memory Consolidation Tracking',
                    description:
                        'Daily spaced reviews protect against memory fade and promote long-term recall.',
                    colors: colors,
                  ),
                ] else ...[
                  InsightRow(
                    icon: Icons.tips_and_updates_rounded,
                    iconColor: colors.primary,
                    title: 'Getting Started with Spaced Repetition',
                    description:
                        'Create your first study deck or import lecture '
                        'materials. Syllabot will generate automated flashcards '
                        'and track your active recall retention score.',
                    colors: colors,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AppFeedback.selection();
                          context.showSnackBar(
                            message:
                                'Syllabot: "Reviewing your study trends. Your memory retention is strongest during morning sessions!"',
                          );
                        },
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15,
                        ),
                        label: const Text('Ask Syllabot AI'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AppFeedback.celebration();
                          try {
                            unawaited(
                              context.router.push(const ExamTimetableRoute()),
                            );
                          } on Object catch (e, st) { AppLogger.recordNonFatal(e, st); }
                        },
                        icon: const Icon(Icons.tune_rounded, size: 15),
                        label: const Text('Cram Targets'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InsightRow extends StatelessWidget {
  const InsightRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.colors,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final AppThemeColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.footnote.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
