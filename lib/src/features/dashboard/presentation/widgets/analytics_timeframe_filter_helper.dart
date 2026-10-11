import 'dart:math' as math;

import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';

/// Helper utilities for resolving and filtering analytics summary data.
abstract final class AnalyticsTimeframeFilterHelper {
  static AnalyticsSummaryEntity resolveAnalytics(
    AnalyticsSummaryEntity? feedAnalytics, {
    UserActivityService? activityService,
  }) {
    AnalyticsSummaryEntity? live;
    try {
      final summary = activityService?.getAnalyticsSummary();
      live = summary?.toEntity();
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }

    if (feedAnalytics == null) {
      return live ?? buildEmptyAnalytics();
    }

    if (live == null) {
      return feedAnalytics;
    }

    final effectiveStreak = math.max(
      feedAnalytics.currentStreakDays,
      live.currentStreakDays,
    );
    final effectiveLongest = math.max(
      feedAnalytics.longestStreakDays,
      live.longestStreakDays,
    );
    final effectiveMinutes = math.max(
      feedAnalytics.weeklyMinutesStudied,
      live.weeklyMinutesStudied,
    );
    final effectiveRetention = feedAnalytics.overallRetentionRate > 0
        ? feedAnalytics.overallRetentionRate
        : live.overallRetentionRate;
    final effectiveMastered = math.max(
      feedAnalytics.totalCardsMastered,
      live.totalCardsMastered,
    );
    final effectiveXp = math.max(
      feedAnalytics.xpPoints,
      live.xpPoints,
    );
    final effectiveRank = live.academicRank != 'Neural Scholar I'
        ? live.academicRank
        : feedAnalytics.academicRank;

    final hasLiveHeat = live.heatMapData.any((d) => d.intensityLevel > 0);

    return AnalyticsSummaryEntity(
      currentStreakDays: effectiveStreak,
      longestStreakDays: effectiveLongest,
      weeklyMinutesStudied: effectiveMinutes,
      overallRetentionRate: effectiveRetention,
      totalCardsMastered: effectiveMastered,
      heatMapData: hasLiveHeat ? live.heatMapData : feedAnalytics.heatMapData,
      xpPoints: effectiveXp,
      academicRank: effectiveRank,
    );
  }

  static AnalyticsSummaryEntity buildEmptyAnalytics() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final startMonday = DateTime(
      currentMonday.year,
      currentMonday.month,
      currentMonday.day - 21,
    );

    final heatMap = List.generate(28, (i) {
      final day = DateTime(
        startMonday.year,
        startMonday.month,
        startMonday.day + i,
      );
      return HeatMapDayEntity(
        date: day,
        intensityLevel: 0,
        cardsReviewed: 0,
        minutesStudied: 0,
      );
    });

    return AnalyticsSummaryEntity(
      currentStreakDays: 0,
      longestStreakDays: 0,
      weeklyMinutesStudied: 0,
      overallRetentionRate: 0,
      totalCardsMastered: 0,
      heatMapData: heatMap,
      xpPoints: 0,
      academicRank: 'Neural Scholar I',
    );
  }

  static AnalyticsSummaryEntity filterAnalyticsByTimeframe(
    AnalyticsSummaryEntity base,
    int timeframeIndex,
  ) {
    if (timeframeIndex == 0) {
      // Last 7 Days
      final recentDays = base.heatMapData.length >= 7
          ? base.heatMapData.sublist(base.heatMapData.length - 7)
          : base.heatMapData;
      final mins = recentDays.fold<int>(0, (sum, d) => sum + d.minutesStudied);
      final reviewed = recentDays.fold<int>(
        0,
        (sum, d) => sum + d.cardsReviewed,
      );
      final effectiveMins = mins > 0 ? mins : base.weeklyMinutesStudied;
      final effectiveMastered = reviewed > 0
          ? reviewed
          : (base.totalCardsMastered > 0
                ? math.max(1, (base.totalCardsMastered * 0.35).round())
                : 0);

      return AnalyticsSummaryEntity(
        currentStreakDays: base.currentStreakDays,
        longestStreakDays: base.longestStreakDays,
        weeklyMinutesStudied: effectiveMins,
        overallRetentionRate: base.overallRetentionRate,
        totalCardsMastered: effectiveMastered,
        heatMapData: recentDays,
        xpPoints: (base.xpPoints * 0.25).round(),
        academicRank: base.academicRank,
      );
    } else if (timeframeIndex == 1) {
      // Last 30 Days
      final recentDays = base.heatMapData.length >= 28
          ? base.heatMapData.sublist(base.heatMapData.length - 28)
          : base.heatMapData;
      final mins = recentDays.fold<int>(0, (sum, d) => sum + d.minutesStudied);
      final reviewed = recentDays.fold<int>(
        0,
        (sum, d) => sum + d.cardsReviewed,
      );
      final effectiveMins = mins > 0 ? mins : (base.weeklyMinutesStudied * 4);
      final effectiveMastered = reviewed > 0
          ? reviewed
          : (base.totalCardsMastered > 0
                ? math.max(1, (base.totalCardsMastered * 0.85).round())
                : 0);
      final effectiveRetention = base.overallRetentionRate > 0
          ? (base.overallRetentionRate * 0.98).clamp(0.0, 1.0)
          : 0.0;

      return AnalyticsSummaryEntity(
        currentStreakDays: base.currentStreakDays,
        longestStreakDays: base.longestStreakDays,
        weeklyMinutesStudied: effectiveMins,
        overallRetentionRate: effectiveRetention,
        totalCardsMastered: effectiveMastered,
        heatMapData: recentDays,
        xpPoints: (base.xpPoints * 0.8).round(),
        academicRank: base.academicRank,
      );
    } else {
      // All Time
      final mins = base.heatMapData.fold<int>(
        0,
        (sum, d) => sum + d.minutesStudied,
      );
      final effectiveMins = mins > 0 ? mins : (base.weeklyMinutesStudied * 8);
      final effectiveRetention = base.overallRetentionRate > 0
          ? (base.overallRetentionRate * 0.95).clamp(0.0, 1.0)
          : 0.0;

      return AnalyticsSummaryEntity(
        currentStreakDays: base.currentStreakDays,
        longestStreakDays: base.longestStreakDays,
        weeklyMinutesStudied: effectiveMins,
        overallRetentionRate: effectiveRetention,
        totalCardsMastered: base.totalCardsMastered,
        heatMapData: base.heatMapData,
        xpPoints: base.xpPoints,
        academicRank: base.academicRank,
      );
    }
  }
}
