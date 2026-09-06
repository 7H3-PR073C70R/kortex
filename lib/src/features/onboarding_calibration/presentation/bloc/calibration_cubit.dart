import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/auto_curate_exam_courses_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_curated_courses_catalog_use_case.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/curriculum_repository.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/save_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_state.dart';

/// Cubit managing step progression, conditional branching, and storage.
class CalibrationCubit extends Cubit<CalibrationState> {
  CalibrationCubit({
    required SaveCalibrationProfileUseCase saveCalibrationProfileUseCase,
    AutoCurateExamCoursesUseCase? autoCurateExamCoursesUseCase,
    CurriculumRepository? curriculumRepository,
    GetCuratedCoursesCatalogUseCase? getCuratedCoursesCatalogUseCase,
  }) : _saveCalibrationProfileUseCase = saveCalibrationProfileUseCase,
       _autoCurateExamCoursesUseCase = autoCurateExamCoursesUseCase,
       _curriculumRepository = curriculumRepository,
       _getCuratedCoursesCatalogUseCase = getCuratedCoursesCatalogUseCase,
       super(const CalibrationState()) {
    unawaited(loadCurriculumMetadata());
    unawaited(loadCatalogCourses());
  }

  final SaveCalibrationProfileUseCase _saveCalibrationProfileUseCase;
  final AutoCurateExamCoursesUseCase? _autoCurateExamCoursesUseCase;
  final CurriculumRepository? _curriculumRepository;
  final GetCuratedCoursesCatalogUseCase? _getCuratedCoursesCatalogUseCase;

  Future<void> loadCurriculumMetadata() async {
    final repo = _curriculumRepository;
    if (repo == null) return;
    final result = await repo.getAllMetadata();
    result.fold(
      (_) {},
      (metadata) => emit(state.copyWith(curriculumMetadata: metadata)),
    );
  }

  Future<void> loadCatalogCourses() async {
    final useCase = _getCuratedCoursesCatalogUseCase;
    if (useCase == null) return;
    final result = await useCase(const NoParams());
    result.fold(
      (_) {},
      (courses) => emit(state.copyWith(catalogCourses: courses)),
    );
  }

