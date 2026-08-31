import 'dart:math';

enum ExamUrgencyLevel {
  normal, // Green: > 14 days
  warning, // Amber: 7 to 14 days
  critical, // Crimson: < 7 days
}

/// Computes dynamic cram paces and daily card targets as exam dates approach.
class CramWorkloadCalculator {
  const CramWorkloadCalculator();

  /// Calculates dynamic daily flashcard target:
  /// $\text{Daily Target} = \lceil (\text{Remaining Cards} + (\text{Lapses} \times 1.5)) / \text{Days Remaining} \rceil$
  int calculateDailyTarget({
    required int remainingCards,
    required int lapses,
    required int daysRemaining,
  }) {
    if (remainingCards <= 0) return 0;
    if (daysRemaining <= 1) {
      return (remainingCards + (lapses * 1.5)).round();
    }

    final workload = remainingCards + (lapses * 1.5);
    final target = workload / daysRemaining;
    return max(1, target.ceil());
  }

  /// Categorizes urgency based on days remaining until the exam.
  ExamUrgencyLevel getUrgencyLevel(int daysRemaining) {
    if (daysRemaining > 14) {
      return ExamUrgencyLevel.normal;
    } else if (daysRemaining >= 7) {
      return ExamUrgencyLevel.warning;
    } else {
      return ExamUrgencyLevel.critical;
    }
  }
}
