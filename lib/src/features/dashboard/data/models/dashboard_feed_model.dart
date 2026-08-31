import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/dashboard/data/models/exam_countdown_model.dart';
import 'package:kortex/src/features/dashboard/data/models/study_deck_model.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';

part 'dashboard_feed_model.freezed.dart';
part 'dashboard_feed_model.g.dart';

@freezed
abstract class CuratedCourseModel with _$CuratedCourseModel {
  const factory CuratedCourseModel({
    required String id,
    required String courseCode,
    required String title,
    required String department,
    required int totalMaterials,
    required bool hasActivePastPapers,
    required String iconName,
    required String colorHex,
    String? pdfDownloadUrl,
    @Default(0.75) double syllabusCoverage,
  }) = _CuratedCourseModel;

  const CuratedCourseModel._();

  factory CuratedCourseModel.fromJson(Map<String, dynamic> json) =>
      _$CuratedCourseModelFromJson(json);

  CuratedCourseEntity toEntity() => CuratedCourseEntity(
    id: id,
    courseCode: courseCode,
    title: title,
    department: department,
    totalMaterials: totalMaterials,
    hasActivePastPapers: hasActivePastPapers,
    iconName: iconName,
    colorHex: colorHex,
    pdfDownloadUrl: pdfDownloadUrl,
    syllabusCoverage: syllabusCoverage,
  );
}

@freezed
abstract class DashboardFeedModel with _$DashboardFeedModel {
  const factory DashboardFeedModel({
    required AnalyticsSummaryModel analyticsSummary,
    required List<StudyDeckModel> dueStudyDecks,
    required List<CuratedCourseModel> curatedCourses,
    ExamCountdownModel? targetExamCountdown,
    @Default(0) int unreadNotificationCount,
    String? syllabotDailyInsight,
  }) = _DashboardFeedModel;

  const DashboardFeedModel._();

  factory DashboardFeedModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardFeedModelFromJson(json);

  DashboardFeedEntity toEntity({
    required CalibrationProfile calibrationProfile,
  }) => DashboardFeedEntity(
    calibrationProfile: calibrationProfile,
    analyticsSummary: analyticsSummary.toEntity(),
    dueStudyDecks: dueStudyDecks.map((e) => e.toEntity()).toList(),
    curatedCourses: curatedCourses.map((e) => e.toEntity()).toList(),
    targetExamCountdown: targetExamCountdown?.toEntity(),
    unreadNotificationCount: unreadNotificationCount,
    syllabotDailyInsight: syllabotDailyInsight,
  );
}
