import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';

class ActivityDayData {
  const ActivityDayData({
    required this.date,
    required this.reviewCount,
  });

  final DateTime date;
  final int reviewCount;
}

class StudyActivityHeatmap extends StatelessWidget {
  const StudyActivityHeatmap({
    required this.activityData,
    this.title,
    super.key,
  });

  final Map<DateTime, int> activityData;
  final String? title;

  Color _getCellColor(BuildContext context, int count) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    if (count == 0) return colors.surfaceBorder.withAlpha(isDark ? 60 : 70);
    if (count < 5) return colors.primary.withAlpha(isDark ? 75 : 65);
    if (count < 10) return colors.primary.withAlpha(isDark ? 140 : 130);
    if (count < 20) return colors.primary.withAlpha(isDark ? 200 : 190);
    return colors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    // Generate 52 weeks (364 days) ending today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const totalWeeks = 52;
    const daysPerWeek = 7;
    final startDate = today.subtract(const Duration(days: totalWeeks * 7 - 1));

    final weeks = List.generate(totalWeeks, (weekIdx) {
      return List.generate(daysPerWeek, (dayIdx) {
        final dayOffset = weekIdx * 7 + dayIdx;
        final date = startDate.add(Duration(days: dayOffset));
        final normalized = DateTime(date.year, date.month, date.day);
        final count = activityData[normalized] ?? 0;
        return ActivityDayData(date: normalized, reviewCount: count);
      });
    });

    final totalReviews = activityData.values.fold<int>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfacePrimary.withAlpha(220),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title ?? l10n.studyActivityHeatmapTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 90 : 50),
                  ),
                ),
                child: Text(
                  l10n.reviewsThisYearCount(totalReviews),
                  style: typography.caption.bold.copyWith(
                    fontSize: 11,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable 52-Week Heatmap Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Scroll to end (today) by default
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: weeks.map((weekDays) {
                return Column(
                  children: weekDays.map((day) {
                    final cellColor = _getCellColor(context, day.reviewCount);
                    final formattedDate = DateFormat(
                      'MMM d, yyyy',
                    ).format(day.date);
                    final tooltipMessage = l10n.heatmapCardReviewsCount(
                      day.reviewCount,
                      formattedDate,
                    );

                    return Semantics(
                      label: tooltipMessage,
                      child: Tooltip(
                        message: tooltipMessage,
                        child: Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(AppRadius.micro),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Density Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                l10n.dashboardHeatmapLess,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 6),
              ...[0, 3, 8, 15, 25].map((level) {
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _getCellColor(context, level),
                    borderRadius: BorderRadius.circular(AppRadius.micro),
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text(
                l10n.dashboardHeatmapMore,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
