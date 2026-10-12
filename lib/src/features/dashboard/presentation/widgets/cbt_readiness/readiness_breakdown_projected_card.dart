import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';

/// Projected exam score card within the CBT readiness diagnostic breakdown sheet.
class ReadinessBreakdownProjectedCard extends StatelessWidget {
  const ReadinessBreakdownProjectedCard({
    required this.readiness,
    super.key,
  });

  final CbtReadinessResult readiness;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            readiness.statusColor.withAlpha(isDark ? 50 : 25),
            colors.primary.withAlpha(isDark ? 30 : 12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: readiness.statusColor.withAlpha(70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'PROJECTED EXAM SCORE',
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfacePrimary.withAlpha(180)
                      : colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(40),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 13,
                      color: readiness.speedReadinessRatio >= 0.8
                          ? colors.success
                          : colors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      readiness.speedDiagnosticLabel,
                      style: typography.caption.bold.copyWith(
                        color: readiness.speedReadinessRatio >= 0.8
                            ? colors.success
                            : colors.warning,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            readiness.projectedScoreRange,
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 16,
              height: 1.35,
            ),
          ),
          if (readiness.totalCourseCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.micro),
                    child: LinearProgressIndicator(
                      value: readiness.calibratedCourseCount /
                          math.max(1, readiness.totalCourseCount),
                      minHeight: 4,
                      backgroundColor: colors.surfaceBorder.withAlpha(60),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        readiness.isFullyCalibrated
                            ? colors.success
                            : colors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${readiness.calibratedCourseCount}/${readiness.totalCourseCount} Calibrated',
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
