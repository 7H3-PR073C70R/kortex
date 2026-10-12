import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Notification Preferences Card for daily prep and milestone exam alerts.
class ExamTimetableNotificationPreferencesCard extends StatelessWidget {
  const ExamTimetableNotificationPreferencesCard({
    required this.dailyReminderEnabled,
    required this.milestoneAlertsEnabled,
    required this.onDailyReminderChanged,
    required this.onMilestoneAlertsChanged,
    super.key,
  });

  final bool dailyReminderEnabled;
  final bool milestoneAlertsEnabled;
  final ValueChanged<bool> onDailyReminderChanged;
  final ValueChanged<bool> onMilestoneAlertsChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: colors.surfaceBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: colors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Timetable & Study Alerts',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep your preparation on track with automated reminders.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Daily Prep Reminders',
              style: typography.body.semiBold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Receive daily pacing reminders based on your workload targets.',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            value: dailyReminderEnabled,
            activeTrackColor: colors.primary,
            onChanged: onDailyReminderChanged,
          ),
          const Divider(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Milestone Countdown Alerts',
              style: typography.body.semiBold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Get notified at 30-day, 14-day, 7-day, and 24-hour milestones.',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            value: milestoneAlertsEnabled,
            activeTrackColor: colors.primary,
            onChanged: onMilestoneAlertsChanged,
          ),
        ],
      ),
    );
  }
}
