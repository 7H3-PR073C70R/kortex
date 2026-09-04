import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// Abstract wrapper around a trace so it can be safely used even if Firebase is disabled.
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
  Future<void> start() => _trace.start();

  @override
  Future<void> stop() => _trace.stop();

  @override
  void putAttribute(String name, String value) =>
      _trace.putAttribute(name, value);

  @override
  void incrementMetric(String name, int value) =>
      _trace.incrementMetric(name, value);

  @override
  void setMetric(String name, int value) => _trace.setMetric(name, value);
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
