import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';

part 'analytics_summary_model.freezed.dart';
part 'analytics_summary_model.g.dart';

@freezed
abstract class HeatMapDayModel with _$HeatMapDayModel {
  const factory HeatMapDayModel({
    required String dateIso,
    required int intensityLevel,
    required int cardsReviewed,
    required int minutesStudied,
  }) = _HeatMapDayModel;

  const HeatMapDayModel._();

  factory HeatMapDayModel.fromJson(Map<String, dynamic> json) =>
      _$HeatMapDayModelFromJson(json);

  HeatMapDayEntity toEntity() => HeatMapDayEntity(
    date: DateTime.tryParse(dateIso) ?? DateTime.now(),
    intensityLevel: intensityLevel,
    cardsReviewed: cardsReviewed,
    minutesStudied: minutesStudied,
  );
}

@freezed
abstract class AnalyticsSummaryModel with _$AnalyticsSummaryModel {
  const factory AnalyticsSummaryModel({
    required int currentStreakDays,
    required int longestStreakDays,
    required int weeklyMinutesStudied,
    required double overallRetentionRate,
    required int totalCardsMastered,
    required List<HeatMapDayModel> heatMapData,
    required int xpPoints,
    required String academicRank,
  }) = _AnalyticsSummaryModel;

  const AnalyticsSummaryModel._();

  factory AnalyticsSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsSummaryModelFromJson(json);

  AnalyticsSummaryEntity toEntity() => AnalyticsSummaryEntity(
    currentStreakDays: currentStreakDays,
    longestStreakDays: longestStreakDays,
    weeklyMinutesStudied: weeklyMinutesStudied,
    overallRetentionRate: overallRetentionRate,
    totalCardsMastered: totalCardsMastered,
    heatMapData: heatMapData.map((e) => e.toEntity()).toList(),
    xpPoints: xpPoints,
    academicRank: academicRank,
  );
}
