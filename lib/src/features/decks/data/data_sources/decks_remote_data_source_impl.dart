import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/decks/data/client/decks_api_client.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/services/past_question_deck_factory.dart';

class DecksRemoteDataSourceImpl implements DecksRemoteDataSource {
  DecksRemoteDataSourceImpl(
    this._client, {
    UserStorageService? userStorage,
    LocalStorageService? storageService,
    DecksLocalDataSource? localDataSource,
  })  : _userStorage = userStorage,
        _storageService = storageService,
        _localDataSourceOverride = localDataSource;

  final DecksApiClient _client;
  final UserStorageService? _userStorage;
  final LocalStorageService? _storageService;
  final DecksLocalDataSource? _localDataSourceOverride;

  final Map<String, List<FlashcardModel>> _localDeckCards = {};
  final List<DeckModel> _localCreatedDecks = [];

  DecksLocalDataSource? get _localDataSource {
    if (_localDataSourceOverride != null) return _localDataSourceOverride;
    try {
      return locator<DecksLocalDataSource>();
    } on Object catch (_) {
      return null;
    }
  }

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

  PastQuestionDeckFactory? get _pastQuestionDeckFactory {
    try {
      if (locator.isRegistered<PastQuestionDeckFactory>()) {
        return locator<PastQuestionDeckFactory>();
      }
    } on Object catch (_) {}
    return null;
  }

