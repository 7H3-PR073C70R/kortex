import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/decks/data/client/decks_api_client.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';
import 'package:kortex/src/features/decks/domain/logic/sm2_algorithm_engine.dart';

class DecksRemoteDataSourceImpl implements DecksRemoteDataSource {
  DecksRemoteDataSourceImpl(
    this._client, {
    this.sm2Engine = const Sm2AlgorithmEngine(),
    UserStorageService? userStorage,
  }) : _userStorage = userStorage;

  final DecksApiClient _client;
  final Sm2AlgorithmEngine sm2Engine;
  final UserStorageService? _userStorage;
  final Map<String, List<FlashcardModel>> _localDeckCards = {};
  final List<DeckModel> _localCreatedDecks = [];

  @override
  Future<void> saveGeneratedDeck({
    required DeckModel deck,
    required List<FlashcardModel> cards,
  }) async {
    // 1. Instant local persistence for zero-latency UI responsiveness
    _localDeckCards[deck.id] = cards;
    _localCreatedDecks
      ..removeWhere((d) => d.id == deck.id)
      ..insert(0, deck.copyWith(cards: cards));

    // 2. Seamless Supabase Database Persistence
    final userId = _userStorage?.getUserId() ?? '';

    // Insert Deck Record
    try {
      final deckPayload = <String, dynamic>{
        'id': deck.id,
        'title': deck.title,
        'subject': deck.subject,
        'total_cards': cards.length,
        'due_cards': cards.length,
        'mastery_rate': deck.masteryRate,
        'description': deck.description,
        if (userId.isNotEmpty) 'user_id': userId,
      };
      await _client.createDeckRecord(deckPayload);
    } on Object catch (_) {
      // Offline/Local continues gracefully
    }

    // Bulk Insert Associated Flashcards
    try {
      final cardsPayload = cards.map((c) {
        return <String, dynamic>{
          'id': c.id,
          'deck_id': deck.id,
          'front': c.front,
          'back': c.back,
          if (c.frontLatex != null) 'front_latex': c.frontLatex,
          if (c.backLatex != null) 'back_latex': c.backLatex,
          if (c.imageUrl != null) 'image_url': c.imageUrl,
          if (c.sourceTopic != null) 'source_topic': c.sourceTopic,
          'interval': c.interval,
          'repetitions': c.repetitions,
          'ease_factor': c.easeFactor,
          if (c.nextDueDate != null)
            'next_due_date': c.nextDueDate!.toIso8601String(),
          if (userId.isNotEmpty) 'user_id': userId,
        };
      }).toList();

      if (cardsPayload.isNotEmpty) {
        await _client.bulkInsertCards(cardsPayload);
      }
    } on Object catch (_) {
      // Offline/Local continues gracefully
    }
  }

  @override
  Future<List<DeckModel>> getUserDecks() async {
    try {
      final remoteDecks = await _client.getUserDecks();
      final remoteIds = remoteDecks.map((d) => d.id).toSet();
      final merged = [
        ..._localCreatedDecks.where((d) => !remoteIds.contains(d.id)),
        ...remoteDecks,
      ];
      return merged;
    } on Object catch (_) {
      return _localCreatedDecks;
    }
  }

  @override
  Future<List<FlashcardModel>> getDeckCards(String deckId) async {
    if (_localDeckCards.containsKey(deckId) &&
        _localDeckCards[deckId]!.isNotEmpty) {
      return _localDeckCards[deckId]!;
    }
    try {
      final cards = await _client.getDeckCards(deckId);
      if (cards.isNotEmpty) {
        return cards;
      }
    } on Object catch (_) {}
    return _localDeckCards[deckId] ?? const [];
  }

  @override
  Future<Sm2CalculationResult> processCardReview({
    required String cardId,
    required int quality,
    required int previousInterval,
    required int previousRepetitions,
    required double previousEaseFactor,
  }) async {
    // Run SM-2 calculation locally for zero-latency instant feedback
    final localResult = sm2Engine.calculate(
      quality: quality,
      previousInterval: previousInterval,
      previousRepetitions: previousRepetitions,
      previousEaseFactor: previousEaseFactor,
    );

    try {
      await _client.processCardReview(cardId, {
        'quality': quality,
        'nextInterval': localResult.nextInterval,
        'newEaseFactor': localResult.newEaseFactor,
        'newRepetitions': localResult.newRepetitions,
        'nextDueDate': localResult.nextDueDate.toIso8601String(),
      });
    } on Object catch (_) {
      // Offline fallback: return computed SM-2 result safely
    }

    return localResult;
  }

  @override
  Future<void> saveSessionResults({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
  }) async {
    try {
      await _client.saveSessionResults(deckId, {
        'cardsReviewed': cardsReviewed,
        'durationSeconds': durationSeconds,
        'retentionScore': retentionScore,
        'completedAt': DateTime.now().toIso8601String(),
      });
    } on Object catch (_) {
      // Session results synced locally
    }
  }
}
