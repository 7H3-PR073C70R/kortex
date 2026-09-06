import 'dart:async';

import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source.dart';
import 'package:kortex/src/features/decks/data/database/decks_database_service.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';

class DecksLocalDataSourceImpl implements DecksLocalDataSource {
  DecksLocalDataSourceImpl(this._databaseService);

  final DecksDatabaseService _databaseService;

  @override
  Future<List<DeckModel>> getDecks() async {
    final rows = await _databaseService.queryDecks();
    return rows.map(_deckFromRow).toList();
  }

  @override
  Future<DeckModel?> getDeck(String id) async {
    final row = await _databaseService.queryDeck(id);
    if (row == null) return null;
    final cards = await getCardsForDeck(id);
    return _deckFromRow(row, cards);
  }

  @override
  Future<List<FlashcardModel>> getCardsForDeck(String deckId) async {
    final rows = await _databaseService.queryCardsForDeck(deckId);
    return rows.map(_cardFromRow).toList();
  }

  @override
  Future<List<FlashcardModel>> getDueCards({
    String? deckId,
    DateTime? beforeDate,
  }) async {
    final rows = await _databaseService.queryDueCards(
      deckId: deckId,
      beforeDate: beforeDate,
    );
    return rows.map(_cardFromRow).toList();
  }

  @override
  Future<void> saveDeck(DeckModel deck, {List<FlashcardModel>? cards}) async {
    final cardsToSave = cards ?? deck.cards;
    if (cardsToSave.isNotEmpty) {
      final deckMap = _deckToRow(deck);
      final cardsMap = cardsToSave.map((c) => _cardToRow(c, deck.id)).toList();
      await _databaseService.batchUpsertDeckAndCards(deckMap, cardsMap);
    } else {
      await _databaseService.upsertDeck(_deckToRow(deck));
    }
  }

  @override
  Future<void> saveCards(String deckId, List<FlashcardModel> cards) async {
    final cardsMap = cards.map((c) => _cardToRow(c, deckId)).toList();
    await _databaseService.batchUpsertCards(cardsMap);
  }

  @override
  Future<void> updateCard(FlashcardModel card) async {
    await _databaseService.upsertCard(_cardToRow(card));
  }

  @override
  Future<void> batchUpdateCards(List<FlashcardModel> cards) async {
    final cardsMap = cards.map(_cardToRow).toList();
    await _databaseService.batchUpsertCards(cardsMap);
  }

  @override
  Future<void> updateDeckStats({
    required String deckId,
    double? masteryRate,
    int? dueCards,
    DateTime? lastStudied,
  }) async {
    final updates = <String, dynamic>{
      'mastery_rate': ?masteryRate,
      'due_cards': ?dueCards,
      'last_studied': ?lastStudied?.toIso8601String(),
    };
    if (updates.isNotEmpty) {
      await _databaseService.updateDeckMetadata(deckId, updates);
    }
  }

  @override
  Future<void> linkDeckToCourse({
    required String deckId,
    required String courseId,
    String? courseCode,
    String? subject,
  }) async {
    final updates = <String, dynamic>{
      'course_id': courseId,
      'course_code': ?courseCode,
      'subject': ?subject,
    };
    await _databaseService.updateDeckMetadata(deckId, updates);
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    await _databaseService.deleteDeck(deckId);
  }

  @override
  Future<void> deleteDecksForCourse(
    String courseId, {
    String? courseCode,
    String? subject,
  }) async {
    await _databaseService.deleteDecksForCourse(
      courseId,
      courseCode: courseCode,
      subject: subject,
    );
  }

  @override
  Future<void> deleteAllDecks() async {
    await _databaseService.deleteAllDecks();
  }

  // --- Row Mappers ---

  DeckModel _deckFromRow(Map<String, dynamic> row, [List<FlashcardModel> cards = const []]) {
    return DeckModel(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Untitled Deck',
      subject: row['subject'] as String? ?? 'General',
      category: row['category'] as String? ?? 'General',
      totalCards: (row['total_cards'] as num?)?.toInt() ?? cards.length,
      dueCards: (row['due_cards'] as num?)?.toInt() ?? 0,
      masteryRate: (row['mastery_rate'] as num?)?.toDouble() ?? 0.0,
      description: row['description'] as String?,
      lastStudied: row['last_studied'] != null
          ? DateTime.tryParse(row['last_studied'] as String)
          : null,
      cards: cards,
      colorHex: row['color_hex'] as String?,
      iconName: row['icon_name'] as String?,
      courseId: row['course_id'] as String?,
      courseCode: row['course_code'] as String?,
    );
  }

  Map<String, dynamic> _deckToRow(DeckModel deck) {
    return {
      'id': deck.id,
      'title': deck.title,
      'subject': deck.subject,
      'category': deck.category,
      'total_cards': deck.totalCards,
      'due_cards': deck.dueCards,
      'mastery_rate': deck.masteryRate,
      'description': deck.description,
      'last_studied': deck.lastStudied?.toIso8601String(),
      'color_hex': deck.colorHex,
      'icon_name': deck.iconName,
      'course_id': deck.courseId,
      'course_code': deck.courseCode,
    };
  }

  FlashcardModel _cardFromRow(Map<String, dynamic> row) {
    return FlashcardModel(
      id: row['id'] as String,
      deckId: row['deck_id'] as String? ?? '',
      front: row['front'] as String? ?? '',
      back: row['back'] as String? ?? '',
      frontLatex: row['front_latex'] as String?,
      backLatex: row['back_latex'] as String?,
      imageUrl: row['image_url'] as String?,
      interval: (row['interval'] as num?)?.toInt() ?? 1,
      repetitions: (row['repetitions'] as num?)?.toInt() ?? 0,
      easeFactor: (row['ease_factor'] as num?)?.toDouble() ?? 2.5,
      lastReviewed: row['last_reviewed'] != null
          ? DateTime.tryParse(row['last_reviewed'] as String)
          : null,
      nextDueDate: row['next_due_date'] != null
          ? DateTime.tryParse(row['next_due_date'] as String)
          : null,
      sourceTopic: row['source_topic'] as String?,
    );
  }

  Map<String, dynamic> _cardToRow(FlashcardModel card, [String? fallbackDeckId]) {
    final deckId = card.deckId.isNotEmpty ? card.deckId : (fallbackDeckId ?? '');
    return {
      'id': card.id,
      'deck_id': deckId,
      'front': card.front,
      'back': card.back,
      'front_latex': card.frontLatex,
      'back_latex': card.backLatex,
      'image_url': card.imageUrl,
      'interval': card.interval,
      'repetitions': card.repetitions,
      'ease_factor': card.easeFactor,
      'last_reviewed': card.lastReviewed?.toIso8601String(),
      'next_due_date': card.nextDueDate?.toIso8601String(),
      'source_topic': card.sourceTopic,
    };
  }
}
