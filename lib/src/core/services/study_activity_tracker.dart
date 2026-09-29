import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/study_circle_cubit.dart';

/// Service responsible for recording completed academic activities (quizzes,
/// duels, study decks, focus timers, live rooms) to the scholar's active Study
/// Circles and ensuring real-time UI state sync across the app.
abstract class StudyActivityTracker {
  /// Records completed activity focus time to all joined Study Circles.
  ///
  /// Duration in seconds is converted to effective focus minutes:
  /// - Under 15 seconds: 0 minutes (session aborted)
  /// - 15 to 89 seconds: 1 minute minimum
  /// - 90+ seconds: Rounded to closest minute `(durationSeconds + 30) ~/ 60`
  Future<int> recordActivityCompletion({
    required int durationSeconds,
    required String activityType,
    String circleId = '',
    Map<String, dynamic>? metadata,
  });
}

class StudyActivityTrackerImpl implements StudyActivityTracker {
  StudyActivityTrackerImpl({
    CommunityRepository? repository,
  }) : _repository = repository;

  final CommunityRepository? _repository;

  CommunityRepository get _effectiveRepo =>
      _repository ?? locator<CommunityRepository>();

  @override
  Future<int> recordActivityCompletion({
    required int durationSeconds,
    required String activityType,
    String circleId = '',
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Calculate effective minutes
    if (durationSeconds < 15) {
      debugPrint('StudyActivityTracker: Duration $durationSeconds s too short (<15s), skipping pod credit.');
      return 0;
    }

    final minutes = durationSeconds < 90 ? 1 : ((durationSeconds + 30) ~/ 60);

    try {
      if (locator.isRegistered<CommunityRepository>()) {
        final result = await _effectiveRepo.recordPodFocusMinutes(
          circleId: circleId,
          minutes: minutes,
          activityType: activityType,
        );

        result.fold(
          (failure) {
            debugPrint('StudyActivityTracker: Failed to record pod focus minutes: ${failure.message}');
          },
          (data) {
            debugPrint('StudyActivityTracker: Successfully recorded $minutes mins for $activityType in pod goal!');
          },
        );
      }
    } on Object catch (e) {
      debugPrint('StudyActivityTracker error recording pod focus minutes: $e');
    }

    // 2. Trigger real-time BLoC UI state refresh
    _syncStudyCircleBlocs();

    return minutes;
  }

  void _syncStudyCircleBlocs() {
    try {
      if (locator.isRegistered<StudyCircleCubit>()) {
        unawaited(locator<StudyCircleCubit>().loadStudyCircles());
      }
    } on Object catch (_) {}

    try {
      if (locator.isRegistered<CommunityHubBloc>()) {
        locator<CommunityHubBloc>().add(
          const RecordPodFocusMinutesEvent(circleId: '', minutes: 0),
        );
      }
    } on Object catch (_) {}
  }
}
