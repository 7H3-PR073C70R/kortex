import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Selection counter, clear-all trigger, and stream filter tabs.
class HighSchoolStreamFilterBar extends StatelessWidget {
  const HighSchoolStreamFilterBar({
    required this.selectedSubjectsCount,
    required this.totalCoursesCount,
    required this.onClearAll,
    required this.streams,
    required this.selectedStream,
    required this.onStreamSelected,
    required this.streamCourseCount,
    super.key,
  });

  final int selectedSubjectsCount;
  final int totalCoursesCount;
  final VoidCallback onClearAll;
  final List<String> streams;
  final String selectedStream;
  final ValueChanged<String> onStreamSelected;
  final int Function(String stream) streamCourseCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Selection Counter & Clear All Bar ─────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: selectedSubjectsCount > 0
                    ? colors.primary.withAlpha(25)
                    : colors.surfaceSecondary.withAlpha(80),
                borderRadius: AppRadius.radiusBadge,
                border: Border.all(
                  color: selectedSubjectsCount > 0
                      ? colors.primary.withAlpha(80)
                      : colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selectedSubjectsCount > 0
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 12,
                    color: selectedSubjectsCount > 0
                        ? colors.primary
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$selectedSubjectsCount of $totalCoursesCount selected',
                    style: typography.caption.bold.copyWith(
                      color: selectedSubjectsCount > 0
                          ? colors.primary
                          : colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedSubjectsCount > 0)
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return GestureDetector(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      onClearAll();
                    },
                    child: AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? colors.error.withAlpha(20)
                            : colors.transparent,
                        borderRadius: AppRadius.radiusBadge,
                      ),
                      child: Text(
                        'Clear all',
                        style: typography.caption.semiBold.copyWith(
                          color: isHovered
                              ? colors.error
                              : colors.error.withAlpha(220),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 2. Stream Filter Tabs ────────────────────────────────────────────
        if (streams.length > 2) ...[
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: streams.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final stream = streams[index];
                final isSelected = selectedStream == stream;
                final count = streamCourseCount(stream);

                return PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return ShrinkableButton(
                      shrinkScale: 0.95,
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        onStreamSelected(stream);
                      },
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : isHovered
                              ? (isDark
                                    ? colors.surfaceSecondary.withAlpha(130)
                                    : colors.surfacePrimary)
                              : (isDark
                                    ? colors.surfaceSecondary.withAlpha(90)
                                    : colors.surfacePrimary.withAlpha(180)),
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : isHovered
                                ? (isDark
                                      ? colors.surfaceBorderHighlight
                                      : colors.primary.withAlpha(90))
                                : (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          60,
                                        )
                                      : colors.surfaceBorder),
                          ),
                        ),
                        child: Text(
                          '$stream ($count)',
                          style: typography.caption.bold.copyWith(
                            color: isSelected
                                ? colors.white
                                : (isHovered
                                      ? colors.textPrimary
                                      : colors.textSecondary),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
