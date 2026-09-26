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
    required this.projectedGrade,
    required this.projectedScoreRange,
    this.remediationSuggestion = '',
    this.weakestAreaLabel = '',
  });

  /// Overall readiness index (0 to 100)
  final int scorePercent;

  /// Human readable diagnostic tag (e.g. "ON TRACK", "ACCELERATE PREP", "NEEDS TRIAGE")
  final String statusLabel;

  /// UI Color associated with the readiness status
  final Color statusColor;

  final double syllabusCoverage;
  final double fsrsRetentionRate;
  final double mockScoreRatio;

  /// Projected letter grade (e.g., "A+", "A", "B+", "B", "C", "D", "F")
  final String projectedGrade;

  /// Projected CBT exam score range (e.g., "290 - 325 / 400")
  final String projectedScoreRange;

  /// Actionable Socratic recommendation to boost score
  final String remediationSuggestion;

  /// Diagnostic identification of the primary bottleneck
  final String weakestAreaLabel;
}

class CbtReadinessCalculator {
  const CbtReadinessCalculator();

  /// Computes a weighted 0-100% CBT readiness score and projects expected exam grade.
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
    String? explicitWeakestTopic,
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
    final String grade;
    final String scoreRange;

    if (finalPercent >= 90) {
      label = 'ON TRACK';
      color = const Color(0xFF10B981); // Emerald
      grade = 'A+';
      scoreRange = '320 - 360 / 400';
    } else if (finalPercent >= 80) {
      label = 'ON TRACK';
      color = const Color(0xFF10B981); // Emerald
      grade = 'A';
      scoreRange = '280 - 315 / 400';
    } else if (finalPercent >= 70) {
      label = 'ACCELERATE PREP';
      color = const Color(0xFFF59E0B); // Amber
      grade = 'B+';
      scoreRange = '250 - 279 / 400';
    } else if (finalPercent >= 60) {
      label = 'ACCELERATE PREP';
      color = const Color(0xFFF59E0B); // Amber
      grade = 'B';
      scoreRange = '220 - 249 / 400';
    } else if (finalPercent >= 50) {
      label = 'NEEDS TRIAGE';
      color = const Color(0xFFEF4444); // Crimson/Rose
      grade = 'C';
      scoreRange = '190 - 219 / 400';
    } else if (finalPercent >= 40) {
      label = 'NEEDS TRIAGE';
      color = const Color(0xFFEF4444); // Crimson/Rose
      grade = 'D';
      scoreRange = '160 - 189 / 400';
    } else {
      label = 'NEEDS TRIAGE';
      color = const Color(0xFFEF4444); // Crimson/Rose
      grade = 'F';
      scoreRange = '< 160 / 400';
    }

    // Determine primary bottleneck diagnostic
    var weakestArea = explicitWeakestTopic ?? '';
    if (weakestArea.isEmpty) {
      if (ret < cov && ret < mock) {
        weakestArea = 'FSRS Memory Retention';
      } else if (cov < ret && cov < mock) {
        weakestArea = 'Syllabus Module Coverage';
      } else {
        weakestArea = 'Mock Test Speed & Accuracy';
      }
    }

    // Actionable Socratic remediation suggestion
    final String remediation;
    if (finalPercent >= 80) {
      remediation = 'Maintain momentum with a 10-minute timed mock sprint to lock in retention.';
    } else if (ret < 0.70) {
      remediation = 'Review 15 high-priority FSRS flashcards to repair decaying memory stability.';
    } else if (cov < 0.60) {
      remediation = 'Complete 1 new syllabus topic module to boost overall syllabus coverage.';
    } else {
      remediation = 'Take a 15-question CBT Practice Test to improve timed exam confidence.';
    }

    return CbtReadinessResult(
      scorePercent: finalPercent,
      statusLabel: label,
      statusColor: color,
      syllabusCoverage: cov,
      fsrsRetentionRate: ret,
      mockScoreRatio: mock,
      projectedGrade: grade,
      projectedScoreRange: scoreRange,
      remediationSuggestion: remediation,
      weakestAreaLabel: weakestArea,
    );
  }
}
