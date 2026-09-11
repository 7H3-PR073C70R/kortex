import 'package:equatable/equatable.dart';

enum AcademicFocus {
  higherEducation,
  highSchool,
  professionalCertification,
  selfDirected,
}

enum StudyPacingStyle {
  microSprint15,
  standardPomodoro25,
  deepWork45,
}

enum HigherEdLevel {
  ond,
  hnd,
  bsc,
  msc,
  phd,
}

/// Domain entity holding a user's calibrated academic profile.
class CalibrationProfile extends Equatable {
  const CalibrationProfile({
    this.focus = AcademicFocus.higherEducation,
    this.higherEdLevel,
    this.higherEdField,
    this.higherEdGoals = const [],
    this.highSchoolExam,
    this.highSchoolSubjects = const [],
    this.highSchoolTimeline,
    this.pacingStyle = StudyPacingStyle.standardPomodoro25,
    this.dailyGoalMinutes = 30,
    this.isCalibrated = false,
  });

  final AcademicFocus focus;
  final HigherEdLevel? higherEdLevel;
  final String? higherEdField;
  final List<String> higherEdGoals;
  final String? highSchoolExam;
  final List<String> highSchoolSubjects;
  final String? highSchoolTimeline;
  final StudyPacingStyle pacingStyle;
  final int dailyGoalMinutes;
  final bool isCalibrated;

  CalibrationProfile copyWith({
    AcademicFocus? focus,
    HigherEdLevel? higherEdLevel,
    String? higherEdField,
    List<String>? higherEdGoals,
    String? highSchoolExam,
    List<String>? highSchoolSubjects,
    String? highSchoolTimeline,
    StudyPacingStyle? pacingStyle,
    int? dailyGoalMinutes,
    bool? isCalibrated,
  }) {
    return CalibrationProfile(
      focus: focus ?? this.focus,
      higherEdLevel: higherEdLevel ?? this.higherEdLevel,
      higherEdField: higherEdField ?? this.higherEdField,
      higherEdGoals: higherEdGoals ?? this.higherEdGoals,
      highSchoolExam: highSchoolExam ?? this.highSchoolExam,
      highSchoolSubjects: highSchoolSubjects ?? this.highSchoolSubjects,
      highSchoolTimeline: highSchoolTimeline ?? this.highSchoolTimeline,
      pacingStyle: pacingStyle ?? this.pacingStyle,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      isCalibrated: isCalibrated ?? this.isCalibrated,
    );
  }

  @override
  List<Object?> get props => [
    focus,
    higherEdLevel,
    higherEdField,
    higherEdGoals,
    highSchoolExam,
    highSchoolSubjects,
    highSchoolTimeline,
    pacingStyle,
    dailyGoalMinutes,
    isCalibrated,
  ];
}
