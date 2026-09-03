import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';
import 'package:kortex/src/features/decks/domain/logic/sm2_algorithm_engine.dart';

enum SpacedRepetitionAlgorithm {
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

class SchedulerFactory {
  SchedulerFactory({
    Sm2AlgorithmEngine? sm2Engine,
    FsrsAlgorithmEngine? fsrsEngine,
  }) : _sm2 = sm2Engine ?? const Sm2AlgorithmEngine(),
       _fsrs = fsrsEngine ?? const FsrsAlgorithmEngine();

  final Sm2AlgorithmEngine _sm2;
  final FsrsAlgorithmEngine _fsrs;

  UnifiedReviewResult calculate({
    required SpacedRepetitionAlgorithm algorithm,
    required int rating, // 1=Again, 2=Hard, 3=Good, 4=Easy (or 0-5 for SM-2)
    int previousInterval = 1,
    int previousReps = 0,
    double previousEaseFactor = 2.5,
    FsrsCardState? previousFsrsState,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    if (algorithm == SpacedRepetitionAlgorithm.fsrs) {
      final fsrsRating = FsrsRating.fromValue(rating.clamp(1, 4));
      final currentState = previousFsrsState ?? FsrsCardState.initial();
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
    } else {
      final quality = rating.clamp(0, 5);
      final sm2Res = _sm2.calculate(
        quality: quality,
        previousInterval: previousInterval,
        previousRepetitions: previousReps,
        previousEaseFactor: previousEaseFactor,
        referenceDate: now,
      );

      return UnifiedReviewResult(
        algorithm: SpacedRepetitionAlgorithm.sm2,
        nextIntervalDays: sm2Res.nextInterval,
        nextDueDate: sm2Res.nextDueDate,
        sm2Result: sm2Res,
      );
    }
  }
}
