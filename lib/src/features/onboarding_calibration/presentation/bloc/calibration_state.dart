import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/dashboard/domain/constants/subject_catalog.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
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
    this.catalogCourses = const [],
  });

  final CalibrationStatus status;
  final int currentStepIndex; // 0, 1, 2, 3
  final CalibrationProfile profile;
  final String? errorMessage;
  final bool isForwardTrajectory;
  final Map<String, List<CurriculumMetadataEntity>> curriculumMetadata;
  final List<CuratedCourseEntity> catalogCourses;

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

  /// Calibration is completely skippable and non-compulsory.
  /// Users can navigate forward and backward freely at any step without being locked.
  bool get canProceed => true;

  List<CuratedCourseEntity> get highSchoolCatalogCourses {
    final exam = (profile.highSchoolExam ?? '').toUpperCase();
    final effectiveList = catalogCourses.isNotEmpty
        ? catalogCourses
        : kCuratedSubjectsCatalog.map((s) {
            return CuratedCourseEntity(
              id: 'curated-${s.code.toLowerCase()}',
              courseCode: s.code,
              title: s.title,
              department: s.stream,
              totalMaterials: s.materials,
              hasActivePastPapers: true,
              iconName: s.icon,
              colorHex: s.colorHex,
              syllabusCoverage: s.coverage,
            );
          }).toList();

    if (exam.contains('SAT')) {
      final satCourses = effectiveList
          .where((c) =>
              c.department.toUpperCase().contains('SAT') ||
              c.id.startsWith('sat-') ||
              c.title.toUpperCase().contains('SAT'))
          .toList();
      if (satCourses.isNotEmpty) return satCourses;
    }
    if (exam.contains('JAMB') || exam.contains('UTME')) {
      final jambCourses = effectiveList
          .where((c) => c.id.startsWith('jamb-') || c.department.toUpperCase().contains('JAMB'))
          .toList();
      if (jambCourses.isNotEmpty) return jambCourses;
    } else if (exam.contains('NECO') || exam.contains('SSCE')) {
      final necoCourses = effectiveList
          .where((c) => c.id.startsWith('neco-') || c.department.toUpperCase().contains('NECO'))
          .toList();
      if (necoCourses.isNotEmpty) return necoCourses;
    } else if (exam.contains('WAEC') || exam.contains('WASSCE')) {
      final waecCourses = effectiveList
          .where((c) => c.id.startsWith('waec-') || c.department.toUpperCase().contains('WAEC'))
          .toList();
      if (waecCourses.isNotEmpty) return waecCourses;
    }

    return effectiveList
        .where((c) =>
            c.department.contains('Core') ||
            c.department.contains('Sciences') ||
            c.department.contains('Commercial') ||
            c.department.contains('Arts'))
        .toList();
  }

  CalibrationState copyWith({
    CalibrationStatus? status,
    int? currentStepIndex,
    CalibrationProfile? profile,
    String? errorMessage,
    bool? isForwardTrajectory,
    Map<String, List<CurriculumMetadataEntity>>? curriculumMetadata,
    List<CuratedCourseEntity>? catalogCourses,
  }) {
    return CalibrationState(
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
      isForwardTrajectory: isForwardTrajectory ?? this.isForwardTrajectory,
      curriculumMetadata: curriculumMetadata ?? this.curriculumMetadata,
      catalogCourses: catalogCourses ?? this.catalogCourses,
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
    catalogCourses,
  ];
}
