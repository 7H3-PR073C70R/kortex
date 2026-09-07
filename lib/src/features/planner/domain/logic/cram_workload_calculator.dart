import 'dart:math' as math;

enum ExamUrgencyLevel {
  normal, // Green: > 14 days
  warning, // Amber: 7 to 14 days
  critical, // Crimson: < 7 days
}

/// Computes dynamic cram paces, predictive exam readiness, and retention trajectories
/// based on the FSRS-6 algorithm forgetting curve and stability metrics.
class CramWorkloadCalculator {
  const CramWorkloadCalculator({
    this.decayExponent = 0.5,
    this.targetRetention = 0.90,
  });

  final double decayExponent;
  final double targetRetention;

  double get _factor =>
      math.pow(0.9, -1.0 / decayExponent).toDouble() - 1.0;

  /// Calculates the dynamic daily flashcard target:
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
    return math.max(1, target.ceil());
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

  /// Calculates FSRS-6 power-law retrievability $R(t, S)$:
  /// $R(t, S) = (1 + \text{factor} \cdot \frac{t}{S})^{-\text{decayExponent}}$
  double calculateRetrievability({
    required double stability,
    required int elapsedDays,
  }) {
    if (stability <= 0) return 0;
    if (elapsedDays <= 0) return 1;
    return math
        .pow(1.0 + _factor * (elapsedDays / stability), -decayExponent)
        .toDouble()
        .clamp(0.0, 1.0);
  }

  /// Predicts overall Exam Readiness Score on a 0% to 100% scale.
  /// Combines topic coverage, FSRS stability retention at exam date,
  /// difficulty weighting, and lapse frequency penalties.
  double calculateExamReadinessScore({
    required int totalCards,
    required int masteredCards,
    required double averageStability,
    required int daysRemaining, double averageDifficulty = 5.0,
    int totalLapses = 0,
  }) {
    if (totalCards <= 0) return 0;

    // 1. Coverage Component (0.0 to 1.0)
    final coverage = (masteredCards / totalCards).clamp(0.0, 1.0);

    // 2. Projected Retrievability at Exam Date (0.0 to 1.0)
    final projectedR = averageStability > 0
        ? calculateRetrievability(
            stability: averageStability,
            elapsedDays: math.max(0, daysRemaining),
          )
        : (masteredCards > 0 ? 0.5 : 0.0);

    // 3. Difficulty Modifier (higher difficulty slightly decreases readiness margin)
    // Scale 1.0 (easiest) to 10.0 (hardest) -> modifier between 0.85 and 1.0
    final normDifficulty = (averageDifficulty.clamp(1.0, 10.0) - 1.0) / 9.0;
    final difficultyModifier = 1.0 - (normDifficulty * 0.15);

    // 4. Lapse Penalty (frequent lapses indicate fragile retention)
    final lapseRatio = (totalLapses / totalCards).clamp(0.0, 1.0);
    final lapsePenalty = 1.0 - (lapseRatio * 0.25);

    // Weighted combination: 45% coverage, 55% projected retrievability
    final compositeScore =
        (0.45 * coverage + 0.55 * projectedR) * difficultyModifier * lapsePenalty;

    return (compositeScore * 100.0).clamp(0.0, 100.0);
  }

  /// Projects daily retention percentages from day 0 to [daysRemaining].
  List<double> predictRetentionTrajectory({
    required double initialStability,
    required int daysRemaining,
  }) {
    final days = math.max(0, daysRemaining);
    final trajectory = <double>[];

    for (var d = 0; d <= days; d++) {
      final r = calculateRetrievability(
        stability: initialStability,
        elapsedDays: d,
      );
      trajectory.add((r * 100.0).clamp(0.0, 100.0));
    }

    return trajectory;
  }
}

