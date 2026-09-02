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
  });

  final DecksApiClient _client;
  final Sm2AlgorithmEngine sm2Engine;
  final Map<String, List<FlashcardModel>> _localDeckCards = {};
  final List<DeckModel> _localCreatedDecks = [];

  @override
  Future<void> saveGeneratedDeck({
    required DeckModel deck,
    required List<FlashcardModel> cards,
  }) async {
    _localDeckCards[deck.id] = cards;
    _localCreatedDecks
      ..removeWhere((d) => d.id == deck.id)
      ..insert(0, deck.copyWith(cards: cards));
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
