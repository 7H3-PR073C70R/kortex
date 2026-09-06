import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';
import 'package:kortex/src/features/decks/domain/logic/sm2_algorithm_engine.dart';

enum SpacedRepetitionAlgorithm {
  @Deprecated('Use FSRS-6 exclusively. Legacy SM-2 is superseded.')
  sm2,
  fsrs,
}

class UnifiedReviewResult {
  const UnifiedReviewResult({
    required this.algorithm,
    required this.nextIntervalDays,
    required this.nextDueDate,
    this.sm2Result,
    this.fsrsState,
  });

  final SpacedRepetitionAlgorithm algorithm;
  final int nextIntervalDays;
  final DateTime nextDueDate;
  final Sm2CalculationResult? sm2Result;
  final FsrsCardState? fsrsState;
}

/// Unified scheduler factory configured strictly to use FSRS Version 6.
class SchedulerFactory {
  SchedulerFactory({
    @Deprecated('Legacy SM-2 engine is ignored in favor of FSRS-6')
    Sm2AlgorithmEngine? sm2Engine,
    FsrsAlgorithmEngine? fsrsEngine,
  }) : _fsrs = fsrsEngine ?? FsrsAlgorithmEngine();

  final FsrsAlgorithmEngine _fsrs;

  UnifiedReviewResult calculate({
    required int rating, // 1=Again, 2=Hard, 3=Good, 4=Easy (or legacy 0-5 quality)
    SpacedRepetitionAlgorithm algorithm = SpacedRepetitionAlgorithm.fsrs,
    int previousInterval = 1,
    int previousReps = 0,
    double previousEaseFactor = 2.5,
    FsrsCardState? previousFsrsState,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    // Map input rating to FsrsRating (handling both 1..4 scale and legacy 0..5 quality scale)
    final FsrsRating fsrsRating;
    if (rating >= 1 && rating <= 4 && algorithm == SpacedRepetitionAlgorithm.fsrs) {
      fsrsRating = FsrsRating.fromValue(rating);
    } else {
      // Legacy quality mapping (0-2: Again, 3: Hard, 4: Good, 5: Easy)
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
