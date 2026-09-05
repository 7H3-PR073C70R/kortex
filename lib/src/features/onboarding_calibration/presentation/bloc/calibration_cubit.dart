import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/auto_curate_exam_courses_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/save_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_state.dart';

/// Cubit managing step progression, conditional branching, and storage.
class CalibrationCubit extends Cubit<CalibrationState> {
  CalibrationCubit({
    required SaveCalibrationProfileUseCase saveCalibrationProfileUseCase,
    AutoCurateExamCoursesUseCase? autoCurateExamCoursesUseCase,
  }) : _saveCalibrationProfileUseCase = saveCalibrationProfileUseCase,
       _autoCurateExamCoursesUseCase = autoCurateExamCoursesUseCase,
       super(const CalibrationState());

  final SaveCalibrationProfileUseCase _saveCalibrationProfileUseCase;
  final AutoCurateExamCoursesUseCase? _autoCurateExamCoursesUseCase;

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
      );
    } else {
      defaultProfile = const CalibrationProfile(
        focus: AcademicFocus.highSchool,
        highSchoolExam: 'WAEC / GCE',
        highSchoolSubjects: ['Mathematics (Core)', 'English Language'],
        highSchoolTimeline: 'Next 6 Months',
      );
    }

    emit(state.copyWith(status: CalibrationStatus.submitting));
    final result = await _saveCalibrationProfileUseCase(defaultProfile);
    result.fold(
      (_) => emit(
        state.copyWith(
          status: CalibrationStatus.completed,
          profile: defaultProfile,
        ),
      ),
      (_) => emit(
        state.copyWith(
          status: CalibrationStatus.completed,
          profile: defaultProfile,
        ),
      ),
    );
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
            ),
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
