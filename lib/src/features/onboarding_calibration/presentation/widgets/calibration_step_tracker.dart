import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isCurrent ? 32 : 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? colors.primary
                : (isDark
                    ? colors.surfaceBorderHighlight.withAlpha(80)
                    : colors.surfaceBorder.withAlpha(120)),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: colors.primary.withAlpha(100),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
}
