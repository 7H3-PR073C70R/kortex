import 'dart:math';
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';

/// Pure mathematical engine for Free Spaced Repetition Scheduler (FSRS-4.5).
class FsrsAlgorithmEngine {
  const FsrsAlgorithmEngine({
    this.weights = defaultWeights,
    this.desiredRetention = 0.90,
  });

  /// Standard FSRS-4.5 17-parameter weights vector.
  static const List<double> defaultWeights = [
    0.4, 0.6, 2.4, 5.8, // w0-w3: Initial stability for ratings 1, 2, 3, 4
    4.93, 0.94, // w4-w5: Initial difficulty
    0.86, 0.01, // w6-w7: Difficulty transition & mean reversion
    1.49, 0.14, 0.94, // w8-w10: Stability recall transition
    2.18, 0.05, 0.34, 1.26, // w11-w14: Stability forgetting/lapse transition
    0.29, 2.61, // w15-w16: Hard penalty & Easy bonus
  ];

  final List<double> weights;
  final double desiredRetention;

  /// Calculates the current retrievability $R(t, S) = (1 + 0.9 \cdot t / S)^{-1}$.
  double calculateRetrievability({
    required double stability,
    required int elapsedDays,
  }) {
    if (stability <= 0) return 0;
    if (elapsedDays <= 0) return 1;
    final r = 1.0 / (1.0 + 0.9 * (elapsedDays / stability));
    return r.clamp(0.0, 1.0);
  }

  /// Calculates next interval in days for a target desired retention.
  int calculateNextInterval(double stability) {
    if (stability <= 0) return 1;
    // At r = 0.90, I = S. In general, I = 9 * S * (1/r - 1).
    final interval = 9.0 * stability * ((1.0 / desiredRetention) - 1.0);
    return max(1, interval.round());
  }

  /// Evaluates state progression given a card's current state and new review
  /// rating.
  FsrsCardState review({
    required FsrsCardState currentState,
    required FsrsRating rating,
    DateTime? reviewTime,
  }) {
    final now = reviewTime ?? DateTime.now();
    final grade = rating.value;

    final elapsedDays = currentState.lastReview == null
        ? 0
        : max(0, now.difference(currentState.lastReview!).inDays);

    double newStability;
    double newDifficulty;
    var newLapses = currentState.lapses;

    if (currentState.reps == 0) {
      // First review initialization
      newStability = weights[grade - 1];
      newDifficulty = (weights[4] - (grade - 3) * weights[5]).clamp(1.0, 10.0);
      if (grade == 1) {
        newLapses += 1;
      }
    } else {
      final currentR = calculateRetrievability(
        stability: currentState.stability,
        elapsedDays: elapsedDays,
      );

      // Update Difficulty
      final deltaD = -weights[6] * (grade - 3);
      final rawD = currentState.difficulty + deltaD;
      final initD3 = weights[4];
      newDifficulty =
          (weights[7] * initD3 + (1.0 - weights[7]) * rawD).clamp(1.0, 10.0);

      // Update Stability
      if (grade == 1) {
        // Lapse / Forget
        newLapses += 1;
        final base = pow(currentState.stability, weights[13]) + 1.0;
        final lapseS = weights[11] *
            pow(newDifficulty, -weights[12]) *
            pow(base, weights[14]) *
            exp(weights[15] * (1.0 - currentR));
        newStability = max(0.1, min(lapseS, currentState.stability));
      } else {
        // Success recall
        final hardPenalty = grade == 2 ? weights[15] : 1.0;
        final easyBonus = grade == 4 ? weights[16] : 1.0;
        final sFactor = 1.0 +
            exp(weights[8]) *
                (11.0 - newDifficulty) *
                pow(currentState.stability, -weights[9]) *
                (exp(weights[10] * (1.0 - currentR)) - 1.0) *
                hardPenalty *
                easyBonus;
        newStability = max(
          currentState.stability,
          currentState.stability * sFactor,
        );
      }
    }

    final scheduledDays =
        grade == 1 ? 1 : calculateNextInterval(newStability);
    final nextDueDate = now.add(Duration(days: scheduledDays));

    return FsrsCardState(
      stability: double.parse(newStability.toStringAsFixed(3)),
      difficulty: double.parse(newDifficulty.toStringAsFixed(3)),
      retrievability: calculateRetrievability(
        stability: newStability,
        elapsedDays: 0,
      ),
      elapsedDays: elapsedDays,
      scheduledDays: scheduledDays,
      reps: currentState.reps + 1,
      lapses: newLapses,
      lastReview: now,
      nextDueDate: nextDueDate,
    );
  }
}
