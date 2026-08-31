import 'package:equatable/equatable.dart';

enum AcademicFocus {
  higherEducation,
  highSchool,
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
    this.isCalibrated = false,
  });

  final AcademicFocus focus;
  final HigherEdLevel? higherEdLevel;
  final String? higherEdField;
  final List<String> higherEdGoals;
  final String? highSchoolExam;
  final List<String> highSchoolSubjects;
  final String? highSchoolTimeline;
  final bool isCalibrated;

  CalibrationProfile copyWith({
    AcademicFocus? focus,
    HigherEdLevel? higherEdLevel,
    String? higherEdField,
    List<String>? higherEdGoals,
    String? highSchoolExam,
    List<String>? highSchoolSubjects,
    String? highSchoolTimeline,
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
        isCalibrated,
      ];
}
