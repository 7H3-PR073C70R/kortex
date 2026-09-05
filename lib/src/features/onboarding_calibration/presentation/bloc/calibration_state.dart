import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/curriculum_metadata_entity.dart';

enum CalibrationStatus {
  initial,
  calibrating,
  submitting,
  completed,
  error,
}

/// State representation for the multi-step branching calibration wizard.
class CalibrationState extends Equatable {
  const CalibrationState({
    this.status = CalibrationStatus.initial,
    this.currentStepIndex = 0,
    this.profile = const CalibrationProfile(),
    this.errorMessage,
    this.isForwardTrajectory = true,
    this.curriculumMetadata = const {},
  });

  final CalibrationStatus status;
  final int currentStepIndex; // 0, 1, 2, 3
  final CalibrationProfile profile;
  final String? errorMessage;
  final bool isForwardTrajectory;
  final Map<String, List<CurriculumMetadataEntity>> curriculumMetadata;

  List<CurriculumMetadataEntity> get standardizedExams =>
      curriculumMetadata['standardized_exam'] ?? const [];

  List<CurriculumMetadataEntity> get facultyTracks =>
      curriculumMetadata['faculty_track'] ?? const [];

  List<CurriculumMetadataEntity> get higherEdLevels =>
      curriculumMetadata['higher_ed_level'] ?? const [];

  List<CurriculumMetadataEntity> get studyGoals =>
      curriculumMetadata['study_goal'] ?? const [];

  List<CurriculumMetadataEntity> get highSchoolSubjects =>
      curriculumMetadata['high_school_subject'] ?? const [];

  int get totalSteps => 4;

  bool get isSubmitting => status == CalibrationStatus.submitting;
  bool get isCompleted => status == CalibrationStatus.completed;

  bool get canProceed {
    switch (currentStepIndex) {
      case 0:
        return true;
      case 1:
        if (profile.focus == AcademicFocus.higherEducation) {
          return profile.higherEdLevel != null;
        } else {
          return profile.highSchoolExam != null &&
              profile.highSchoolExam!.isNotEmpty;
        }
      case 2:
        if (profile.focus == AcademicFocus.higherEducation) {
          return profile.higherEdField != null &&
              profile.higherEdField!.isNotEmpty;
        } else {
          return profile.highSchoolSubjects.isNotEmpty;
        }
      case 3:
        if (profile.focus == AcademicFocus.higherEducation) {
          return profile.higherEdGoals.isNotEmpty;
        } else {
          return profile.highSchoolTimeline != null &&
              profile.highSchoolTimeline!.isNotEmpty;
        }
      default:
        return true;
    }
  }

  CalibrationState copyWith({
    CalibrationStatus? status,
    int? currentStepIndex,
    CalibrationProfile? profile,
    String? errorMessage,
    bool? isForwardTrajectory,
    Map<String, List<CurriculumMetadataEntity>>? curriculumMetadata,
  }) {
    return CalibrationState(
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
      isForwardTrajectory: isForwardTrajectory ?? this.isForwardTrajectory,
      curriculumMetadata: curriculumMetadata ?? this.curriculumMetadata,
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentStepIndex,
    profile,
    errorMessage,
    isForwardTrajectory,
    curriculumMetadata,
  ];
}
