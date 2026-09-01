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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          height: 4,
          width: isCurrent ? 20 : 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: isActive
                ? colors.primary
                : (isDark
                    ? colors.surfaceBorderHighlight.withAlpha(80)
                    : colors.surfaceBorder.withAlpha(120)),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: colors.primary.withAlpha(100),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
}
