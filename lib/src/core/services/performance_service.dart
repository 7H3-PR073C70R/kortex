import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Abstract wrapper around a trace so it can be safely used even if Firebase is disabled or unsupported.
abstract class AppTrace {
  Future<void> start();
  Future<void> stop();
  void putAttribute(String name, String value);
  void incrementMetric(String name, int value);
  void setMetric(String name, int value);
}

class _FirebaseAppTrace implements AppTrace {
  _FirebaseAppTrace(this._trace);

  final Trace _trace;

  @override
  Future<void> start() async {
    try {
      await _trace.start();
    } on MissingPluginException catch (_) {
      // Safe no-op on platforms without native channel implementation (e.g. macOS/desktop)
    } on Object catch (e) {
      developer.log('Firebase performance trace.start failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _trace.stop();
    } on MissingPluginException catch (_) {
      // Safe no-op on platforms without native channel implementation
    } on Object catch (e) {
      developer.log('Firebase performance trace.stop failed: $e');
    }
  }

  @override
  void putAttribute(String name, String value) {
    try {
      _trace.putAttribute(name, value);
    } on MissingPluginException catch (_) {
      // Safe no-op
    } on Object catch (e) {
      developer.log('Firebase performance putAttribute failed: $e');
    }
  }

  @override
  void incrementMetric(String name, int value) {
    try {
      _trace.incrementMetric(name, value);
    } on MissingPluginException catch (_) {
      // Safe no-op
    } on Object catch (e) {
      developer.log('Firebase performance incrementMetric failed: $e');
    }
  }

  @override
  void setMetric(String name, int value) {
    try {
      _trace.setMetric(name, value);
    } on MissingPluginException catch (_) {
      // Safe no-op
    } on Object catch (e) {
      developer.log('Firebase performance setMetric failed: $e');
    }
  }
}

class _NoOpAppTrace implements AppTrace {
  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void putAttribute(String name, String value) {}

  @override
  void incrementMetric(String name, int value) {}

  @override
  void setMetric(String name, int value) {}
}

/// Service wrapping Firebase Performance Monitoring.
class PerformanceService {
  PerformanceService({FirebasePerformance? performance})
    : _performance = performance;

  FirebasePerformance? _performance;

  bool get _isAvailable {
    try {
      // Firebase Performance is natively supported on iOS and Android only.
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        return false;
      }
      if (Firebase.apps.isEmpty) return false;
      _performance ??= FirebasePerformance.instance;
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  /// Creates and returns a new trace.
  AppTrace newTrace(String name) {
    if (!_isAvailable) {
      return _NoOpAppTrace();
    }
    try {
      final trace = _performance!.newTrace(name);
      return _FirebaseAppTrace(trace);
    } on Object catch (e) {
      developer.log('Failed to create Firebase performance trace: $e');
      return _NoOpAppTrace();
    }
  }

  /// Traces an asynchronous action by measuring the duration between start and completion.
  Future<T> traceAction<T>(
    String traceName,
    Future<T> Function(AppTrace trace) action, {
    Map<String, String>? attributes,
  }) async {
    final trace = newTrace(traceName);
    attributes?.forEach(trace.putAttribute);
    await trace.start();
    try {
      final result = await action(trace);
      return result;
    } finally {
      await trace.stop();
    }
  }
}