  List<CuratedCourseModel> _getRegisteredCourses() {
    try {
      final raw = _localStorage?.getPreference(key: PrefKeys.userCuratedCourses);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map(CuratedCourseModel.fromJson)
            .toList();
      }
    } on Object catch (_) {}
    return const [];
  }

  String? _getUserTrack() {
    try {
      if (locator.isRegistered<AuthBloc>()) {
        return locator<AuthBloc>().state.userProfile?.targetTrack;
      }
    } on Object catch (_) {}
    return null;
  }

  Future<void> _loadPersistedDecksIntoMemory() async {
    // 1. Primary: load from local relational database (SQLite)
    if (_localDataSource != null) {
      try {
        final localDecks = await _localDataSource!.getDecks();
        for (final deck in localDecks) {
          final idx = _localCreatedDecks.indexWhere((d) => d.id == deck.id);
          if (idx < 0) {
            _localCreatedDecks.add(deck);
          } else {
            _localCreatedDecks[idx] = deck;
          }
        }
        if (_localCreatedDecks.isNotEmpty) return;
      } on Object catch (_) {}
    }

    // 2. Fallback: Legacy Hive / SharedPreferences loader for unmigrated sessions
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
          } else {
            _localCreatedDecks[idx] = deck;
          }
          if (deck.cards.isNotEmpty) {
            _localDeckCards[deck.id] = deck.cards;
          }
        }
      }
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

    // 2. Resilient local relational persistence (SQLite)
    unawaited(_localDataSource?.saveDeck(deck, cards: cards));

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
        if (deck.courseId != null) 'course_id': deck.courseId,
        if (deck.courseCode != null) 'course_code': deck.courseCode,
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
    await _loadPersistedDecksIntoMemory();

    final token = _userStorage?.getToken();
    if (_userStorage != null && (token == null || token.trim().isEmpty)) {
      // User is unauthenticated: return local created decks & canonical course decks immediately without network call
      final fallbackList = <DeckModel>[..._localCreatedDecks];
      try {
        final track = _getUserTrack();
        final factory = _pastQuestionDeckFactory;
        if (factory != null && factory.isSecondaryTrack(track)) {
          final registeredCourses = _getRegisteredCourses();
          if (registeredCourses.isNotEmpty) {
            final canonicalDecks =
                await factory.generateCanonicalDecksForCourses(
              courses: registeredCourses,
              track: track,
            );
            for (final cd in canonicalDecks) {
              if (!fallbackList.any((d) => d.id == cd.id)) {
                fallbackList.add(cd);
              }
            }
          }
        }
      } on Object catch (_) {}

      return fallbackList;
    }

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

      final resultList = <DeckModel>[...merged];

      // Merge canonical 2-year past questions study decks for registered courses in WAEC, JAMB, or NECO
      try {
        final track = _getUserTrack();
        final factory = _pastQuestionDeckFactory;
        if (factory != null && factory.isSecondaryTrack(track)) {
          final registeredCourses = _getRegisteredCourses();
          if (registeredCourses.isNotEmpty) {
            final canonicalDecks =
                await factory.generateCanonicalDecksForCourses(
              courses: registeredCourses,
              track: track,
            );
            for (final cd in canonicalDecks) {
              if (!resultList.any((d) => d.id == cd.id)) {
                resultList.add(cd);
              }
            }
          }
        }
      } on Object catch (_) {}

      return resultList;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        final isAuthOrNotFound = e is DioException &&
            (e.response?.statusCode == 401 ||
                e.response?.statusCode == 403 ||
                e.response?.statusCode == 404);
        if (!isAuthOrNotFound) {
          unawaited(
            _crashlyticsService!.recordError(
              e,
              stack,
              reason:
                  'DecksRemoteDataSource.getUserDecks failed, returning local cache',
            ),
          );
        }
      }

      final fallbackList = <DeckModel>[..._localCreatedDecks];
      try {
        final track = _getUserTrack();
        final factory = _pastQuestionDeckFactory;
        if (factory != null && factory.isSecondaryTrack(track)) {
          final registeredCourses = _getRegisteredCourses();
          if (registeredCourses.isNotEmpty) {
            final canonicalDecks =
                await factory.generateCanonicalDecksForCourses(
              courses: registeredCourses,
              track: track,
            );
            for (final cd in canonicalDecks) {
              if (!fallbackList.any((d) => d.id == cd.id)) {
                fallbackList.add(cd);
              }
            }
          }
        }
      } on Object catch (_) {}

      return fallbackList;
    }
  }

  @override
  Future<List<FlashcardModel>> getDeckCards(String deckId) async {
    if (_localDeckCards.containsKey(deckId) &&
        _localDeckCards[deckId]!.isNotEmpty) {
      return _localDeckCards[deckId]!;
    }

    // Check if this is a canonical past questions study deck
    if (deckId.startsWith(PastQuestionDeckFactory.canonicalPrefix)) {
      final factory = _pastQuestionDeckFactory;
      if (factory != null) {
        final cards = await factory.generateCardsForCanonicalDeck(deckId);
        if (cards.isNotEmpty) {
          _localDeckCards[deckId] = cards;
          return cards;
        }
      }
    }

    // 0. Check in-memory created decks
    final inMemoryDeck =
        _localCreatedDecks.where((d) => d.id == deckId).firstOrNull;
    if (inMemoryDeck != null && inMemoryDeck.cards.isNotEmpty) {
      _localDeckCards[deckId] = inMemoryDeck.cards;
      return inMemoryDeck.cards;
    }

    // 1. Check local relational database (SQLite)
    if (_localDataSource != null) {
      try {
        final localCards = await _localDataSource!.getCardsForDeck(deckId);
        if (localCards.isNotEmpty) {
          _localDeckCards[deckId] = localCards;
          return localCards;
        }
      } on Object catch (_) {}
    }

    // 2. Check legacy persistent storage
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
          unawaited(_localDataSource?.saveCards(deckId, loaded));
          return loaded;
        }
      }
    } on Object catch (_) {}

    // 3. Fetch from remote if not cached locally and user is authenticated
    final token = _userStorage?.getToken();
    if (_userStorage == null || (token != null && token.trim().isNotEmpty)) {
      try {
        final cards = await _client.getDeckCards(deckId);
        if (cards.isNotEmpty) {
          _localDeckCards[deckId] = cards;
          unawaited(_localDataSource?.saveCards(deckId, cards));
          return cards;
        }
      } on Object catch (e, stack) {
        if (_crashlyticsService != null) {
          final isAuthOrNotFound = e is DioException &&
              (e.response?.statusCode == 401 ||
                  e.response?.statusCode == 403 ||
                  e.response?.statusCode == 404);
          if (!isAuthOrNotFound) {
            unawaited(
              _crashlyticsService!.recordError(
                e,
                stack,
                reason: 'DecksRemoteDataSource.getDeckCards failed',
              ),
            );
          }
        }
      }
    }
    return _localDeckCards[deckId] ?? const [];
  }

  @override
  Future<void> updateDeckCards(String deckId, List<FlashcardModel> cards) async {
    _localDeckCards[deckId] = cards;

    final dueCount = cards.where((c) => c.isDueToday).length;
    final masteredCount = cards.where((c) => c.repetitions >= 1).length;
    final calculatedMasteryRate =
        cards.isNotEmpty ? (masteredCount / cards.length) : 0.0;

    final deckIdx = _localCreatedDecks.indexWhere((d) => d.id == deckId);
    if (deckIdx >= 0) {
      final old = _localCreatedDecks[deckIdx];
      _localCreatedDecks[deckIdx] = old.copyWith(
        cards: cards,
        dueCards: dueCount,
        masteryRate: calculatedMasteryRate > old.masteryRate
            ? calculatedMasteryRate
            : old.masteryRate,
      );
    }

    // Direct, targeted update in SQLite: only cards for this deck updated
    unawaited(_localDataSource?.saveCards(deckId, cards));
    unawaited(
      _localDataSource?.updateDeckStats(
        deckId: deckId,
        masteryRate: calculatedMasteryRate,
        dueCards: dueCount,
      ),
    );
  }

  @override
  Future<void> saveSessionResults({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    double? masteryRate,
    int? dueCards,
    List<FlashcardModel>? updatedCards,
  }) async {
    // 1. Direct targeted SQLite update of reviewed flashcards (no monolithic re-serialization)
    if (updatedCards != null && updatedCards.isNotEmpty) {
      _localDeckCards[deckId] = updatedCards;
      unawaited(_localDataSource?.batchUpdateCards(updatedCards));
    }

    final cards =
        _localDeckCards[deckId] ?? updatedCards ?? const <FlashcardModel>[];
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

    // 2. Instant local in-memory state update
    final deckIdx = _localCreatedDecks.indexWhere((d) => d.id == deckId);
    if (deckIdx >= 0) {
      final old = _localCreatedDecks[deckIdx];
      _localCreatedDecks[deckIdx] = old.copyWith(
        masteryRate: calculatedMasteryRate,
        dueCards: calculatedDueCards,
        lastStudied: now,
        cards: cards.isNotEmpty ? cards : old.cards,
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
          cards: cards,
        ),
      );
    }

    // 3. Fast targeted SQLite update for deck stats
    unawaited(
      _localDataSource?.updateDeckStats(
        deckId: deckId,
        masteryRate: calculatedMasteryRate,
        dueCards: calculatedDueCards,
        lastStudied: now,
      ),
    );

    // 4. Sync to Supabase RPC record_study_session with correct parameter names
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

    // 5. Persist updated deck mastery and due status to Supabase decks table
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
    unawaited(_localDataSource?.deleteDeck(deckId));

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
      _localDeckCards.remove(deck.id);
      _localCreatedDecks.removeWhere((d) => d.id == deck.id);
      try {
        await _client.deleteDeck(deck.id);
      } on Object catch (_) {}
    }

    await _localDataSource?.deleteDecksForCourse(
      courseId,
      courseCode: courseCode,
      subject: subject,
    );
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
    }

    unawaited(
      _localDataSource?.linkDeckToCourse(
        deckId: deckId,
        courseId: courseId,
        courseCode: courseCode,
        subject: subject,
      ),
    );

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
    unawaited(_localDataSource?.deleteAllDecks());

    for (final id in allIds) {
      try {
        await _client.deleteDeck(id);
      } on Object catch (_) {}
    }
  }
}
