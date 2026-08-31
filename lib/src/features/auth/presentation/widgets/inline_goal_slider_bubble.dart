import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/widgets/goal_calibration_slider.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Embedded interactive daily card review goal slider rendered inside the
/// AI chat stream.
class InlineGoalSliderBubble extends HookWidget {
  const InlineGoalSliderBubble({
    required this.initialDailyTarget,
    required this.initialRetentionBenchmark,
    required this.onGoalConfirmed,
    super.key,
  });

  final int initialDailyTarget;
  final double initialRetentionBenchmark;
  final void Function(int target, double retention) onGoalConfirmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final targetState = useState<int>(initialDailyTarget);
    final retentionState = useState<double>(initialRetentionBenchmark);
    final isConfirmed = useState<bool>(false);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(200)
            : colors.surfacePrimary.withAlpha(240),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 50 : 30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GoalCalibrationSlider(
            dailyTarget: targetState.value,
            retentionBenchmark: retentionState.value,
            onTargetChanged: (val) {
              targetState.value = val;
            },
            onRetentionChanged: (val) {
              retentionState.value = val;
            },
          ),
          const SizedBox(height: 14),
          ShrinkableButton(
            onTap: isConfirmed.value
                ? null
                : () {
                    isConfirmed.value = true;
                    onGoalConfirmed(targetState.value, retentionState.value);
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isConfirmed.value
                      ? [
                          colors.surfaceTertiary,
                          colors.surfaceTertiary,
                        ]
                      : [
                          colors.primary,
                          colors.primary.withAlpha(220),
                        ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConfirmed.value
                          ? Icons.check_circle_rounded
                          : Icons.tune_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConfirmed.value
                          ? 'Goal Calibrated'
                          : 'Confirm Daily Target (${targetState.value} cards)',
                      style: typography.footnote.bold.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
