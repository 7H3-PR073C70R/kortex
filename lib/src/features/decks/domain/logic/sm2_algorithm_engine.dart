import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';

/// Pure mathematical engine for SuperMemo-2 (SM-2) spaced repetition.
class Sm2AlgorithmEngine {
  const Sm2AlgorithmEngine();

  /// Calculates the next interval, ease factor, and repetition count.
  ///
  /// [quality] rating ranges from 0 (complete blackout) to 5 (perfect).
  /// [previousInterval] previous scheduled interval in days.
  /// [previousRepetitions] consecutive successful reviews count.
  /// [previousEaseFactor] current difficulty factor (defaults to 2.5).
  Sm2CalculationResult calculate({
    required int quality,
    required int previousInterval,
    required int previousRepetitions,
    double previousEaseFactor = 2.5,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final clampedQuality = quality.clamp(0, 5);

    int newRepetitions;
    int nextInterval;

    if (clampedQuality < 3) {
      // Again / Failed review -> Reset repetition count and schedule for 1 day
      newRepetitions = 0;
      nextInterval = 1;
    } else {
      // Successful recall (quality >= 3)
      if (previousRepetitions == 0) {
        nextInterval = 1;
      } else if (previousRepetitions == 1) {
        nextInterval = 6;
      } else {
        nextInterval = (previousInterval * previousEaseFactor).round();
        if (nextInterval <= previousInterval) {
          nextInterval = previousInterval + 1;
        }
      }
      newRepetitions = previousRepetitions + 1;
    }

    // Update Ease Factor: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    final qDiff = 5 - clampedQuality;
    var newEaseFactor =
        previousEaseFactor + (0.1 - (qDiff * (0.08 + (qDiff * 0.02))));
    if (newEaseFactor < 1.3) {
      newEaseFactor = 1.3;
    }

    final nextDueDate = now.add(Duration(days: nextInterval));

    return Sm2CalculationResult(
      nextInterval: nextInterval,
      newEaseFactor: double.parse(newEaseFactor.toStringAsFixed(3)),
      newRepetitions: newRepetitions,
      nextDueDate: nextDueDate,
    );
  }
}
