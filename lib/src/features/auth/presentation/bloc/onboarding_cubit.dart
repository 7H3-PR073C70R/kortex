import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';

enum OnboardingStatus { initial, loading, completed, error }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.status = OnboardingStatus.initial,
    this.currentStep = 0,
    this.selectedTrack = 'WAEC',
    this.dailyTarget = 20,
    this.retentionBenchmark = 0.85,
    this.tracks = CourseTrackEntity.defaultTracks,
    this.completedProfile,
    this.errorMessage,
  });

  final OnboardingStatus status;
  final int currentStep;
  final String selectedTrack;
  final int dailyTarget;
  final double retentionBenchmark;
  final List<CourseTrackEntity> tracks;
  final UserProfileEntity? completedProfile;
  final String? errorMessage;

  bool get isLoading => status == OnboardingStatus.loading;
  bool get isCompleted => status == OnboardingStatus.completed;

  CourseTrackEntity get currentTrackEntity => tracks.firstWhere(
        (t) => t.id == selectedTrack,
        orElse: () => tracks.first,
      );

  OnboardingState copyWith({
    OnboardingStatus? status,
    int? currentStep,
    String? selectedTrack,
    int? dailyTarget,
    double? retentionBenchmark,
    List<CourseTrackEntity>? tracks,
    UserProfileEntity? completedProfile,
    String? errorMessage,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      selectedTrack: selectedTrack ?? this.selectedTrack,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      retentionBenchmark: retentionBenchmark ?? this.retentionBenchmark,
      tracks: tracks ?? this.tracks,
      completedProfile: completedProfile ?? this.completedProfile,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentStep,
        selectedTrack,
        dailyTarget,
        retentionBenchmark,
        tracks,
        completedProfile,
        errorMessage,
      ];
}

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required CompleteOnboardingUseCase completeOnboardingUseCase,
  })  : _completeOnboardingUseCase = completeOnboardingUseCase,
        super(const OnboardingState());

  final CompleteOnboardingUseCase _completeOnboardingUseCase;

  void selectTrack(String trackId) {
    final track = state.tracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => state.tracks.first,
    );
    emit(
      state.copyWith(
        selectedTrack: trackId,
        dailyTarget: track.defaultDailyTarget,
      ),
    );
  }

  void updateDailyTarget(int target) {
    emit(state.copyWith(dailyTarget: target));
  }

  void updateRetentionBenchmark(double benchmark) {
    emit(state.copyWith(retentionBenchmark: benchmark));
  }

  void nextStep() {
    if (state.currentStep < 2) {
      emit(state.copyWith(currentStep: state.currentStep + 1));
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      emit(state.copyWith(currentStep: state.currentStep - 1));
    }
  }

  Future<void> completeOnboarding() async {
    emit(state.copyWith(status: OnboardingStatus.loading));
    final result = await _completeOnboardingUseCase(
      track: state.selectedTrack,
      dailyTarget: state.dailyTarget,
      retentionBenchmark: state.retentionBenchmark,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: OnboardingStatus.error,
          errorMessage: failure.message ?? 'Failed to finalize setup.',
        ),
      ),
      (profile) => emit(
        state.copyWith(
          status: OnboardingStatus.completed,
          completedProfile: profile,
        ),
      ),
    );
  }
}
