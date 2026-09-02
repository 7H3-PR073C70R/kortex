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
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? frontLatex;
  final String? backLatex;
  final String? imageUrl;
  final int interval;
  final int repetitions;
  final double easeFactor;
  final DateTime? lastReviewed;
  final DateTime? nextDueDate;
  final String? sourceTopic;

  bool get isDueToday {
    if (nextDueDate == null) return true;
    final now = DateTime.now();
    return nextDueDate!.isBefore(now) ||
        (nextDueDate!.year == now.year &&
            nextDueDate!.month == now.month &&
            nextDueDate!.day == now.day);
  }

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
      ];
}
