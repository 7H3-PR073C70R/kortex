import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:share_plus/share_plus.dart';

class FocusSessionSummarySheet extends StatelessWidget {
  const FocusSessionSummarySheet({
    required this.roomTitle,
    required this.subject,
    required this.completedPomodoros,
    required this.pomodoroDurationMinutes,
    required this.cardsReviewed,
    required this.activeGoal,
    required this.isGoalAchieved,
    required this.onDone,
    super.key,
  });

  final String roomTitle;
  final String subject;
  final int completedPomodoros;
  final int pomodoroDurationMinutes;
  final int cardsReviewed;
  final String? activeGoal;
  final bool isGoalAchieved;
  final VoidCallback onDone;

  static Future<void> show(
    BuildContext context, {
    required String roomTitle,
    required String subject,
    required int completedPomodoros,
    required int pomodoroDurationMinutes,
    required int cardsReviewed,
    required String? activeGoal,
    required bool isGoalAchieved,
    required VoidCallback onDone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FocusSessionSummarySheet(
        roomTitle: roomTitle,
        subject: subject,
        completedPomodoros: completedPomodoros,
        pomodoroDurationMinutes: pomodoroDurationMinutes,
        cardsReviewed: cardsReviewed,
        activeGoal: activeGoal,
        isGoalAchieved: isGoalAchieved,
        onDone: onDone,
      ),
    );
  }

  int get totalFocusMinutes => completedPomodoros * pomodoroDurationMinutes;

  int get earnedXp {
    var xp = completedPomodoros * 50 + cardsReviewed * 2;
    if (isGoalAchieved) {
      xp += 50;
    }
    return xp;
  }

  void _shareSummary() {
    final goalPart = (activeGoal != null && activeGoal!.trim().isNotEmpty)
        ? '\n🎯 Goal: "$activeGoal" ${isGoalAchieved ? "✅ Achieved" : "⏳ In Progress"}'
        : '';
    final message =
        '🔥 Just wrapped up a Deep Flow study session in Kortex!\n'
        '⏱ $totalFocusMinutes mins focused ($completedPomodoros Pomodoro blocks)'
        '$goalPart\n'
        '⚡ Earned +$earnedXp XP in #$subject!';
    unawaited(SharePlus.instance.share(ShareParams(text: message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 60 : 30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grabber handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header with celebratory trophy badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withAlpha(35),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: const Text('🏆', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Wrapped!',
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$roomTitle • $subject',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // XP Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.primary.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '+$earnedXp XP',
                      style: typography.subhead.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stat Cards Grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.timer_outlined,
                  iconColor: colors.primary,
                  label: 'Focus Time',
                  value: '$totalFocusMinutes min',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.deepOrangeAccent,
                  label: 'Pomodoros',
                  value: '$completedPomodoros blocks',
                ),
              ),
              if (cardsReviewed > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.style_rounded,
                    iconColor: Colors.tealAccent,
                    label: 'Cards Solved',
                    value: '$cardsReviewed',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Goal Accountability Card (if goal was set)
          if (activeGoal != null && activeGoal!.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isGoalAchieved
                    ? Colors.green.withAlpha(isDark ? 30 : 15)
                    : colors.primary.withAlpha(isDark ? 25 : 12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isGoalAchieved
                      ? Colors.green.withAlpha(70)
                      : colors.primary.withAlpha(50),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isGoalAchieved
                        ? Icons.check_circle_rounded
                        : Icons.track_changes_rounded,
                    color: isGoalAchieved ? Colors.green : colors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGoalAchieved
                              ? 'Micro-Goal Achieved (+50 XP Bonus)'
                              : 'Micro-Goal Tracked',
                          style: typography.caption.bold.copyWith(
                            color: isGoalAchieved
                                ? Colors.green
                                : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '"$activeGoal"',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            const SizedBox(height: 6),
          ],

          // Action Buttons
          Row(
            children: [
              // Share button
              Expanded(
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    _shareSummary();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.primary.withAlpha(40)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.share_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Share',
                          style: typography.body.bold.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Leave / Finish button
              Expanded(
                flex: 2,
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.mediumImpact());
                    Navigator.of(context).pop();
                    onDone();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.syllabotAccent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withAlpha(70),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Done & Exit Cockpit',
                      style: typography.body.bold.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withAlpha(25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: typography.caption.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
