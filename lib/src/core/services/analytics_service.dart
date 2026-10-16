import 'dart:developer' as developer;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service wrapping Firebase Analytics with event tracking and screen views.
class AnalyticsService {
  AnalyticsService({
    FirebaseAnalytics? analytics,
    this.onEventLogged,
  }) : _analytics = analytics;

  FirebaseAnalytics? _analytics;

  /// Optional listener/callback invoked when any event is logged (useful for test assertions and debugging)
  final void Function(String name, Map<String, Object>? parameters)? onEventLogged;

  /// In-memory trace of logged events for test verification
  final List<Map<String, dynamic>> loggedEventsForTesting = [];

  bool get _isAvailable {
    try {
      if (Firebase.apps.isEmpty) return false;
      _analytics ??= FirebaseAnalytics.instance;
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  FirebaseAnalyticsObserver? get observer {
    if (_isAvailable && _analytics != null) {
      return FirebaseAnalyticsObserver(analytics: _analytics!);
    }
    return null;
  }

  /// Log custom analytic event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEventsForTesting.add({
      'name': name,
      if (parameters != null) 'parameters': Map<String, Object>.from(parameters),
    });
    onEventLogged?.call(name, parameters);
    developer.log('Analytics Event [$name]: $parameters');
    if (_isAvailable) {
      try {
        await _analytics?.logEvent(name: name, parameters: parameters);
      } on Object catch (e) {
        developer.log('Failed to log analytic event: $e');
      }
    }
  }

  /// Log screen navigation
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    developer.log('Analytics Screen: $screenName');
    if (_isAvailable) {
      try {
        await _analytics?.logScreenView(
          screenName: screenName,
          screenClass: screenClass,
        );
      } on Object catch (e) {
        developer.log('Failed to log screen view: $e');
      }
    }
  }

  /// Track study session completion
  Future<void> logStudySessionCompleted({
    required String deckId,
    required int cardCount,
    required double accuracy,
  }) async {
    await logEvent(
      name: 'study_session_completed',
      parameters: {
        'deck_id': deckId,
        'card_count': cardCount,
        'accuracy': accuracy,
      },
    );
  }

  /// Track flashcard synthesis
  Future<void> logFlashcardsGenerated({
    required String sourceType,
    required int cardCount,
  }) async {
    await logEvent(
      name: 'flashcards_generated',
      parameters: {
        'source_type': sourceType,
        'card_count': cardCount,
      },
    );
  }

  /// Track quiz completion
  Future<void> logQuizCompleted({
    required String quizId,
    required int score,
    required int totalQuestions,
  }) async {
    await logEvent(
      name: 'quiz_completed',
      parameters: {
        'quiz_id': quizId,
        'score': score,
        'total_questions': totalQuestions,
      },
    );
  }

  /// Set user ID
  Future<void> setUserId(String? userId) async {
    if (_isAvailable) {
      try {
        await _analytics?.setUserId(id: userId);
      } on Object catch (e) {
        developer.log('Failed to set Analytics user ID: $e');
      }
    }
  }

  // ===========================================================================
  // CBT Health & Readiness Observability Telemetry
  // ===========================================================================

  /// Track when a student starts a Day-One or track diagnostic assessment
  Future<void> logCbtDiagnosticStarted({
    required String trackOrExamName,
    int questionCount = 15,
  }) async {
    await logEvent(
      name: 'cbt_diagnostic_started',
      parameters: {
        'track_name': trackOrExamName,
        'question_count': questionCount,
      },
    );
  }

  /// Track when a student completes and submits a diagnostic assessment
  Future<void> logCbtDiagnosticCompleted({
    required String trackOrExamName,
    required int scorePercent,
    required int totalQuestions,
    required int correctAnswers,
    required int durationSeconds,
  }) async {
    await logEvent(
      name: 'cbt_diagnostic_completed',
      parameters: {
        'track_name': trackOrExamName,
        'score_percent': scorePercent,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'duration_seconds': durationSeconds,
      },
    );
  }

  /// Track when a full CBT mock exam simulation is initiated
  Future<void> logCbtMockExamStarted({
    required String examTrack,
    required String attemptId,
    required int totalQuestions,
    required int durationMinutes,
    bool isTimed = true,
  }) async {
    await logEvent(
      name: 'cbt_mock_exam_started',
      parameters: {
        'exam_track': examTrack,
        'attempt_id': attemptId,
        'total_questions': totalQuestions,
        'duration_minutes': durationMinutes,
        'is_timed': isTimed ? 1 : 0,
      },
    );
  }

  /// Track when a full CBT mock exam is submitted (manual or auto-deadline)
  Future<void> logCbtMockExamSubmitted({
    required String examTrack,
    required String attemptId,
    required int scorePercent,
    required int totalQuestions,
    required int correctAnswers,
    required int elapsedSeconds,
    required bool isAutoSubmit,
  }) async {
    await logEvent(
      name: 'cbt_mock_exam_submitted',
      parameters: {
        'exam_track': examTrack,
        'attempt_id': attemptId,
        'score_percent': scorePercent,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'elapsed_seconds': elapsedSeconds,
        'is_auto_submit': isAutoSubmit ? 1 : 0,
      },
    );
  }

  /// Track when an interrupted CBT exam session is safely restored
  Future<void> logCbtExamResumedAfterInterrupt({
    required String examTrack,
    required String attemptId,
    required int remainingSeconds,
    required int answeredQuestionsCount,
    required int totalQuestions,
  }) async {
    await logEvent(
      name: 'cbt_exam_resumed_after_interrupt',
      parameters: {
        'exam_track': examTrack,
        'attempt_id': attemptId,
        'remaining_seconds': remainingSeconds,
        'answered_count': answeredQuestionsCount,
        'total_questions': totalQuestions,
      },
    );
  }

  /// Track when pending offline CBT quiz submissions are successfully flushed
  Future<void> logCbtOfflineQueueFlushSuccess({
    required int flushedCount,
    required int remainingCount,
    required int durationMs,
  }) async {
    await logEvent(
      name: 'cbt_offline_queue_flush_success',
      parameters: {
        'flushed_count': flushedCount,
        'remaining_count': remainingCount,
        'duration_ms': durationMs,
      },
    );
  }

  /// Track when offline CBT queue flush encounters failures or moves to dead-letter
  Future<void> logCbtOfflineQueueFlushFailed({
    required int failedCount,
    required String errorReason,
    required int retryCount,
  }) async {
    await logEvent(
      name: 'cbt_offline_queue_flush_failed',
      parameters: {
        'failed_count': failedCount,
        'error_reason': errorReason,
        'retry_count': retryCount,
      },
    );
  }

  /// Track when a student views their CBT readiness score and confidence intervals
  Future<void> logReadinessScoreViewed({
    required double readinessScore,
    required String statusTier,
    String? confidenceIntervalLabel,
    double? standardErrorMargin,
    String? examTrack,
  }) async {
    final params = <String, Object>{
      'readiness_score': readinessScore,
      'status_tier': statusTier,
    };
    if (confidenceIntervalLabel != null) {
      params['confidence_label'] = confidenceIntervalLabel;
    }
    if (standardErrorMargin != null) {
      params['standard_error_margin'] = standardErrorMargin;
    }
    if (examTrack != null) {
      params['exam_track'] = examTrack;
    }
    await logEvent(
      name: 'readiness_score_viewed',
      parameters: params,
    );
  }
}
