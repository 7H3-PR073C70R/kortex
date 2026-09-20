import 'package:equatable/equatable.dart';

class FlashcardEntity extends Equatable {
  const FlashcardEntity({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.frontLatex,
    this.backLatex,
    this.imageUrl,
    this.interval = 1,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.lastReviewed,
    this.nextDueDate,
    this.sourceTopic,
    // FSRS-6 native memory state fields
    this.fsrsStability = 0.0,
    this.fsrsDifficulty = 0.0,
    this.fsrsElapsedDays = 0,
    this.fsrsScheduledDays = 0,
    this.fsrsLapses = 0,
    this.fsrsState = 0,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? frontLatex;
  final String? backLatex;
  final String? imageUrl;

  // SM-2 legacy fields — retained for backward compatibility and display.
  final int interval;
  final int repetitions;
  final double easeFactor;
  final DateTime? lastReviewed;
  final DateTime? nextDueDate;
  final String? sourceTopic;

  // FSRS-6 native memory state — authoritative source of truth.
  /// Memory stability S in days.
  final double fsrsStability;

  /// Card difficulty D on scale [1.0, 10.0].
  final double fsrsDifficulty;

  /// Days elapsed since the previous review.
  final int fsrsElapsedDays;

  /// Next scheduled interval in days.
  final int fsrsScheduledDays;

  /// Total forgetting lapses count.
  final int fsrsLapses;

  /// FSRS learning state: 0=new, 1=learning, 2=review, 3=relearning.
  final int fsrsState;

  bool get isDueToday {
    if (nextDueDate == null) return true;
    final now = DateTime.now();
    return nextDueDate!.isBefore(now) ||
        (nextDueDate!.year == now.year &&
            nextDueDate!.month == now.month &&
            nextDueDate!.day == now.day);
  }

  /// Whether this card has been seen before (has real FSRS state or legacy repetitions).
  bool get hasBeenReviewed => fsrsState > 0 || repetitions > 0;

  FlashcardEntity copyWith({
    String? id,
    String? deckId,
    String? front,
    String? back,
    String? frontLatex,
    String? backLatex,
    String? imageUrl,
    int? interval,
    int? repetitions,
    double? easeFactor,
    DateTime? lastReviewed,
    DateTime? nextDueDate,
    String? sourceTopic,
    double? fsrsStability,
    double? fsrsDifficulty,
    int? fsrsElapsedDays,
    int? fsrsScheduledDays,
    int? fsrsLapses,
    int? fsrsState,
  }) {
    return FlashcardEntity(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      frontLatex: frontLatex ?? this.frontLatex,
      backLatex: backLatex ?? this.backLatex,
      imageUrl: imageUrl ?? this.imageUrl,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      sourceTopic: sourceTopic ?? this.sourceTopic,
      fsrsStability: fsrsStability ?? this.fsrsStability,
      fsrsDifficulty: fsrsDifficulty ?? this.fsrsDifficulty,
      fsrsElapsedDays: fsrsElapsedDays ?? this.fsrsElapsedDays,
      fsrsScheduledDays: fsrsScheduledDays ?? this.fsrsScheduledDays,
      fsrsLapses: fsrsLapses ?? this.fsrsLapses,
      fsrsState: fsrsState ?? this.fsrsState,
    );
  }

  @override
  List<Object?> get props => [
    id,
    deckId,
    front,
    back,
    frontLatex,
    backLatex,
    imageUrl,
    interval,
    repetitions,
    easeFactor,
    lastReviewed,
    nextDueDate,
    sourceTopic,
    fsrsStability,
    fsrsDifficulty,
    fsrsElapsedDays,
    fsrsScheduledDays,
    fsrsLapses,
    fsrsState,
  ];
}
