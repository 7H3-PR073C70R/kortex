import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';

/// Intelligent scheduler that calculates optimal cognitive retention hours
/// based on historical study logs and queues timed study notifications.
class SmartStudyReminderScheduler {
  const SmartStudyReminderScheduler({
    LocalStorageService? localStorageService,
  }) : _localStorage = localStorageService;

  final LocalStorageService? _localStorage;

  LocalStorageService get _effectiveStorage =>
      _localStorage ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : throw StateError('LocalStorageService is not registered.'));

  /// Default fallback peak cognitive study hour (19:00 / 7 PM).
  static const int defaultPeakHour = 19;

  /// Analyzes stored study session timestamps to determine peak retention hour (0-23).
  int calculateOptimalRetentionHour() {
    try {
      final logsJson = _effectiveStorage.getPreference(key: 'study_session_history');
      if (logsJson == null || logsJson.isEmpty) {
        return defaultPeakHour;
      }

      // Count session frequencies per hour
      final hourCounts = List<int>.filled(24, 0);
      final timestamps = logsJson.split(',');

      for (final ts in timestamps) {
        final dt = DateTime.tryParse(ts.trim());
        if (dt != null) {
          hourCounts[dt.hour]++;
        }
      }

      var maxIndex = defaultPeakHour;
      var maxCount = 0;
      for (var i = 0; i < 24; i++) {
        if (hourCounts[i] > maxCount) {
          maxCount = hourCounts[i];
          maxIndex = i;
        }
      }

      return maxCount > 0 ? maxIndex : defaultPeakHour;
    } on Object catch (err) {
      debugPrint('[SmartStudyReminderScheduler] Calculation warning: $err');
      return defaultPeakHour;
    }
  }

  /// Calculates the next DateTime target for scheduling a smart study reminder.
  DateTime calculateNextReminderSchedule() {
    final peakHour = calculateOptimalRetentionHour();
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, peakHour);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Records a study session timestamp to refine future AI retention hour predictions.
  Future<void> recordStudySessionTimestamp([DateTime? timestamp]) async {
    try {
      final nowStr = (timestamp ?? DateTime.now()).toIso8601String();
      final existing = _effectiveStorage.getPreference(key: 'study_session_history') ?? '';
      
      final history = (existing.isEmpty ? <String>[] : existing.split(','))
        ..add(nowStr);

      // Keep most recent 50 sessions for rolling window calculation
      if (history.length > 50) {
        history.removeRange(0, history.length - 50);
      }

      await _effectiveStorage.savePreference(
        key: 'study_session_history',
        data: history.join(','),
      );
    } on Object catch (e) {
      debugPrint('[SmartStudyReminderScheduler] Record timestamp error: $e');
    }
  }
}
