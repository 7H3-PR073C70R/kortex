import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/di/locator.dart';

/// Centralized structured logger for Kortex with automatic Crashlytics routing.
class AppLogger {
  AppLogger._();

  /// Logs a debug trace (development only)
  static void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode) return;
    developer.log(
      message,
      name: tag ?? 'Kortex',
      level: 500,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs an informational event
  static void info(String message, {String? tag}) {
    if (kReleaseMode) return;
    developer.log(message, name: tag ?? 'Kortex', level: 800);
  }

  /// Logs a warning (handled degradation or fallback)
  static void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '⚠️ $message',
      name: tag ?? 'Kortex',
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs an error and dispatches non-fatal exception to Crashlytics
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    bool recordCrashlytics = true,
  }) {
    developer.log(
      '🚨 $message',
      name: tag ?? 'Kortex',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );

    if (recordCrashlytics && error != null) {
      recordNonFatal(error, stackTrace, reason: message);
    }
  }

  /// Records a non-fatal error to Firebase Crashlytics safely
  static void recordNonFatal(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    Iterable<Object> information = const [],
  }) {
    developer.log(
      'AppLogger.recordNonFatal: $error',
      name: 'Kortex',
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );

    try {
      if (locator.isRegistered<CrashlyticsService>()) {
        unawaited(
          locator<CrashlyticsService>().recordError(
            error,
            stackTrace,
            reason: reason,
            information: information,
          ),
        );
      }
    } on Object catch (e) {
      developer.log('AppLogger: Failed to dispatch to Crashlytics: $e');
    }
  }
}
