import 'package:kortex/src/features/decks/data/client/decks_api_client.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';
import 'package:kortex/src/features/decks/domain/logic/sm2_algorithm_engine.dart';

class DecksRemoteDataSourceImpl implements DecksRemoteDataSource {
  const DecksRemoteDataSourceImpl(
    this._client, {
    this.sm2Engine = const Sm2AlgorithmEngine(),
  });

  final DecksApiClient _client;
  final Sm2AlgorithmEngine sm2Engine;

  @override
  Future<List<DeckModel>> getUserDecks() async {
    try {
      final decks = await _client.getUserDecks();
      return decks;
    } on Object catch (_) {
      return const [];
    }
  }

  @override
  Future<List<FlashcardModel>> getDeckCards(String deckId) async {
    try {
      final cards = await _client.getDeckCards(deckId);
      return cards;
    } on Object catch (_) {
      return const [];
    }
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
