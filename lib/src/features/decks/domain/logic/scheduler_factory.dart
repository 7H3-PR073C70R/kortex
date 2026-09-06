import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';

enum SpacedRepetitionAlgorithm {
  fsrs,
}

class UnifiedReviewResult {
  const UnifiedReviewResult({
    required this.algorithm,
    required this.nextIntervalDays,
    required this.nextDueDate,
    this.fsrsState,
  });

  final SpacedRepetitionAlgorithm algorithm;
  final int nextIntervalDays;
  final DateTime nextDueDate;
  final FsrsCardState? fsrsState;
}

/// Unified scheduler factory configured strictly to use FSRS Version 6.
class SchedulerFactory {
  SchedulerFactory({
    FsrsAlgorithmEngine? fsrsEngine,
  }) : _fsrs = fsrsEngine ?? FsrsAlgorithmEngine();

  final FsrsAlgorithmEngine _fsrs;

  UnifiedReviewResult calculate({
    required int rating, // 1=Again, 2=Hard, 3=Good, 4=Easy
    SpacedRepetitionAlgorithm algorithm = SpacedRepetitionAlgorithm.fsrs,
    int previousInterval = 1,
    int previousReps = 0,
    double previousEaseFactor = 2.5,
    FsrsCardState? previousFsrsState,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    final FsrsRating fsrsRating;
    if (rating >= 1 && rating <= 4) {
      fsrsRating = FsrsRating.fromValue(rating);
    } else {
      // Fallback for edge cases
      if (rating < 3) {
        fsrsRating = FsrsRating.again;
      } else if (rating == 3) {
        fsrsRating = FsrsRating.hard;
      } else if (rating == 4) {
        fsrsRating = FsrsRating.good;
      } else {
        fsrsRating = FsrsRating.easy;
      }
    }

    final currentState = previousFsrsState ??
        FsrsCardState(
          stability: previousInterval > 0 ? previousInterval.toDouble() : 0.0,
          difficulty: ((3.0 - previousEaseFactor) * 5.0).clamp(1.0, 10.0),
          retrievability: 1,
          elapsedDays: previousInterval,
          scheduledDays: previousInterval,
          reps: previousReps,
          lapses: 0,
          nextDueDate: now.add(Duration(days: previousInterval)),
        );

    final updatedFsrs = _fsrs.review(
      currentState: currentState,
      rating: fsrsRating,
      reviewTime: now,
    );

    return UnifiedReviewResult(
      algorithm: SpacedRepetitionAlgorithm.fsrs,
      nextIntervalDays: updatedFsrs.scheduledDays,
      nextDueDate: updatedFsrs.nextDueDate,
      fsrsState: updatedFsrs,
    );
  }
}
