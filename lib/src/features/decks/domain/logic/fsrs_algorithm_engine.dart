import 'dart:math' as math;
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart'
    as scheduler;

/// Pure mathematical engine for Free Spaced Repetition Scheduler (FSRS-6).
class FsrsAlgorithmEngine {
  FsrsAlgorithmEngine({
    List<double>? weights,
    this.desiredRetention = 0.90,
  }) : weights = weights ?? defaultWeights,
       _scheduler = scheduler.FsrsScheduler(
         requestRetention: desiredRetention,
         weights: weights ?? defaultWeights,
       );

  /// Standard FSRS-6 21-parameter weights vector.
  static const List<double> defaultWeights =
      scheduler.FsrsScheduler.defaultWeights;

  final List<double> weights;
  final double desiredRetention;
  final scheduler.FsrsScheduler _scheduler;

  /// Calculates the current retrievability using FSRS-6 power forgetting curve.
  double calculateRetrievability({
    required double stability,
    required int elapsedDays,
  }) {
    return _scheduler.retrievability(
      elapsedDays.toDouble(),
      stability,
    );
  }

  /// Calculates next interval in days for a target desired retention using FSRS-6.
  /// When [daysUntilExam] is provided, applies acute assessment deadline compression
  /// to ensure cards are not scheduled past an upcoming test/exam.
  int calculateNextInterval(double stability, {int? daysUntilExam}) {
    if (stability <= 0) return 1;
    final decayExponent = weights.length > 20 ? weights[20] : 0.5;
    final factor = math.pow(0.9, -1.0 / decayExponent).toDouble() - 1.0;
    final standardInterval = (stability /
            factor *
            (math.pow(desiredRetention, -1.0 / decayExponent) - 1.0))
        .round();
    final interval = math.max(1, standardInterval);

    if (daysUntilExam != null && daysUntilExam > 0) {
      if (daysUntilExam <= 2) {
        // Critical crunch (< 48h): schedule within 24 hours
        return 1;
      }
      if (daysUntilExam <= 7) {
        // Week of assessment: ensure at least one more review prior to exam day
        return math.max(1, math.min(interval, (daysUntilExam / 2).floor()));
      }
      if (daysUntilExam <= 14) {
        // 2-week acute preparation: clamp to before the exam date
        return math.max(1, math.min(interval, daysUntilExam - 1));
      }
    }

    return interval;
  }

  /// Evaluates state progression given a card's current state and new review
  /// rating using FSRS-6, with optional acute deadline horizon compression.
  FsrsMemoryState review({
    required FsrsMemoryState currentState,
    required FsrsRating rating,
    DateTime? reviewTime,
    int? daysUntilExam,
  }) {
    final now = reviewTime ?? DateTime.now();

    final isNewCard = currentState.reps == 0 && currentState.lastReview == null;
    final fsrsCard = scheduler.FsrsCard(
      cardId: 'card',
      due: currentState.nextDueDate,
      stability: currentState.stability,
      difficulty: currentState.difficulty,
      elapsedDays: currentState.elapsedDays,
      scheduledDays: currentState.scheduledDays,
      reps: currentState.reps,
      lapses: currentState.lapses,
      state: isNewCard
          ? scheduler.FsrsCardState.newCard
          : scheduler.FsrsCardState.review,
      lastReview: currentState.lastReview,
      lastReviewedEpoch: currentState.lastReview?.millisecondsSinceEpoch ?? 0,
    );

    final result = _scheduler.reviewCard(
      currentCard: fsrsCard,
      rating: rating,
      now: now,
    );

    var scheduledDays = result.card.scheduledDays;
    if (daysUntilExam != null && daysUntilExam > 0) {
      if (daysUntilExam <= 2) {
        scheduledDays = 1;
      } else if (daysUntilExam <= 7) {
        scheduledDays =
            math.max(1, math.min(scheduledDays, (daysUntilExam / 2).floor()));
      } else if (daysUntilExam <= 14) {
        scheduledDays = math.max(1, math.min(scheduledDays, daysUntilExam - 1));
      }
    }

    final dueDate = now.add(Duration(days: scheduledDays));

    return FsrsMemoryState(
      stability: double.parse(result.card.stability.toStringAsFixed(3)),
      difficulty: double.parse(result.card.difficulty.toStringAsFixed(3)),
      retrievability: calculateRetrievability(
        stability: result.card.stability,
        elapsedDays: 0,
      ),
      elapsedDays: result.card.elapsedDays,
      scheduledDays: scheduledDays,
      reps: result.card.reps,
      lapses: result.card.lapses,
      lastReview: result.card.lastReview,
      nextDueDate: dueDate,
    );
  }
}
