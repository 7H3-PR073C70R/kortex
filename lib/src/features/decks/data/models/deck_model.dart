import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

part 'deck_model.freezed.dart';
part 'deck_model.g.dart';

@freezed
abstract class DeckModel with _$DeckModel {
  const factory DeckModel({
    required String id,
    required String title,
    required String subject,
    required int totalCards,
    required int dueCards,
    required double masteryRate,
    required String category,
    String? description,
    DateTime? lastStudied,
    @Default([]) List<FlashcardModel> cards,
    String? colorHex,
    String? iconName,
  }) = _DeckModel;

  const DeckModel._();

  factory DeckModel.fromJson(Map<String, dynamic> json) =>
      _$DeckModelFromJson(json);

  factory DeckModel.fromEntity(DeckEntity entity) {
    return DeckModel(
      id: entity.id,
      title: entity.title,
      subject: entity.subject,
      totalCards: entity.totalCards,
      dueCards: entity.dueCards,
      masteryRate: entity.masteryRate,
      category: entity.category,
      description: entity.description,
      lastStudied: entity.lastStudied,
      cards: entity.cards.map(FlashcardModel.fromEntity).toList(),
      colorHex: entity.colorHex,
      iconName: entity.iconName,
    );
  }

  DeckEntity toEntity() {
    return DeckEntity(
      id: id,
      title: title,
      subject: subject,
      totalCards: totalCards,
      dueCards: dueCards,
      masteryRate: masteryRate,
      category: category,
      description: description,
      lastStudied: lastStudied,
      cards: cards.map((c) => c.toEntity()).toList(),
      colorHex: colorHex,
      iconName: iconName,
    );
  }
}