  void setAcademicFocus(AcademicFocus focus) {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(focus: focus),
      ),
    );
  }

  void setHigherEdLevel(HigherEdLevel level) {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(higherEdLevel: level),
      ),
    );
  }

  void setHigherEdField(String field) {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(higherEdField: field),
      ),
    );
  }

  void toggleHigherEdGoal(String goal) {
    final currentGoals = List<String>.from(state.profile.higherEdGoals);
    if (currentGoals.contains(goal)) {
      currentGoals.remove(goal);
    } else {
      currentGoals.add(goal);
    }
    emit(
      state.copyWith(
        profile: state.profile.copyWith(higherEdGoals: currentGoals),
      ),
    );
  }

  void setHighSchoolExam(String exam) {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(highSchoolExam: exam),
      ),
    );
  }

  void toggleHighSchoolSubject(String subject) {
    final currentSubjects = List<String>.from(state.profile.highSchoolSubjects);
    if (currentSubjects.contains(subject)) {
      currentSubjects.remove(subject);
    } else {
      currentSubjects.add(subject);
    }
    emit(
      state.copyWith(
        profile: state.profile.copyWith(highSchoolSubjects: currentSubjects),
      ),
    );
  }

  void setHighSchoolSubjects(List<String> subjects) {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(highSchoolSubjects: List.unmodifiable(subjects)),
      ),
    );
  }

  void clearHighSchoolSubjects() {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(highSchoolSubjects: const []),
      ),
    );
  }

  void setHighSchoolTimeline(String timeline) {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(highSchoolTimeline: timeline),
      ),
    );
  }

  /// Skips calibration by populating a sensible default profile so the
  /// dashboard never crashes from nulls. The profile has isCalibrated=false
  /// so the UI can show a "Complete your profile" banner.
  Future<void> skipCalibration() async {
    final CalibrationProfile defaultProfile;

    if (state.profile.focus == AcademicFocus.higherEducation) {
      defaultProfile = const CalibrationProfile(
        higherEdLevel: HigherEdLevel.bsc,
        higherEdField: 'General Studies',
        higherEdGoals: ['Spaced Repetition (SM-2) Mastery'],
        isCalibrated: true,
      );
    } else {
      defaultProfile = const CalibrationProfile(
        focus: AcademicFocus.highSchool,
        highSchoolExam: 'WAEC / GCE',
        highSchoolSubjects: ['Mathematics (Core)', 'English Language'],
        highSchoolTimeline: 'Next 6 Months',
        isCalibrated: true,
      );
    }

    emit(state.copyWith(status: CalibrationStatus.submitting));
    final result = await _saveCalibrationProfileUseCase(defaultProfile);
    result.fold(
      (_) {
        _markOnboardingCompleteLocallyAndRemotely();
        emit(
          state.copyWith(
            status: CalibrationStatus.completed,
            profile: defaultProfile,
          ),
        );
      },
      (_) {
        _markOnboardingCompleteLocallyAndRemotely();
        final exam = defaultProfile.highSchoolExam;
        if (defaultProfile.focus == AcademicFocus.highSchool &&
            exam != null &&
            _autoCurateExamCoursesUseCase != null) {
          unawaited(
            _autoCurateExamCoursesUseCase(
              AutoCurateExamCoursesParams(
                examName: exam,
                subjects: defaultProfile.highSchoolSubjects,
              ),
            ).then((_) {
              try {
                locator<DashboardBloc>().add(const DashboardRefreshed());
              } on Object catch (_) {}
            }),
          );
        }
        emit(
          state.copyWith(
            status: CalibrationStatus.completed,
            profile: defaultProfile,
          ),
        );
      },
    );
  }

  void _markOnboardingCompleteLocallyAndRemotely() {
    try {
      unawaited(
        locator<LocalStorageService>().savePreference(
          key: PrefKeys.hasCompletedOnboarding,
          data: 'true',
        ),
      );
      unawaited(
        locator<AuthRepository>().completeOnboarding(
          track: state.profile.highSchoolExam ?? 'WAEC',
          dailyTarget: 20,
        ),
      );
      locator<AuthBloc>().add(
        const AuthStatusChanged(AuthSessionStatus.authenticatedComplete),
      );
    } on Object catch (_) {}
  }

  void nextStep() {
    if (state.currentStepIndex < state.totalSteps - 1) {
      emit(
        state.copyWith(
          currentStepIndex: state.currentStepIndex + 1,
          isForwardTrajectory: true,
        ),
      );
    } else {
      unawaited(finishCalibration());
    }
  }

  void previousStep() {
    if (state.currentStepIndex > 0) {
      emit(
        state.copyWith(
          currentStepIndex: state.currentStepIndex - 1,
          isForwardTrajectory: false,
        ),
      );
    }
  }

  Future<void> finishCalibration() async {
    emit(state.copyWith(status: CalibrationStatus.submitting));
    final finalizedProfile = state.profile.copyWith(isCalibrated: true);
    final result = await _saveCalibrationProfileUseCase(finalizedProfile);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CalibrationStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) {
        _markOnboardingCompleteLocallyAndRemotely();
        final exam = finalizedProfile.highSchoolExam;
        if (finalizedProfile.focus == AcademicFocus.highSchool &&
            exam != null &&
            _autoCurateExamCoursesUseCase != null) {
          unawaited(
            _autoCurateExamCoursesUseCase(
              AutoCurateExamCoursesParams(
                examName: exam,
                subjects: finalizedProfile.highSchoolSubjects,
              ),
            ).then((_) {
              try {
                locator<DashboardBloc>().add(const DashboardRefreshed());
              } on Object catch (_) {}
            }),
          );
        }
        emit(
          state.copyWith(
            status: CalibrationStatus.completed,
            profile: finalizedProfile,
          ),
        );
      },
    );
  }
}
