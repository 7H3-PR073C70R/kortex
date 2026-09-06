import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
abstract class DecksRepository {
  Future<Either<Failure, List<DeckEntity>>> getUserDecks();

  Future<Either<Failure, List<FlashcardEntity>>> getDeckCards(String deckId);

  Future<Either<Failure, void>> updateDeckCards(
    String deckId,
    List<FlashcardEntity> cards,
  );

  Future<Either<Failure, void>> saveSessionResults({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    double? masteryRate,
    int? dueCards,
    List<FlashcardEntity>? updatedCards,
  });

  Future<Either<Failure, void>> deleteDeck(String deckId);
}
