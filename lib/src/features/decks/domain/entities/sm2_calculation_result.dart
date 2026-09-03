import 'package:equatable/equatable.dart';

/// Calculation result produced by the SuperMemo-2 (SM-2) algorithm.
class Sm2CalculationResult extends Equatable {
  const Sm2CalculationResult({
    required this.nextInterval,
    required this.newEaseFactor,
    required this.newRepetitions,
    required this.nextDueDate,
  });

  /// Next repetition interval in days.
  final int nextInterval;

  /// Updated difficulty / ease factor (minimum 1.3).
  final double newEaseFactor;

  /// Consecutive successful review count.
  final int newRepetitions;

  /// Exact DateTime when this card is due next.
  final DateTime nextDueDate;

  @override
  List<Object?> get props => [
    nextInterval,
    newEaseFactor,
    newRepetitions,
    nextDueDate,
  ];
}
