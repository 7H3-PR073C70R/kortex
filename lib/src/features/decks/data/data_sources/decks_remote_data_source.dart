import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';

abstract class DecksRemoteDataSource {
  Future<List<DeckModel>> getUserDecks();

  Future<List<FlashcardModel>> getDeckCards(String deckId);

  Future<void> saveGeneratedDeck({
    required DeckModel deck,
    required List<FlashcardModel> cards,
  });

  Future<Sm2CalculationResult> processCardReview({
    required String cardId,
    required int quality,
    required int previousInterval,
    required int previousRepetitions,
    required double previousEaseFactor,
  });

  Future<void> saveSessionResults({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
  });

  Future<void> deleteDeck(String deckId);
}
