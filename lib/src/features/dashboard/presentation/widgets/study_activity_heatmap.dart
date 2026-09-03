import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
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
    final primary = context.theme.colorScheme.primary;
    if (count == 0) return Colors.white10;
    if (count < 5) return primary.withValues(alpha: 0.3);
    if (count < 10) return primary.withValues(alpha: 0.55);
    if (count < 20) return primary.withValues(alpha: 0.8);
    return primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;

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
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title ?? l10n.studyActivityHeatmapTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalReviews Reviews this Year',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
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
                            borderRadius: BorderRadius.circular(3),
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
                'Less',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text(
                'More',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
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
