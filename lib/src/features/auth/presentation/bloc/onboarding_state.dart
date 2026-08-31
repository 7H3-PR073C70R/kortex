import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';

enum OnboardingMode {
  chat,
  form,
}

enum OnboardingStatus {
  initial,
  loading,
  inProgress,
  completed,
  error,
}

class OnboardingState extends Equatable {
  const OnboardingState({
    this.activeMode = OnboardingMode.chat,
    this.status = OnboardingStatus.initial,
    this.currentStep = 0,
    this.selectedTrack = 'WAEC',
    this.dailyTarget = 20,
    this.retentionBenchmark = 0.85,
    this.email = '',
    this.displayName = '',
    this.tracks = CourseTrackEntity.defaultTracks,
    this.errorMessage,
    this.completedProfile,
  });

  final OnboardingMode activeMode;
  final OnboardingStatus status;
  final int currentStep;
  final String selectedTrack;
  final int dailyTarget;
  final double retentionBenchmark;
  final String email;
  final String displayName;
  final List<CourseTrackEntity> tracks;
  final String? errorMessage;
  final UserProfileEntity? completedProfile;

  bool get isLoading => status == OnboardingStatus.loading;
  bool get isCompleted => status == OnboardingStatus.completed;

  CourseTrackEntity get currentTrackEntity {
    return tracks.firstWhere(
      (t) => t.id == selectedTrack,
      orElse: () => tracks.first,
    );
  }

  OnboardingState copyWith({
    OnboardingMode? activeMode,
    OnboardingStatus? status,
    int? currentStep,
    String? selectedTrack,
    int? dailyTarget,
    double? retentionBenchmark,
    String? email,
    String? displayName,
    List<CourseTrackEntity>? tracks,
    String? errorMessage,
    UserProfileEntity? completedProfile,
  }) {
    return OnboardingState(
      activeMode: activeMode ?? this.activeMode,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      selectedTrack: selectedTrack ?? this.selectedTrack,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      retentionBenchmark: retentionBenchmark ?? this.retentionBenchmark,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      tracks: tracks ?? this.tracks,
      errorMessage: errorMessage ?? this.errorMessage,
      completedProfile: completedProfile ?? this.completedProfile,
    );
  }

  @override
  List<Object?> get props => [
        activeMode,
        status,
        currentStep,
        selectedTrack,
        dailyTarget,
        retentionBenchmark,
        email,
        displayName,
        tracks,
        errorMessage,
        completedProfile,
      ];
}
