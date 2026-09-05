import 'dart:async';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
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

  CrashlyticsService? get _crashlyticsService {
    try {
      return locator<CrashlyticsService>();
    } on Object catch (_) {
      return null;
    }
  }

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

    final actualDueCount = cards.where((c) => c.isDueToday).length;

    // Insert Deck Record
    try {
      final deckPayload = <String, dynamic>{
        'id': deck.id,
        'title': deck.title,
        'subject': deck.subject,
        'total_cards': cards.length,
        'due_cards': actualDueCount,
        'mastery_rate': deck.masteryRate,
        'description': deck.description,
        if (userId.isNotEmpty) 'user_id': userId,
      };
      await _client.createDeckRecord(deckPayload);
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason:
                'DecksRemoteDataSource.createDeckRecord failed, proceeding offline',
          ),
        );
      }
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
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason:
                'DecksRemoteDataSource.bulkInsertCards failed, proceeding offline',
          ),
        );
      }
    }
  }

  @override
  Future<List<DeckModel>> getUserDecks() async {
    try {
      final remoteDecks = await _client.getUserDecks();
      final remoteIds = remoteDecks.map((d) => d.id).toSet();
      final updatedRemote = remoteDecks.map((remote) {
        final localMatch =
            _localCreatedDecks.where((d) => d.id == remote.id).firstOrNull;
        if (localMatch != null && localMatch.masteryRate > remote.masteryRate) {
          return remote.copyWith(
            masteryRate: localMatch.masteryRate,
            dueCards: localMatch.dueCards,
            lastStudied: localMatch.lastStudied,
          );
        }
        return remote;
      }).toList();

      final merged = [
        ..._localCreatedDecks.where((d) => !remoteIds.contains(d.id)),
        ...updatedRemote,
      ];
      return merged;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason:
                'DecksRemoteDataSource.getUserDecks failed, returning local cache',
          ),
        );
      }
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
        _localDeckCards[deckId] = cards;
        return cards;
      }
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'DecksRemoteDataSource.getDeckCards failed',
          ),
        );
      }
    }
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
    // Run SM-2 calculation locally for zero-latency instant card swiping
    final localResult = sm2Engine.calculate(
      quality: quality,
      previousInterval: previousInterval,
      previousRepetitions: previousRepetitions,
      previousEaseFactor: previousEaseFactor,
    );

    // Update in-memory cached card state immediately
    for (final deckCards in _localDeckCards.values) {
      final idx = deckCards.indexWhere((c) => c.id == cardId);
      if (idx != -1) {
        deckCards[idx] = deckCards[idx].copyWith(
          interval: localResult.nextInterval,
          repetitions: localResult.newRepetitions,
          easeFactor: localResult.newEaseFactor,
          nextDueDate: localResult.nextDueDate,
        );
        break;
      }
    }

    // Fire-and-forget sync to backend
    try {
      unawaited(
        _client.processCardReview(cardId, {
          'p_card_id': cardId,
          'p_quality': quality,
        }),
      );
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'DecksRemoteDataSource.processCardReview sync failed',
          ),
        );
      }
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
    // 1. Calculate local deck mastery rate and due cards
    final cards = _localDeckCards[deckId] ?? const <FlashcardModel>[];
    final masteredCount = cards.where((c) => c.repetitions >= 1).length;
    final totalCount = cards.isNotEmpty ? cards.length : cardsReviewed;
    final masteryRate = totalCount > 0
        ? (masteredCount > 0 ? masteredCount / totalCount : (retentionScore > 0 ? retentionScore : 1.0)).clamp(0.0, 1.0)
        : 1.0;
    final dueCards = cards.where((c) => c.isDueToday).length;
    final now = DateTime.now();

    // 2. Update local deck cache
    final localIdx = _localCreatedDecks.indexWhere((d) => d.id == deckId);
    if (localIdx != -1) {
      _localCreatedDecks[localIdx] = _localCreatedDecks[localIdx].copyWith(
        masteryRate: masteryRate,
        dueCards: dueCards,
        lastStudied: now,
      );
    } else {
      _localCreatedDecks.add(
        DeckModel(
          id: deckId,
          title: 'Study Deck',
          subject: 'General',
          category: 'General',
          totalCards: totalCount,
          dueCards: dueCards,
          masteryRate: masteryRate,
          lastStudied: now,
        ),
      );
    }

    // 3. Sync to Supabase RPC record_study_session with correct parameter names
    try {
      await _client.saveSessionResults({
        'p_deck_id': deckId,
        'p_cards_reviewed': cardsReviewed,
        'p_duration_seconds': durationSeconds,
        'p_retention_score': retentionScore,
      });
    } on Object catch (_) {
      // Offline/Local continues gracefully
    }

    // 4. Persist updated deck mastery and due status to Supabase decks table
    try {
      await _client.updateDeckRecord(deckId, {
        'mastery_rate': masteryRate,
        'due_cards': dueCards,
        'last_studied': now.toIso8601String(),
      });
    } on Object catch (_) {
      // Offline/Local continues gracefully
    }
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    _localDeckCards.remove(deckId);
    _localCreatedDecks.removeWhere((d) => d.id == deckId);

    try {
      await _client.deleteDeck(deckId);
    } on Object catch (_) {
      // Offline/Local deletion continues smoothly
    }
  }
}
