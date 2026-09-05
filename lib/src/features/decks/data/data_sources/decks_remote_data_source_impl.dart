import 'dart:async';
import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
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
    LocalStorageService? storageService,
  })  : _userStorage = userStorage,
        _storageService = storageService;

  final DecksApiClient _client;
  final Sm2AlgorithmEngine sm2Engine;
  final UserStorageService? _userStorage;
  final LocalStorageService? _storageService;

  final Map<String, List<FlashcardModel>> _localDeckCards = {};
  final List<DeckModel> _localCreatedDecks = [];

  LocalStorageService? get _localStorage {
    if (_storageService != null) return _storageService;
    try {
      return locator<LocalStorageService>();
    } on Object catch (_) {
      return null;
    }
  }

  CrashlyticsService? get _crashlyticsService {
    try {
      return locator<CrashlyticsService>();
    } on Object catch (_) {
      return null;
    }
  }

  void _loadPersistedDecksIntoMemory() {
    try {
      final raw = _localStorage?.getPreference(key: PrefKeys.persistedUserDecks);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final loaded = list
            .map((e) => DeckModel.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final deck in loaded) {
          final idx = _localCreatedDecks.indexWhere((d) => d.id == deck.id);
          if (idx < 0) {
            _localCreatedDecks.add(deck);
          }
        }
      }
    } on Object catch (_) {}
  }

  Future<void> _persistDecksToStorage() async {
    try {
      final jsonStr = jsonEncode(_localCreatedDecks.map((d) => d.toJson()).toList());
      await _localStorage?.savePreference(
        key: PrefKeys.persistedUserDecks,
        data: jsonStr,
      );
    } on Object catch (_) {}
  }

  @override
  Future<void> saveGeneratedDeck({
    required DeckModel deck,
    required List<FlashcardModel> cards,
  }) async {
    // 1. Instant local memory persistence
    _localDeckCards[deck.id] = cards;
    _localCreatedDecks
      ..removeWhere((d) => d.id == deck.id)
      ..insert(0, deck.copyWith(cards: cards));

    // 2. Resilient local disk persistence (Hive) across app restarts
    unawaited(_persistDecksToStorage());
    try {
      final cardsJsonStr = jsonEncode(cards.map((c) => c.toJson()).toList());
      unawaited(
        _localStorage?.savePreference(
          key: '${PrefKeys.persistedDeckCardsPrefix}${deck.id}',
          data: cardsJsonStr,
        ),
      );
    } on Object catch (_) {}

    // 3. Seamless Supabase Database Persistence
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
    _loadPersistedDecksIntoMemory();

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

    // 1. Check local persistent storage first
    try {
      final raw = _localStorage?.getPreference(
        key: '${PrefKeys.persistedDeckCardsPrefix}$deckId',
      );
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final loaded = list
            .map((e) => FlashcardModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (loaded.isNotEmpty) {
          _localDeckCards[deckId] = loaded;
          return loaded;
        }
      }
    } on Object catch (_) {}

    // 2. Fetch from remote if not cached locally
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
    // 1. Execute local SM-2 algorithm immediately for 0ms UI latency
    final localResult = sm2Engine.calculate(
      quality: quality,
      previousRepetitions: previousRepetitions,
      previousInterval: previousInterval,
      previousEaseFactor: previousEaseFactor,
    );

    // 2. Sync to Supabase RPC process_card_sm2_review with correct parameter names
    try {
      await _client.processCardReview(cardId, {
        'p_card_id': cardId,
        'p_quality': quality,
        'p_interval': localResult.nextInterval,
        'p_repetitions': localResult.newRepetitions,
        'p_ease_factor': localResult.newEaseFactor,
        'p_next_due_date': localResult.nextDueDate.toIso8601String(),
      });
    } on Object catch (_) {
      // Offline/Local continues gracefully
    }

    return localResult;
  }

  @override
  Future<void> saveSessionResults({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    double? masteryRate,
    int? dueCards,
  }) async {
    final cards = _localDeckCards[deckId] ?? const <FlashcardModel>[];
    final masteredCount = cards.where((c) => c.repetitions >= 1).length;
    final totalCount = cards.isNotEmpty ? cards.length : cardsReviewed;
    final calculatedMasteryRate = masteryRate ??
        (totalCount > 0
            ? (masteredCount > 0
                    ? masteredCount / totalCount
                    : (retentionScore > 0 ? retentionScore : 1.0))
                .clamp(0.0, 1.0)
            : 1.0);
    final calculatedDueCards =
        dueCards ?? cards.where((c) => c.isDueToday).length;
    final now = DateTime.now();

    // 1. Instant local state update
    final deckIdx = _localCreatedDecks.indexWhere((d) => d.id == deckId);
    if (deckIdx >= 0) {
      final old = _localCreatedDecks[deckIdx];
      _localCreatedDecks[deckIdx] = old.copyWith(
        masteryRate: calculatedMasteryRate,
        dueCards: calculatedDueCards,
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
          dueCards: calculatedDueCards,
          masteryRate: calculatedMasteryRate,
          lastStudied: now,
        ),
      );
    }
    unawaited(_persistDecksToStorage());

    // 2. Sync to Supabase RPC record_study_session with correct parameter names
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

    // 3. Persist updated deck mastery and due status to Supabase decks table
    try {
      await _client.updateDeckRecord(deckId, {
        'mastery_rate': calculatedMasteryRate,
        'due_cards': calculatedDueCards,
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
    unawaited(_persistDecksToStorage());
    unawaited(
      _localStorage?.deletePreference(
        key: '${PrefKeys.persistedDeckCardsPrefix}$deckId',
      ),
    );

    try {
      await _client.deleteDeck(deckId);
    } on Object catch (_) {
      // Offline/Local deletion continues smoothly
    }
  }

  @override
  Future<void> deleteDecksForCourse(
    String courseId, {
    String? courseCode,
    String? subject,
  }) async {
    final toDelete = _localCreatedDecks.where((d) {
      if (d.courseId != null && d.courseId == courseId) return true;
      if (courseCode != null &&
          d.courseCode != null &&
          d.courseCode!.toLowerCase() == courseCode.toLowerCase()) {
        return true;
      }
      if (subject != null &&
          d.subject.toLowerCase() == subject.toLowerCase()) {
        return true;
      }
      return false;
    }).toList();

    for (final deck in toDelete) {
      await deleteDeck(deck.id);
    }
  }

  @override
  Future<void> linkDeckToCourse({
    required String deckId,
    required String courseId,
    String? courseCode,
    String? subject,
  }) async {
    final index = _localCreatedDecks.indexWhere((d) => d.id == deckId);
    if (index != -1) {
      final old = _localCreatedDecks[index];
      _localCreatedDecks[index] = old.copyWith(
        courseId: courseId,
        courseCode: courseCode ?? old.courseCode,
        subject: subject ?? old.subject,
      );
      unawaited(_persistDecksToStorage());
    }

    try {
      await _client.updateDeckRecord(deckId, {
        'course_id': courseId,
        'course_code': ?courseCode,
      });
    } on Object catch (_) {}
  }

  @override
  Future<void> deleteAllDecks() async {
    final allIds = _localCreatedDecks.map((d) => d.id).toList();
    _localDeckCards.clear();
    _localCreatedDecks.clear();
    unawaited(_persistDecksToStorage());

    for (final id in allIds) {
      unawaited(
        _localStorage?.deletePreference(
          key: '${PrefKeys.persistedDeckCardsPrefix}$id',
        ),
      );
      try {
        await _client.deleteDeck(id);
      } on Object catch (_) {}
    }
  }
}
