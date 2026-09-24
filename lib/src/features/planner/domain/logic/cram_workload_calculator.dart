import 'dart:math' as math;
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';

enum ExamUrgencyLevel {
  normal, // Green: on track, ample runway
  warning, // Amber: approaching prep window
  critical, // Crimson: final crunch (< 24-48h for quizzes, < 7d for finals)
}

enum StudyPriorityLevel {
  low,
  normal,
  high,
  critical,
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

  double get _factor => math.pow(0.9, -1.0 / decayExponent).toDouble() - 1.0;

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

  /// Categorizes urgency based on days remaining and assessment type.
  /// Solves the urgency inversion where short-horizon quizzes induced artificial panic.
  ExamUrgencyLevel getUrgencyLevel(
    int daysRemaining, {
    AssessmentType type = AssessmentType.finalExam,
  }) {
    switch (type) {
      case AssessmentType.quiz:
        if (daysRemaining > 3) return ExamUrgencyLevel.normal;
        if (daysRemaining >= 1) return ExamUrgencyLevel.warning;
        return ExamUrgencyLevel.critical;
      case AssessmentType.classTest:
        if (daysRemaining > 7) return ExamUrgencyLevel.normal;
        if (daysRemaining >= 3) return ExamUrgencyLevel.warning;
        return ExamUrgencyLevel.critical;
      case AssessmentType.midterm:
        if (daysRemaining > 14) return ExamUrgencyLevel.normal;
        if (daysRemaining >= 5) return ExamUrgencyLevel.warning;
        return ExamUrgencyLevel.critical;
      case AssessmentType.finalExam:
      case AssessmentType.mockExam:
      case AssessmentType.custom:
        if (daysRemaining > 14) return ExamUrgencyLevel.normal;
        if (daysRemaining >= 7) return ExamUrgencyLevel.warning;
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
  /// When [empiricalQuizScorePercent] is provided, applies a Bimodal Cognitive Model:
  /// 50% FSRS theoretical retrievability + 50% empirical diagnostic quiz performance.
  double calculateExamReadinessScore({
    required int totalCards,
    required int masteredCards,
    required double averageStability,
    required int daysRemaining,
    double averageDifficulty = 5.0,
    int totalLapses = 0,
    double? empiricalQuizScorePercent,
  }) {
    if (totalCards <= 0) {
      if (empiricalQuizScorePercent != null) {
        final normalized = (empiricalQuizScorePercent > 1.0
                ? empiricalQuizScorePercent
                : empiricalQuizScorePercent * 100.0)
            .clamp(0.0, 100.0);
        return normalized;
      }
      return 0;
    }

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
        (0.45 * coverage + 0.55 * projectedR) *
        difficultyModifier *
        lapsePenalty;

    final fsrsReadiness = (compositeScore * 100.0).clamp(0.0, 100.0);

    if (empiricalQuizScorePercent == null) {
      return fsrsReadiness;
    }

    final normalizedQuiz = (empiricalQuizScorePercent > 1.0
            ? empiricalQuizScorePercent
            : empiricalQuizScorePercent * 100.0)
        .clamp(0.0, 100.0);

    // Bimodal blend: 50% FSRS memory retrievability + 50% diagnostic quiz verification
    return (0.50 * fsrsReadiness + 0.50 * normalizedQuiz).clamp(0.0, 100.0);
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

  /// Calculates the Study Priority Index (SPI) on a 0.0 to 100.0 scale.
  /// Combines assessment grade weight, time-to-evaluation urgency, and workload deficit.
  double calculatePriorityScore({required ExamEventEntity exam}) {
    if (exam.isCompleted || exam.isPast) return 0;

    // 1. Grade Weight Factor (0.1 to 1.0)
    final weight = exam.effectiveWeightPercent;
    final normWeight =
        (weight > 1.0 ? weight / 60.0 : weight / 0.60).clamp(0.1, 1.0);

    // 2. Time-to-Evaluation Urgency Factor
    final hours = exam.timeRemaining.inHours;
    final double urgencyFactor;
    if (hours <= 24) {
      urgencyFactor = 1.0;
    } else if (hours <= 48) {
      urgencyFactor = 0.85;
    } else if (exam.daysRemaining <= 4) {
      urgencyFactor = 0.70;
    } else if (exam.daysRemaining <= 7) {
      urgencyFactor = 0.50;
    } else if (exam.daysRemaining <= 14) {
      urgencyFactor = 0.35;
    } else {
      urgencyFactor = (14.0 / math.max(14, exam.daysRemaining)) * 0.35;
    }

    // 3. Workload Deficit Factor (unmastered cards + lapses vs total)
    final workloadDeficit = exam.totalCardsCount > 0
        ? ((exam.remainingCards + exam.totalLapses * 1.5) /
                exam.totalCardsCount)
            .clamp(0.1, 1.5)
        : 0.5;

    // Composite: 40% Grade Weight, 40% Urgency, 20% Workload Deficit
    final composite = (normWeight * 40.0) +
        (urgencyFactor * 40.0) +
        ((workloadDeficit / 1.5) * 20.0);

    return composite.clamp(0.0, 100.0);
  }

  /// Categorizes SPI into discrete priority levels.
  StudyPriorityLevel calculatePriorityLevel({required ExamEventEntity exam}) {
    final score = calculatePriorityScore(exam: exam);
    if (score >= 70.0) return StudyPriorityLevel.critical;
    if (score >= 45.0) return StudyPriorityLevel.high;
    if (score >= 25.0) return StudyPriorityLevel.normal;
    return StudyPriorityLevel.low;
  }

  /// Calculates the total consolidated daily card workload across all active upcoming assessments.
  int calculateTotalDailyWorkload(List<ExamEventEntity> exams) {
    var total = 0;
    for (final e in exams) {
      if (!e.isCompleted && !e.isPast) {
        total += calculateDailyTarget(
          remainingCards: e.remainingCards,
          lapses: e.totalLapses,
          daysRemaining: e.daysRemaining,
        );
      }
    }
    return total;
  }

  /// Estimates daily study time in minutes (~20 seconds per card recall, minimum 5 mins if cards > 0).
  int calculateEstimatedDailyMinutes(int dailyCards) {
    if (dailyCards <= 0) return 0;
    return math.max(5, (dailyCards * 20 / 60).ceil());
  }
}
