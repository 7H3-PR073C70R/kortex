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
    @Default(1) int interval,
    @Default(0) int repetitions,
    @Default(2.5) double easeFactor,
    DateTime? lastReviewed,
    DateTime? nextDueDate,
    String? sourceTopic,
  }) = _FlashcardModel;

  const FlashcardModel._();

  bool get isDueToday =>
      nextDueDate == null || nextDueDate!.isBefore(DateTime.now());

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
    );
  }
}
