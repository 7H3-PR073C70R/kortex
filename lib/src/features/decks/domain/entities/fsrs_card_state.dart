import 'package:equatable/equatable.dart';

enum FsrsRating {
  again(1),
  hard(2),
  good(3),
  easy(4)
  ;

  const FsrsRating(this.value);
  final int value;

  static FsrsRating fromValue(int val) {
    switch (val) {
      case 1:
        return FsrsRating.again;
      case 2:
        return FsrsRating.hard;
      case 3:
        return FsrsRating.good;
      case 4:
      default:
        return FsrsRating.easy;
    }
  }
}

/// Represents the mathematical memory state of a card in the FSRS-4.5 engine.
class FsrsCardState extends Equatable {
  const FsrsCardState({
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.elapsedDays,
    required this.scheduledDays,
    required this.reps,
    required this.lapses,
    required this.nextDueDate,
    this.lastReview,
  });

  /// Initial fresh state before any reviews.
  factory FsrsCardState.initial() {
    return FsrsCardState(
      stability: 0,
      difficulty: 0,
      retrievability: 1,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      nextDueDate: DateTime.now(),
    );
  }

  /// Memory stability $S$ in days (time required for retention to fall to 90%).
  final double stability;

  /// Card difficulty $D$ on scale [1.0, 10.0].
  final double difficulty;

  /// Current probability of recall $R(t, S) \in [0.0, 1.0]$.
  final double retrievability;

  /// Days elapsed since the previous review.
  final int elapsedDays;

  /// Next scheduled interval in days.
  final int scheduledDays;

  /// Total review count.
  final int reps;

  /// Total forgetting lapses count.
  final int lapses;

  /// Timestamp of the last review.
  final DateTime? lastReview;

  /// Calculated next due date.
  final DateTime nextDueDate;

  FsrsCardState copyWith({
    double? stability,
    double? difficulty,
    double? retrievability,
    int? elapsedDays,
    int? scheduledDays,
    int? reps,
    int? lapses,
    DateTime? lastReview,
    DateTime? nextDueDate,
  }) {
    return FsrsCardState(
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      retrievability: retrievability ?? this.retrievability,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReview: lastReview ?? this.lastReview,
      nextDueDate: nextDueDate ?? this.nextDueDate,
    );
  }

  @override
  List<Object?> get props => [
    stability,
    difficulty,
    retrievability,
    elapsedDays,
    scheduledDays,
    reps,
    lapses,
    lastReview,
    nextDueDate,
  ];
}
