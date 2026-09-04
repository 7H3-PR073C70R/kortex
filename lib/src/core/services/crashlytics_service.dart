import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Service wrapping Firebase Crashlytics with safe offline/test fallbacks.
class CrashlyticsService {
  CrashlyticsService({FirebaseCrashlytics? crashlytics})
      : _crashlytics = crashlytics;

  FirebaseCrashlytics? _crashlytics;

  bool get _isAvailable {
    try {
      if (Firebase.apps.isEmpty) return false;
      _crashlytics ??= FirebaseCrashlytics.instance;
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  /// Record an error or exception to Crashlytics
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    developer.log(
      'Crashlytics error recorded (fatal: $fatal): $exception',
      error: exception,
      stackTrace: stack,
    );

    if (_isAvailable) {
      try {
        await _crashlytics?.recordError(
          exception,
          stack,
          reason: reason,
          information: information,
          fatal: fatal,
        );
      } on Object catch (e) {
        developer.log('Failed to record error to Crashlytics: $e');
      }
    }
  }

  /// Log a breadcrumb message to Crashlytics
  Future<void> log(String message) async {
    developer.log('Crashlytics breadcrumb: $message');
    if (_isAvailable) {
      try {
        await _crashlytics?.log(message);
      } on Object catch (e) {
        developer.log('Failed to log breadcrumb to Crashlytics: $e');
      }
    }
  }

  /// Set custom key-value diagnostic metadata
  Future<void> setCustomKey(String key, Object value) async {
    if (_isAvailable) {
      try {
        await _crashlytics?.setCustomKey(key, value);
      } on Object catch (e) {
        developer.log('Failed to set Crashlytics custom key: $e');
      }
    }
  }

  /// Set the user identifier for crash grouping
  Future<void> setUserId(String userId) async {
    if (_isAvailable) {
      try {
        await _crashlytics?.setUserIdentifier(userId);
      } on Object catch (e) {
        developer.log('Failed to set Crashlytics user ID: $e');
      }
    }
  }
}
