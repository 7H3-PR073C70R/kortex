import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Interactive date and time picker tiles for scheduling an assessment.
class AssessmentDateTimePickersSection extends StatelessWidget {
  const AssessmentDateTimePickersSection({
    required this.selectedDate,
    required this.selectedTime,
    required this.onPickDate,
    required this.onPickTime,
    super.key,
  });

  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final formattedDate = DateFormat('EEE, d MMM y').format(selectedDate);
    final formattedTime = selectedTime.format(context);

    return Row(
      children: [
        // Date Picker Tile
        Expanded(
          flex: 6,
          child: PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return AnimatedContainer(
                duration: AppMotion.snappy,
                curve: Curves.easeOutCubic,
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: AppRadius.radiusCard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (isHovered
                              ? colors.surfaceSecondary.withAlpha(220)
                              : colors.surfaceSecondary)
                          : (isHovered
                              ? colors.surfaceSecondary.withAlpha(120)
                              : colors.surfacePrimary),
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: isHovered
                            ? colors.primary.withAlpha(isDark ? 160 : 100)
                            : colors.surfaceBorder,
                      ),
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l10n.targetDateLabel,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: typography.callout.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Time Picker Tile
        Expanded(
          flex: 4,
          child: PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return AnimatedContainer(
                duration: AppMotion.snappy,
                curve: Curves.easeOutCubic,
                child: InkWell(
                  onTap: onPickTime,
                  borderRadius: AppRadius.radiusCard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (isHovered
                              ? colors.surfaceSecondary.withAlpha(220)
                              : colors.surfaceSecondary)
                          : (isHovered
                              ? colors.surfaceSecondary.withAlpha(120)
                              : colors.surfacePrimary),
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: isHovered
                            ? colors.primary.withAlpha(isDark ? 160 : 100)
                            : colors.surfaceBorder,
                      ),
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l10n.timePickerLabel,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: typography.callout.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
