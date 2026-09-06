import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';

abstract class DecksLocalDataSource {
  /// Retrieves all cached decks from the local relational database.
  Future<List<DeckModel>> getDecks();

  /// Retrieves a specific deck by [id] with its cards.
  Future<DeckModel?> getDeck(String id);

  /// Retrieves cards belonging to [deckId], ordered by next due date.
  Future<List<FlashcardModel>> getCardsForDeck(String deckId);

  /// Retrieves all cards that are currently due for review.
  Future<List<FlashcardModel>> getDueCards({
    String? deckId,
    DateTime? beforeDate,
  });

  /// Saves a deck and optionally its initial flashcards atomically.
  Future<void> saveDeck(DeckModel deck, {List<FlashcardModel>? cards});

  /// Saves or replaces cards for a specific [deckId].
  Future<void> saveCards(String deckId, List<FlashcardModel> cards);

  /// Fast single-card update without re-serializing unrelated cards or decks.
  Future<void> updateCard(FlashcardModel card);

  /// Batch update multiple flashcards inside a single atomic SQLite transaction.
  Future<void> batchUpdateCards(List<FlashcardModel> cards);

  /// Updates deck review metadata (mastery rate, due count, last studied).
  Future<void> updateDeckStats({
    required String deckId,
    double? masteryRate,
    int? dueCards,
    DateTime? lastStudied,
  });

  /// Links a deck to an academic course.
  Future<void> linkDeckToCourse({
    required String deckId,
    required String courseId,
    String? courseCode,
    String? subject,
  });

  /// Deletes a deck and cascades deletion to all its flashcards.
  Future<void> deleteDeck(String deckId);

  /// Deletes decks associated with a course.
  Future<void> deleteDecksForCourse(
    String courseId, {
    String? courseCode,
    String? subject,
  });

  /// Clears all decks and cards from the local database.
  Future<void> deleteAllDecks();

  /// Sub-millisecond full-text search (FTS5) across cards.
  Future<List<FlashcardModel>> searchCards(String query, {String? deckId});
}
