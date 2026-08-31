import 'package:equatable/equatable.dart';

/// Heat map day cell entity representing study intensity for visual
/// retention graph.
class HeatMapDayEntity extends Equatable {
  const HeatMapDayEntity({
    required this.date,

    /// 0 = none, 1 = light, 2 = moderate, 3 = high, 4 = master
    required this.intensityLevel,
    required this.cardsReviewed,
    required this.minutesStudied,
  });

  final DateTime date;
  final int intensityLevel;
  final int cardsReviewed;
  final int minutesStudied;

  @override
  List<Object?> get props => [
    date,
    intensityLevel,
    cardsReviewed,
    minutesStudied,
  ];
}

/// Comprehensive study analytics summary for user dashboard.
class AnalyticsSummaryEntity extends Equatable {
  const AnalyticsSummaryEntity({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.weeklyMinutesStudied,
    required this.overallRetentionRate,
    required this.totalCardsMastered,
    required this.heatMapData,
    required this.xpPoints,
    required this.academicRank,
  });

  final int currentStreakDays;
  final int longestStreakDays;
  final int weeklyMinutesStudied;
  final double overallRetentionRate; // e.g. 0.92 = 92%
  final int totalCardsMastered;
  final List<HeatMapDayEntity> heatMapData;
  final int xpPoints;
  final String academicRank; // e.g., "Neural Scholar IV"

  @override
  List<Object?> get props => [
    currentStreakDays,
    longestStreakDays,
    weeklyMinutesStudied,
    overallRetentionRate,
    totalCardsMastered,
    heatMapData,
    xpPoints,
    academicRank,
  ];
}
