import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';

/// Target Exam Countdown domain entity (WAEC, JAMB, SAT, Thesis, etc.)
class ExamCountdownEntity extends Equatable {
  const ExamCountdownEntity({
    required this.id,
    required this.examName,
    required this.targetDate,
    required this.syllabusProgress, // 0.0 to 1.0
    required this.subjectTrack,
    required this.totalMockPapersAvailable,
    required this.completedMocksCount,
    this.badgeTitle = 'NATIONAL STANDARD',
  });

  final String id;
  final String examName;
  final DateTime targetDate;
  final double syllabusProgress;
  final String subjectTrack;
  final int totalMockPapersAvailable;
  final int completedMocksCount;
  final String badgeTitle;

  int get daysRemaining {
    final now = DateTime.now();
    final difference = targetDate.difference(now).inDays;
    return difference < 0 ? 0 : difference;
  }

  @override
  List<Object?> get props => [
    id,
    examName,
    targetDate,
    syllabusProgress,
    subjectTrack,
    totalMockPapersAvailable,
    completedMocksCount,
    badgeTitle,
  ];
}

/// Curated Course / Past Paper Material domain entity
class CuratedCourseEntity extends Equatable {
  const CuratedCourseEntity({
    required this.id,
    required this.courseCode,
    required this.title,
    required this.department,
    required this.totalMaterials,
    required this.hasActivePastPapers,
    required this.iconName,
    required this.colorHex,
    this.pdfDownloadUrl,
    this.syllabusCoverage = 0.75,
  });

  final String id;
  final String courseCode; // e.g. "MTH 301", "WAEC-CHEM", "SAT-MATH"
  final String title;
  final String department;
  final int totalMaterials;
  final bool hasActivePastPapers;
  final String iconName;
  final String colorHex;
  final String? pdfDownloadUrl;
  final double syllabusCoverage;

  @override
  List<Object?> get props => [
    id,
    courseCode,
    title,
    department,
    totalMaterials,
    hasActivePastPapers,
    iconName,
    colorHex,
    pdfDownloadUrl,
    syllabusCoverage,
  ];
}

/// Core Aggregate Root for the entire Kortex Dashboard Feed
class DashboardFeedEntity extends Equatable {
  const DashboardFeedEntity({
    required this.calibrationProfile,
    required this.analyticsSummary,
    required this.dueStudyDecks,
    required this.curatedCourses,
    this.targetExamCountdown,
    this.unreadNotificationCount = 0,
    this.syllabotDailyInsight,
  });

  final CalibrationProfile calibrationProfile;
  final AnalyticsSummaryEntity analyticsSummary;
  final List<StudyDeckEntity> dueStudyDecks;
  final List<CuratedCourseEntity> curatedCourses;
  final ExamCountdownEntity? targetExamCountdown;
  final int unreadNotificationCount;
  final String? syllabotDailyInsight;

  bool get isHighSchoolCandidate =>
      calibrationProfile.focus == AcademicFocus.highSchool;

  bool get isHigherEdStudent =>
      calibrationProfile.focus == AcademicFocus.higherEducation;

  bool get isProfileUncalibrated => !calibrationProfile.isCalibrated;

  DashboardFeedEntity copyWith({
    CalibrationProfile? calibrationProfile,
    AnalyticsSummaryEntity? analyticsSummary,
    List<StudyDeckEntity>? dueStudyDecks,
    List<CuratedCourseEntity>? curatedCourses,
    ExamCountdownEntity? targetExamCountdown,
    int? unreadNotificationCount,
    String? syllabotDailyInsight,
  }) {
    return DashboardFeedEntity(
      calibrationProfile: calibrationProfile ?? this.calibrationProfile,
      analyticsSummary: analyticsSummary ?? this.analyticsSummary,
      dueStudyDecks: dueStudyDecks ?? this.dueStudyDecks,
      curatedCourses: curatedCourses ?? this.curatedCourses,
      targetExamCountdown: targetExamCountdown ?? this.targetExamCountdown,
      unreadNotificationCount:
          unreadNotificationCount ?? this.unreadNotificationCount,
      syllabotDailyInsight: syllabotDailyInsight ?? this.syllabotDailyInsight,
    );
  }

  @override
  List<Object?> get props => [
    calibrationProfile,
    analyticsSummary,
    dueStudyDecks,
    curatedCourses,
    targetExamCountdown,
    unreadNotificationCount,
    syllabotDailyInsight,
  ];
}
