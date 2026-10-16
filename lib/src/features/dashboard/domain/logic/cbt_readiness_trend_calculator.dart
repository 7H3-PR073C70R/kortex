import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Single historical or projected point along a student's CBT readiness timeline.
class CbtReadinessTrendPoint extends Equatable {
  const CbtReadinessTrendPoint({
    required this.weekIndex,
    required this.weekLabel,
    required this.weekStartDate,
    required this.readinessScore,
    required this.testsCompleted,
    this.isProjected = false,
  });

  /// Index of the week in the timeline (0 = oldest week, N = current week).
  final int weekIndex;

  /// Short label for chart x-axis (e.g. "Wk 1", "Wk 2", "This Week").
  final String weekLabel;

  /// Beginning date of this weekly bucket.
  final DateTime weekStartDate;

  /// CBT readiness percentage (0.0 - 100.0).
  final double readinessScore;

  /// Number of CBT mocks, quizzes, or diagnostics completed in this week.
  final int testsCompleted;

  /// True if this score is a future projection or uncalibrated target trajectory.
  final bool isProjected;

  @override
  List<Object?> get props => [
        weekIndex,
        weekLabel,
        weekStartDate,
        readinessScore,
        testsCompleted,
        isProjected,
      ];
}

/// Pure domain calculator that transforms historical study sessions into a
/// multi-week CBT readiness trajectory without any Flutter or UI dependencies.
class CbtReadinessTrendCalculator {
  const CbtReadinessTrendCalculator();

  /// Calculates a rolling [weekCount]-week readiness timeline.
  ///
  /// [sessions] should be raw session maps containing at minimum:
  /// - `timestamp`: ISO-8601 string
  /// - `retentionScore`: double between 0.0 and 1.0 (accuracy)
  /// - `category`: 'quiz' | 'cbt_mock' | 'exam'
  ///
  /// [currentReadinessScore] is the currently evaluated CBT readiness percentage (0 - 100).
  /// [now] is an optional clock override for deterministic unit testing.
  List<CbtReadinessTrendPoint> calculateWeeklyTrend({
    required List<Map<String, dynamic>> sessions,
    required double currentReadinessScore,
    int weekCount = 6,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final clampedWeekCount = math.max(3, math.min(12, weekCount));

    // Filter relevant assessment sessions
    final assessmentSessions = sessions.where((s) {
      final cat = (s['category'] ?? s['activityCategory'])?.toString().toLowerCase();
      return cat == 'quiz' || cat == 'cbt_mock' || cat == 'exam';
    }).toList();

    // Generate weekly bucket date boundaries
    // week 0 is oldest (clampedWeekCount - 1 weeks ago), last week is current week.
    final points = <CbtReadinessTrendPoint>[];
    final weekStartDates = List.generate(clampedWeekCount, (i) {
      final weeksAgo = (clampedWeekCount - 1) - i;
      final dt = effectiveNow.subtract(Duration(days: 7 * weeksAgo));
      return DateTime(dt.year, dt.month, dt.day);
    });

    // If completely uncalibrated and zero activity, return flat 0% baseline
    if (assessmentSessions.isEmpty && currentReadinessScore <= 0.0) {
      return List.generate(clampedWeekCount, (i) {
        final isCurrentWeek = i == clampedWeekCount - 1;
        return CbtReadinessTrendPoint(
          weekIndex: i,
          weekLabel: isCurrentWeek ? 'Current' : 'Wk ${i + 1}',
          weekStartDate: weekStartDates[i],
          readinessScore: 0,
          testsCompleted: 0,
        );
      });
    }

    // Partition sessions into weekly buckets
    final weekScores = List.generate(clampedWeekCount, (_) => <double>[]);

    for (final session in assessmentSessions) {
      final tsStr = session['timestamp'] as String?;
      if (tsStr == null) continue;
      final dt = DateTime.tryParse(tsStr);
      if (dt == null) continue;

      final diffDays = effectiveNow.difference(dt).inDays;
      if (diffDays < 0) continue; // Future timestamp guard

      final weekIdx = (clampedWeekCount - 1) - (diffDays ~/ 7);
      if (weekIdx >= 0 && weekIdx < clampedWeekCount) {
        final score = (session['retentionScore'] as num?)?.toDouble() ?? 0.0;
        weekScores[weekIdx].add(score * 100.0);
      }
    }

    // Track running calibrated baseline
    var lastKnownCalibratedScore = 0.0;
    var hasEncounteredFirstSession = false;

    for (var i = 0; i < clampedWeekCount; i++) {
      final isCurrentWeek = i == clampedWeekCount - 1;
      final weekLabel = isCurrentWeek ? 'Current' : 'Wk ${i + 1}';
      final scoresInWeek = weekScores[i];

      if (isCurrentWeek) {
        // Current week always aligns with the authoritative currentReadinessScore
        points.add(
          CbtReadinessTrendPoint(
            weekIndex: i,
            weekLabel: weekLabel,
            weekStartDate: weekStartDates[i],
            readinessScore: currentReadinessScore,
            testsCompleted: scoresInWeek.length,
          ),
        );
        continue;
      }

      if (scoresInWeek.isNotEmpty) {
        hasEncounteredFirstSession = true;
        final weekAvg = scoresInWeek.reduce((a, b) => a + b) / scoresInWeek.length;
        lastKnownCalibratedScore = weekAvg.clamp(0.0, 100.0);

        points.add(
          CbtReadinessTrendPoint(
            weekIndex: i,
            weekLabel: weekLabel,
            weekStartDate: weekStartDates[i],
            readinessScore: (lastKnownCalibratedScore * 10).roundToDouble() / 10,
            testsCompleted: scoresInWeek.length,
          ),
        );
      } else {
        if (!hasEncounteredFirstSession) {
          // Pre-diagnostic weeks remain uncalibrated baseline (0.0)
          points.add(
            CbtReadinessTrendPoint(
              weekIndex: i,
              weekLabel: weekLabel,
              weekStartDate: weekStartDates[i],
              readinessScore: 0,
              testsCompleted: 0,
            ),
          );
        } else {
          // Carry forward calibrated score with subtle natural decay if inactive
          final decayed = (lastKnownCalibratedScore * 0.98).clamp(0.0, 100.0);
          lastKnownCalibratedScore = decayed;

          points.add(
            CbtReadinessTrendPoint(
              weekIndex: i,
              weekLabel: weekLabel,
              weekStartDate: weekStartDates[i],
              readinessScore: (decayed * 10).roundToDouble() / 10,
              testsCompleted: 0,
            ),
          );
        }
      }
    }

    return points;
  }
}
