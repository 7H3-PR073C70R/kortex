import 'dart:async';

import 'package:drift/drift.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';

class DecksLocalDataSourceImpl implements DecksLocalDataSource {
  DecksLocalDataSourceImpl(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<DeckModel>> getDecks() async {
    final entries = await _appDatabase.getAllDecks();
    return entries.map(_deckFromEntry).toList();
  }

  @override
  Future<DeckModel?> getDeck(String id) async {
    final entry = await _appDatabase.getDeckById(id);
    if (entry == null) return null;
    final cards = await getCardsForDeck(id);
    return _deckFromEntry(entry, cards);
  }

  @override
  Future<List<FlashcardModel>> getCardsForDeck(String deckId) async {
    final entries = await _appDatabase.getCardsForDeckId(deckId);
    return entries.map(_cardFromEntry).toList();
  }

  @override
  Future<List<FlashcardModel>> getDueCards({
    String? deckId,
    DateTime? beforeDate,
  }) async {
    final entries = await _appDatabase.getDueCardsList(
      deckId: deckId,
      beforeDate: beforeDate,
    );
    return entries.map(_cardFromEntry).toList();
  }

  @override
  Future<void> saveDeck(DeckModel deck, {List<FlashcardModel>? cards}) async {
    final cardsToSave = cards ?? deck.cards;
    final deckComp = _deckToCompanion(deck);
    final cardsComp =
        cardsToSave.map((c) => _cardToCompanion(c, deck.id)).toList();
    await _appDatabase.batchUpsertDeckAndCardsTransaction(
      deckComp,
      cardsComp,
    );
  }

  @override
  Future<void> saveCards(String deckId, List<FlashcardModel> cards) async {
    final cardsComp =
        cards.map((c) => _cardToCompanion(c, deckId)).toList();
    await _appDatabase.batchUpsertFlashcards(cardsComp);
  }

  @override
  Future<void> updateCard(FlashcardModel card) async {
    await _appDatabase.upsertFlashcardEntry(_cardToCompanion(card));
  }

  @override
  Future<void> batchUpdateCards(List<FlashcardModel> cards) async {
    final cardsComp = cards.map(_cardToCompanion).toList();
    await _appDatabase.batchUpsertFlashcards(cardsComp);
  }

  @override
  Future<void> updateDeckStats({
    required String deckId,
    double? masteryRate,
    int? dueCards,
    DateTime? lastStudied,
  }) async {
    await _appDatabase.updateDeckMetadataFields(
      deckId,
      masteryRate: masteryRate,
      dueCards: dueCards,
      lastStudied: lastStudied,
    );
  }

  @override
  Future<void> linkDeckToCourse({
    required String deckId,
    required String courseId,
    String? courseCode,
    String? subject,
  }) async {
    await _appDatabase.updateDeckMetadataFields(
      deckId,
      courseId: courseId,
      courseCode: courseCode,
      subject: subject,
    );
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    await _appDatabase.deleteDeckById(deckId);
  }

  @override
  Future<void> deleteDecksForCourse(
    String courseId, {
    String? courseCode,
    String? subject,
  }) async {
    await _appDatabase.deleteDecksForCourseId(
      courseId,
      courseCode: courseCode,
      subject: subject,
    );
  }

  @override
  Future<void> deleteAllDecks() async {
    await _appDatabase.deleteAllDeckEntries();
  }

  @override
  Future<List<FlashcardModel>> searchCards(
    String query, {
    String? deckId,
  }) async {
    final entries = await _appDatabase.searchCardsFts(query, deckId: deckId);
    return entries.map(_cardFromEntry).toList();
  }

  // --- Drift Entry Mappers ---

  DeckModel _deckFromEntry(
    DeckEntry entry, [
    List<FlashcardModel> cards = const [],
  ]) {
    return DeckModel(
      id: entry.id,
      title: entry.title,
      subject: entry.subject,
      category: entry.category,
      totalCards: entry.totalCards,
      dueCards: entry.dueCards,
      masteryRate: entry.masteryRate,
      description: entry.description,
      lastStudied: entry.lastStudied,
      cards: cards,
      colorHex: entry.colorHex,
      iconName: entry.iconName,
      courseId: entry.courseId,
      courseCode: entry.courseCode,
    );
  }

  FlashcardModel _cardFromEntry(FlashcardEntry entry) {
    return FlashcardModel(
      id: entry.id,
      deckId: entry.deckId,
      front: entry.front,
      back: entry.back,
      frontLatex: entry.frontLatex,
      backLatex: entry.backLatex,
      imageUrl: entry.imageUrl,
      interval: entry.interval,
      repetitions: entry.repetitions,
      easeFactor: entry.easeFactor,
      lastReviewed: entry.lastReviewed,
      nextDueDate: entry.nextDueDate,
      sourceTopic: entry.sourceTopic,
    );
  }

  DecksCompanion _deckToCompanion(DeckModel deck) {
    final now = DateTime.now();
    return DecksCompanion(
      id: Value(deck.id),
      title: Value(deck.title),
      subject: Value(deck.subject),
      category: Value(deck.category),
      totalCards: Value(deck.totalCards),
      dueCards: Value(deck.dueCards),
      masteryRate: Value(deck.masteryRate),
      description: Value(deck.description),
      lastStudied: Value(deck.lastStudied),
      colorHex: Value(deck.colorHex),
      iconName: Value(deck.iconName),
      courseId: Value(deck.courseId),
      courseCode: Value(deck.courseCode),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  FlashcardsCompanion _cardToCompanion(
    FlashcardModel card, [
    String? fallbackDeckId,
  ]) {
    final deckId =
        card.deckId.isNotEmpty ? card.deckId : (fallbackDeckId ?? '');
    final now = DateTime.now();
    return FlashcardsCompanion(
      id: Value(card.id),
      deckId: Value(deckId),
      front: Value(card.front),
      back: Value(card.back),
      frontLatex: Value(card.frontLatex),
      backLatex: Value(card.backLatex),
      imageUrl: Value(card.imageUrl),
      interval: Value(card.interval),
      repetitions: Value(card.repetitions),
      easeFactor: Value(card.easeFactor),
      lastReviewed: Value(card.lastReviewed),
      nextDueDate: Value(card.nextDueDate),
      sourceTopic: Value(card.sourceTopic),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }
}
