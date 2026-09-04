import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

class GoalCalibrationSlider extends StatelessWidget {
  const GoalCalibrationSlider({
    required this.dailyTarget,
    required this.retentionBenchmark,
    required this.onTargetChanged,
    required this.onRetentionChanged,
    super.key,
  });

  final int dailyTarget;
  final double retentionBenchmark;
  final ValueChanged<int> onTargetChanged;
  final ValueChanged<double> onRetentionChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final estimatedMinutes = (dailyTarget * 1.5).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 40 : 25),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 40 : 15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Header with Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.dailyTargetCardGoal,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withAlpha(200),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.cardsPerDay(dailyTarget),
                  style: typography.footnote.bold.copyWith(
                    color: colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.dailyTargetCardGoalDesc,
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Daily Target Slider
          Semantics(
            label: 'Daily target slider: $dailyTarget cards per day',
            slider: true,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colors.primary,
                inactiveTrackColor: colors.surfaceTertiary,
                thumbColor: colors.primary,
                overlayColor: colors.primary.withAlpha(40),
                trackHeight: 6,
              ),
              child: Slider(
                value: dailyTarget.toDouble().clamp(5, 60),
                min: 5,
                max: 60,
                divisions: 11,
                onChanged: (val) => onTargetChanged(val.round()),
              ),
            ),
          ),

          // Estimated Commitment & Retention Pill row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '~$estimatedMinutes mins / day',
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    size: 16,
                    color: colors.syllabotAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.retentionTarget((retentionBenchmark * 100).round()),
                    style: typography.caption.bold.copyWith(
                      color: colors.syllabotAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
