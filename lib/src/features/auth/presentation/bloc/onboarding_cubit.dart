import 'package:bloc/bloc.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/onboarding_state.dart';

export 'onboarding_state.dart';

/// Cubit managing synchronized state between AI Chat and Form onboarding modes.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required CompleteOnboardingUseCase completeOnboardingUseCase,
  }) : _completeOnboardingUseCase = completeOnboardingUseCase,
       super(const OnboardingState());

  final CompleteOnboardingUseCase _completeOnboardingUseCase;

  void setMode(OnboardingMode mode) {
    emit(state.copyWith(activeMode: mode));
  }

  void toggleMode() {
    final nextMode = state.activeMode == OnboardingMode.chat
        ? OnboardingMode.form
        : OnboardingMode.chat;
    emit(state.copyWith(activeMode: nextMode));
  }

  void syncStep(int step) {
    emit(state.copyWith(currentStep: step.clamp(0, 2)));
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

  void updateProfileData({String? email, String? displayName}) {
    emit(
      state.copyWith(
        email: email ?? state.email,
        displayName: displayName ?? state.displayName,
      ),
    );
  }

  void selectTrack(String trackId) {
    final track = state.tracks.firstWhere(
      (t) => t.id == trackId,
      orElse: () => state.tracks.first,
    );
    emit(
      state.copyWith(
        selectedTrack: track.id,
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
          errorMessage: failure.message ?? 'Failed to complete onboarding.',
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
