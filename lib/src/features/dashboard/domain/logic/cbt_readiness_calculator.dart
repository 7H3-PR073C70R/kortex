import 'package:flutter/material.dart';

/// Algorithmic CBT Exam Readiness score calculator based on syllabus coverage,
/// active-recall FSRS card retention rate, CBT mock test scores, and target exam date proximity.
class CbtReadinessResult {
  const CbtReadinessResult({
    required this.scorePercent,
    required this.statusLabel,
    required this.statusColor,
    required this.syllabusCoverage,
    required this.fsrsRetentionRate,
    required this.mockScoreRatio,
  });

  /// Overall readiness index (0 to 100)
  final int scorePercent;

  /// Human readable diagnostic tag (e.g. "On Track", "Needs Acceleration", "Critical Review")
  final String statusLabel;

  /// UI Color associated with the readiness status
  final Color statusColor;

  final double syllabusCoverage;
  final double fsrsRetentionRate;
  final double mockScoreRatio;
}

class CbtReadinessCalculator {
  const CbtReadinessCalculator();

  /// Computes a weighted 0-100% CBT readiness score.
  /// Weights:
  /// - Syllabus Coverage: 30%
  /// - FSRS Active Recall Retention: 35%
  /// - CBT Mock Exam Performance: 25%
  /// - Time Urgency Balance: 10%
  CbtReadinessResult compute({
    required double syllabusCoverage,
    required double fsrsRetentionRate,
    required double mockScoreRatio,
    required int daysRemaining,
  }) {
    final cov = syllabusCoverage.clamp(0.0, 1.0);
    final ret = fsrsRetentionRate.clamp(0.0, 1.0);
    final mock = mockScoreRatio.clamp(0.0, 1.0);

    // Time factor: if exam is further out (> 30 days), lower penalty for uncompleted syllabus.
    // If exam is imminent (< 7 days), low coverage significantly penalizes readiness score.
    final double timeFactor;
    if (daysRemaining <= 0) {
      timeFactor = 1.0;
    } else if (daysRemaining <= 7) {
      timeFactor = 0.70 + (cov * 0.30);
    } else if (daysRemaining <= 30) {
      timeFactor = 0.85 + (cov * 0.15);
    } else {
      timeFactor = 1.0;
    }

    final rawWeighted = (cov * 0.30) + (ret * 0.35) + (mock * 0.25) + (timeFactor * 0.10);
    final finalPercent = (rawWeighted * 100).round().clamp(0, 100);

    final String label;
    final Color color;

    if (finalPercent >= 75) {
      label = 'ON TRACK';
      color = const Color(0xFF10B981); // Emerald
    } else if (finalPercent >= 50) {
      label = 'ACCELERATE PREP';
      color = const Color(0xFFF59E0B); // Amber
    } else {
      label = 'NEEDS TRIAGE';
      color = const Color(0xFFEF4444); // Crimson/Rose
    }

    return CbtReadinessResult(
      scorePercent: finalPercent,
      statusLabel: label,
      statusColor: color,
      syllabusCoverage: cov,
      fsrsRetentionRate: ret,
      mockScoreRatio: mock,
    );
  }
}
