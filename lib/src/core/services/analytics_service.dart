import 'dart:developer' as developer;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service wrapping Firebase Analytics with event tracking and screen views.
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics}) : _analytics = analytics;

  FirebaseAnalytics? _analytics;

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
}
