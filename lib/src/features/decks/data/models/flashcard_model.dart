import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';

part 'flashcard_model.freezed.dart';
part 'flashcard_model.g.dart';

@freezed
abstract class FlashcardModel with _$FlashcardModel {
  const factory FlashcardModel({
    required String id,
    required String deckId,
    required String front,
    required String back,
    String? frontLatex,
    String? backLatex,
    String? imageUrl,
    // SM-2 legacy fields — retained for backward compatibility and display.
    @Default(1) int interval,
    @Default(0) int repetitions,
    @Default(2.5) double easeFactor,
    DateTime? lastReviewed,
    DateTime? nextDueDate,
    String? sourceTopic,
    // FSRS-6 native memory state — authoritative source of truth.
    @Default(0.0) double fsrsStability,
    @Default(0.0) double fsrsDifficulty,
    @Default(0) int fsrsElapsedDays,
    @Default(0) int fsrsScheduledDays,
    @Default(0) int fsrsLapses,
    /// FSRS learning state: 0=new, 1=learning, 2=review, 3=relearning.
    @Default(0) int fsrsState,
  }) = _FlashcardModel;

  const FlashcardModel._();

  bool get isDueToday {
    if (nextDueDate == null) return true;
    final now = DateTime.now();
    return nextDueDate!.isBefore(now) ||
        (nextDueDate!.year == now.year &&
            nextDueDate!.month == now.month &&
            nextDueDate!.day == now.day);
  }

  factory FlashcardModel.fromJson(Map<String, dynamic> json) =>
      _$FlashcardModelFromJson(json);

  factory FlashcardModel.fromEntity(FlashcardEntity entity) {
    return FlashcardModel(
      id: entity.id,
      deckId: entity.deckId,
      front: entity.front,
      back: entity.back,
      frontLatex: entity.frontLatex,
      backLatex: entity.backLatex,
      imageUrl: entity.imageUrl,
      interval: entity.interval,
      repetitions: entity.repetitions,
      easeFactor: entity.easeFactor,
      lastReviewed: entity.lastReviewed,
      nextDueDate: entity.nextDueDate,
      sourceTopic: entity.sourceTopic,
      fsrsStability: entity.fsrsStability,
      fsrsDifficulty: entity.fsrsDifficulty,
      fsrsElapsedDays: entity.fsrsElapsedDays,
      fsrsScheduledDays: entity.fsrsScheduledDays,
      fsrsLapses: entity.fsrsLapses,
      fsrsState: entity.fsrsState,
    );
  }

  FlashcardEntity toEntity() {
    return FlashcardEntity(
      id: id,
      deckId: deckId,
      front: front,
      back: back,
      frontLatex: frontLatex,
      backLatex: backLatex,
      imageUrl: imageUrl,
      interval: interval,
      repetitions: repetitions,
      easeFactor: easeFactor,
      lastReviewed: lastReviewed,
      nextDueDate: nextDueDate,
      sourceTopic: sourceTopic,
      fsrsStability: fsrsStability,
      fsrsDifficulty: fsrsDifficulty,
      fsrsElapsedDays: fsrsElapsedDays,
      fsrsScheduledDays: fsrsScheduledDays,
      fsrsLapses: fsrsLapses,
      fsrsState: fsrsState,
    );
  }
}
