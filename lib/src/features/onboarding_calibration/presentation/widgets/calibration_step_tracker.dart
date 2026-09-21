import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Glassmorphic progress indicator showing active calibration step.
class CalibrationStepTracker extends StatelessWidget {
  const CalibrationStepTracker({
    required this.currentStep,
    required this.totalSteps,
    super.key,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        final isCurrent = index == currentStep;

        return AnimatedContainer(
          duration: AppMotion.standard,
          curve: AppMotion.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          height: 4,
          width: isCurrent ? 20 : 6,
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusMicro,
            color: isActive
                ? colors.primary
                : (isDark
                      ? colors.surfaceBorderHighlight.withAlpha(80)
                      : colors.surfaceBorder.withAlpha(120)),
          ),
        );
      }),
    );
  }
}
