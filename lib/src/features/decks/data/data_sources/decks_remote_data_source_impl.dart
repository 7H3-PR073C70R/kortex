import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/decks/data/client/decks_api_client.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/logic/deck_title_resolver.dart';

class DecksRemoteDataSourceImpl implements DecksRemoteDataSource {
  DecksRemoteDataSourceImpl(
    this._client, {
    UserStorageService? userStorage,
    LocalStorageService? storageService,
    DecksLocalDataSource? localDataSource,
    Connectivity? connectivity,
  }) : _userStorage = userStorage,
       _storageService = storageService,
       _localDataSourceOverride = localDataSource,
       _connectivity = connectivity {
    if (_connectivity != null) {
      _initConnectivityListener();
    }
  }

  final DecksApiClient _client;
  final UserStorageService? _userStorage;
  final LocalStorageService? _storageService;
  final DecksLocalDataSource? _localDataSourceOverride;
  final Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  void _initConnectivityListener() {
    try {
      _connectivitySub = _connectivity?.onConnectivityChanged.listen((results) {
        final isOnline = results.any(
          (c) =>
              c == ConnectivityResult.wifi ||
              c == ConnectivityResult.mobile ||
              c == ConnectivityResult.ethernet,
        );
        if (isOnline) {
          unawaited(getUserDecks());
        }
      });
    } on Object catch (_) {}
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
  }

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

  bool _isValidId(String id) {
    if (id.trim().isEmpty) return false;
    final clean = id.trim();
    if (clean == 'all' || clean == 'all_decks' || clean == 'cross_deck') {
      return false;
    }
    if (clean.contains(':')) return false;
    final validIdRegex = RegExp(r'^[a-zA-Z0-9_\-]+$');
    return validIdRegex.hasMatch(clean);
  }

  bool _isValidUuid(String id) => _isValidId(id);

  static const String _pendingDeckDeletionsKey =
      '__kortex_pending_deck_deletions';

  Set<String> _getPendingDeckDeletions() {
    try {
      final raw = _localStorage?.getPreference(key: _pendingDeckDeletionsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => e.toString()).toSet();
      }
    } on Object catch (_) {}
    return <String>{};
  }

  Future<void> _savePendingDeckDeletions(Set<String> deletions) async {
    try {
      if (deletions.isEmpty) {
        await _localStorage?.deletePreference(key: _pendingDeckDeletionsKey);
      } else {
        await _localStorage?.savePreference(
          key: _pendingDeckDeletionsKey,
          data: jsonEncode(deletions.toList()),
        );
      }
    } on Object catch (_) {}
  }

  void _persistLocalDecksToStorage() {
    try {
      final jsonStr = jsonEncode(
        _localCreatedDecks.map((d) => d.toJson()).toList(),
      );
      unawaited(
        _localStorage?.savePreference(
          key: PrefKeys.persistedUserDecks,
          data: jsonStr,
        ),
      );
    } on Object catch (_) {}
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
      } on Object catch (_) {}
    }

    // 2. Supplement / Fallback: SharedPreferences loader
    try {
      final raw = _localStorage?.getPreference(
        key: PrefKeys.persistedUserDecks,
      );
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
            if (deck.lastStudied != null &&
                (_localCreatedDecks[idx].lastStudied == null ||
                    deck.lastStudied!.isAfter(
                      _localCreatedDecks[idx].lastStudied!,
                    ))) {
              _localCreatedDecks[idx] = deck;
            }
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
    _persistLocalDecksToStorage();

    // 2. Resilient local relational persistence (SQLite)
    unawaited(_localDataSource?.saveDeck(deck, cards: cards));

    // 3. Seamless Supabase Database Persistence
    final userId = _userStorage?.getUserId() ?? '';
    final actualDueCount = cards.where((c) => c.isDueToday).length;

    if (_isValidUuid(deck.id)) {
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
        final cardsPayload = cards.where((c) => _isValidUuid(c.id)).map((c) {
          return <String, dynamic>{
            'id': c.id,
            'deck_id': deck.id,
            if (userId.isNotEmpty) 'user_id': userId,
            'front': c.front,
            'back': c.back,
            'front_latex': c.frontLatex,
            'back_latex': c.backLatex,
            'source_topic': c.sourceTopic,
            'interval': c.interval,
            'repetitions': c.repetitions,
            'ease_factor': c.easeFactor,
            'next_due_date': (c.nextDueDate ?? DateTime.now())
                .toIso8601String(),
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
  }

  @override
  Future<List<DeckModel>> getUserDecks() async {
    await _loadPersistedDecksIntoMemory();

    final token = _userStorage?.getToken();
    if (_userStorage != null && (token == null || token.trim().isEmpty)) {
      // User is unauthenticated: return local created decks & canonical course decks immediately without network call
      final fallbackList = <DeckModel>[..._localCreatedDecks];
      return fallbackList;
    }

    try {
      // 1. Flush any pending offline deck deletions to Supabase
      final pendingDeletions = _getPendingDeckDeletions();
      if (pendingDeletions.isNotEmpty) {
        final remainingPending = Set<String>.from(pendingDeletions);
        for (final deletedId in pendingDeletions) {
          if (_isValidUuid(deletedId)) {
            try {
              await _client.deleteDeck(deletedId);
              remainingPending.remove(deletedId);
            } on Object catch (_) {}
          } else {
            remainingPending.remove(deletedId);
          }
        }
        await _savePendingDeckDeletions(remainingPending);
      }

      final remoteDecks = await _client.getUserDecks();
      // Filter out any decks that were deleted locally while offline
      final activeRemoteDecks = remoteDecks
          .where((d) => !pendingDeletions.contains(d.id))
          .toList();
      final remoteIds = activeRemoteDecks.map((d) => d.id).toSet();
      final dashboardFeed = locator.isRegistered<DashboardBloc>()
          ? locator<DashboardBloc>().state.feed
          : null;
      final dashDueMap = {
        if (dashboardFeed != null)
          for (final d in dashboardFeed.dueStudyDecks)
            d.id: d,
      };

      final updatedRemote = activeRemoteDecks.map((remote) {
        final localMatch = _localCreatedDecks
            .where((d) => d.id == remote.id)
            .firstOrNull;
        final dashMatch = dashDueMap[remote.id];

        final inMemCards = _localDeckCards[remote.id];
        final inMemDue = inMemCards != null && inMemCards.isNotEmpty
            ? inMemCards.where((c) => c.isDueToday).length
            : 0;

        var effectiveDue = remote.dueCards;
        if (localMatch != null && localMatch.dueCards > effectiveDue) {
          effectiveDue = localMatch.dueCards;
        }
        if (dashMatch != null && dashMatch.dueCards > effectiveDue) {
          effectiveDue = dashMatch.dueCards;
        }
        if (inMemDue > effectiveDue) {
          effectiveDue = inMemDue;
        }

        var effectiveMastery = remote.masteryRate;
        if (localMatch != null && localMatch.masteryRate > effectiveMastery) {
          effectiveMastery = localMatch.masteryRate;
        }

        var effectiveTotal = remote.totalCards;
        if (localMatch != null && localMatch.totalCards > effectiveTotal) {
          effectiveTotal = localMatch.totalCards;
        }
        if (dashMatch != null && dashMatch.totalCards > effectiveTotal) {
          effectiveTotal = dashMatch.totalCards;
        }
        if (inMemCards != null && inMemCards.length > effectiveTotal) {
          effectiveTotal = inMemCards.length;
        }

        var effectiveLastStudied = remote.lastStudied;
        if (localMatch != null && localMatch.lastStudied != null) {
          if (effectiveLastStudied == null ||
              localMatch.lastStudied!.isAfter(effectiveLastStudied)) {
            effectiveLastStudied = localMatch.lastStudied;
          }
        }
        if (dashMatch != null) {
          if (effectiveLastStudied == null ||
              dashMatch.lastReviewed.isAfter(effectiveLastStudied)) {
            effectiveLastStudied = dashMatch.lastReviewed;
          }
        }

        // If effective due cards were higher than remote due cards, sync back to Supabase in background
        if (effectiveDue > remote.dueCards && _isValidUuid(remote.id)) {
          unawaited(() async {
            try {
              await _client.updateDeckRecord(remote.id, {
                'due_cards': effectiveDue,
                if (effectiveLastStudied != null)
                  'last_studied': effectiveLastStudied.toIso8601String(),
              });
            } on Object catch (_) {}
          }());
        }

        return remote.copyWith(
          totalCards: effectiveTotal,
          dueCards: effectiveDue,
          masteryRate: effectiveMastery,
          lastStudied: effectiveLastStudied,
        );
      }).toList();

      // 2. Auto-sync offline-created decks to Supabase now that we are online
      final userId = _userStorage?.getUserId() ?? '';
      final localOnlyDecks = _localCreatedDecks
          .where((d) =>
              !remoteIds.contains(d.id) &&
              _isValidUuid(d.id) &&
              !pendingDeletions.contains(d.id))
          .toList();
      for (final localDeck in localOnlyDecks) {
        unawaited(() async {
          try {
            await _client.createDeckRecord({
              'id': localDeck.id,
              'title': localDeck.title,
              'subject': localDeck.subject,
              'total_cards': localDeck.totalCards,
              'due_cards': localDeck.dueCards,
              'mastery_rate': localDeck.masteryRate,
              'description': localDeck.description,
              if (userId.isNotEmpty) 'user_id': userId,
              if (localDeck.courseId != null) 'course_id': localDeck.courseId,
              if (localDeck.courseCode != null)
                'course_code': localDeck.courseCode,
            });

            final cards = _localDeckCards[localDeck.id] ?? localDeck.cards;
            if (cards.isNotEmpty) {
              final cardsPayload = cards
                  .where((c) => _isValidUuid(c.id))
                  .map((c) {
                return <String, dynamic>{
                  'id': c.id,
                  'deck_id': localDeck.id,
                  if (userId.isNotEmpty) 'user_id': userId,
                  'front': c.front,
                  'back': c.back,
                  'front_latex': c.frontLatex,
                  'back_latex': c.backLatex,
                  'source_topic': c.sourceTopic,
                  'interval': c.interval,
                  'repetitions': c.repetitions,
                  'ease_factor': c.easeFactor,
                  'next_due_date':
                      (c.nextDueDate ?? DateTime.now()).toIso8601String(),
                };
              }).toList();
              if (cardsPayload.isNotEmpty) {
                await _client.bulkInsertCards(cardsPayload);
              }
            }
          } on Object catch (_) {}
        }());
      }

      final updatedLocalOnly = _localCreatedDecks
          .where((d) => !remoteIds.contains(d.id))
          .map((localDeck) {
            final dashMatch = dashDueMap[localDeck.id];
            final inMemCards = _localDeckCards[localDeck.id];
            final inMemDue = inMemCards != null && inMemCards.isNotEmpty
                ? inMemCards.where((c) => c.isDueToday).length
                : 0;

            var effectiveDue = localDeck.dueCards;
            if (dashMatch != null && dashMatch.dueCards > effectiveDue) {
              effectiveDue = dashMatch.dueCards;
            }
            if (inMemDue > effectiveDue) {
              effectiveDue = inMemDue;
            }

            var effectiveTotal = localDeck.totalCards;
            if (dashMatch != null && dashMatch.totalCards > effectiveTotal) {
              effectiveTotal = dashMatch.totalCards;
            }
            if (inMemCards != null && inMemCards.length > effectiveTotal) {
              effectiveTotal = inMemCards.length;
            }

            return localDeck.copyWith(
              totalCards: effectiveTotal,
              dueCards: effectiveDue,
            );
          })
          .toList();

      final merged = [
        ...updatedLocalOnly,
        ...updatedRemote,
      ];

      // Deduplicate decks created from the same auto-synthesized document
      final seenDocDecks = <String, DeckModel>{};
      final dedupedResult = <DeckModel>[];
      final duplicateDeckIdsToRemove = <String>[];

      for (final deck in merged) {
        final desc = deck.description ?? '';
        final docMatch = RegExp('Auto-synthesized from document ([a-zA-Z0-9_-]+)').firstMatch(desc);
        if (docMatch != null) {
          final docId = docMatch.group(1)!;
          if (seenDocDecks.containsKey(docId)) {
            final prev = seenDocDecks[docId]!;
            if (deck.masteryRate > prev.masteryRate ||
                (deck.lastStudied != null && (prev.lastStudied == null || deck.lastStudied!.isAfter(prev.lastStudied!)))) {
              duplicateDeckIdsToRemove.add(prev.id);
              seenDocDecks[docId] = deck;
              final idx = dedupedResult.indexOf(prev);
              if (idx >= 0) dedupedResult[idx] = deck;
            } else {
              duplicateDeckIdsToRemove.add(deck.id);
            }
            continue;
          }
          seenDocDecks[docId] = deck;
        }
        dedupedResult.add(deck);
      }

      if (duplicateDeckIdsToRemove.isNotEmpty) {
        _localCreatedDecks.removeWhere((d) => duplicateDeckIdsToRemove.contains(d.id));
        _persistLocalDecksToStorage();
      }

      // Persist fetched remote decks into local SQLite and memory cache for offline continuity across reinstalls
      for (final deck in updatedRemote) {
        final idx = _localCreatedDecks.indexWhere((d) => d.id == deck.id);
        if (idx < 0) {
          _localCreatedDecks.add(deck);
        } else {
          _localCreatedDecks[idx] = deck;
        }
        unawaited(_localDataSource?.saveDeck(deck));
      }
      _persistLocalDecksToStorage();

      final resultList = <DeckModel>[...dedupedResult];

      // Background offline pre-fetching of top due decks to guarantee 100% offline study availability
      unawaited(_prefetchTopDueDecks(updatedRemote));

      return resultList.map(DeckTitleResolver.enrichDeckModel).toList();
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        final isAuthOrNotFound =
            e is DioException &&
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
      final seenFallback = <String, DeckModel>{};
      final dedupedFallback = <DeckModel>[];
      for (final deck in fallbackList) {
        final desc = deck.description ?? '';
        final docMatch = RegExp('Auto-synthesized from document ([a-zA-Z0-9_-]+)').firstMatch(desc);
        if (docMatch != null) {
          final docId = docMatch.group(1)!;
          if (seenFallback.containsKey(docId)) continue;
          seenFallback[docId] = deck;
        }
        dedupedFallback.add(deck);
      }
      return dedupedFallback.map(DeckTitleResolver.enrichDeckModel).toList();
    }
  }

  Future<void> _prefetchTopDueDecks(List<DeckModel> decks) async {
    final dueDecks =
        decks.where((d) => d.dueCards > 0 && _isValidId(d.id)).take(3);
    for (final deck in dueDecks) {
      if (!_localDeckCards.containsKey(deck.id) ||
          _localDeckCards[deck.id]!.isEmpty) {
        try {
          final cards = await _client.getDeckCards(deck.id);
          if (cards.isNotEmpty) {
            _localDeckCards[deck.id] = cards;
            unawaited(_localDataSource?.saveCards(deck.id, cards));
          }
        } on Object catch (_) {}
      }
    }
  }

  @override
  Future<List<FlashcardModel>> getDeckCards(String deckId) async {
    if (_localDeckCards.containsKey(deckId) &&
        _localDeckCards[deckId]!.isNotEmpty) {
      return _localDeckCards[deckId]!;
    }

    // 0. Check in-memory created decks
    final inMemoryDeck = _localCreatedDecks
        .where((d) => d.id == deckId)
        .firstOrNull;
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

    // 3. Fetch from remote if not cached locally, deckId is a valid UUID, and user is authenticated
    final token = _userStorage?.getToken();
    if (_isValidUuid(deckId) &&
        (_userStorage == null || (token != null && token.trim().isNotEmpty))) {
      try {
        final cards = await _client.getDeckCards(deckId);
        if (cards.isNotEmpty) {
          _localDeckCards[deckId] = cards;
          unawaited(_localDataSource?.saveCards(deckId, cards));
          return cards;
        }
      } on Object catch (e, stack) {
        if (_crashlyticsService != null) {
          final isAuthOrNotFound =
              e is DioException &&
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
  Future<void> updateDeckCards(
    String deckId,
    List<FlashcardModel> cards,
  ) async {
    _localDeckCards[deckId] = cards;

    final dueCount = cards.where((c) => c.isDueToday).length;
    final masteredCount = cards.where((c) => c.repetitions >= 1).length;
    final calculatedMasteryRate = cards.isNotEmpty
        ? (masteredCount / cards.length)
        : 0.0;

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

    _persistLocalDecksToStorage();

    // Direct, targeted update in SQLite: only cards for this deck updated
    await _localDataSource?.saveCards(deckId, cards);
    await _localDataSource?.updateDeckStats(
      deckId: deckId,
      masteryRate: calculatedMasteryRate,
      dueCards: dueCount,
    );

    // Push card updates and deck metadata to Supabase asynchronously
    final userId = _userStorage?.getUserId() ?? '';
    if (_isValidUuid(deckId)) {
      unawaited(() async {
        try {
          await _client.updateDeckRecord(
            deckId,
            <String, dynamic>{
              'total_cards': cards.length,
              'due_cards': dueCount,
              'mastery_rate': calculatedMasteryRate,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );

          final cardsPayload = cards.where((c) => _isValidUuid(c.id)).map((c) {
            return <String, dynamic>{
              'id': c.id,
              'deck_id': deckId,
              if (userId.isNotEmpty) 'user_id': userId,
              'front': c.front,
              'back': c.back,
              'front_latex': c.frontLatex,
              'back_latex': c.backLatex,
              'source_topic': c.sourceTopic,
              'interval': c.interval,
              'repetitions': c.repetitions,
              'ease_factor': c.easeFactor,
              'next_due_date': (c.nextDueDate ?? DateTime.now()).toIso8601String(),
            };
          }).toList();

          if (cardsPayload.isNotEmpty) {
            await _client.bulkInsertCards(cardsPayload);
          }
        } on Object catch (e, stack) {
          final crashlytics = _crashlyticsService;
          if (crashlytics != null) {
            unawaited(
              crashlytics.recordError(
                e,
                stack,
                reason: 'DecksRemoteDataSource.updateDeckCards remote sync failed',
              ),
            );
          }
        }
      }());
    }
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
      await _localDataSource?.batchUpdateCards(updatedCards);
    }

    final cards =
        _localDeckCards[deckId] ?? updatedCards ?? const <FlashcardModel>[];
    final masteredCount = cards.where((c) => c.repetitions >= 1).length;
    final totalCount = cards.isNotEmpty ? cards.length : cardsReviewed;
    final calculatedMasteryRate =
        masteryRate ??
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
        DeckTitleResolver.enrichDeckModel(
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
        ),
      );
    }

    // 3. Fast targeted SQLite update for deck stats & ensure deck row exists
    _persistLocalDecksToStorage();
    final deckEntry = _localCreatedDecks.firstWhere((d) => d.id == deckId);
    await _localDataSource?.saveDeck(deckEntry, cards: cards);
    await _localDataSource?.updateDeckStats(
      deckId: deckId,
      masteryRate: calculatedMasteryRate,
      dueCards: calculatedDueCards,
      lastStudied: now,
    );

    // 4. Sync to Supabase RPC record_study_session with correct parameter names if UUID
    if (_isValidUuid(deckId)) {
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

      // 6. Persist updated card review states to Supabase flashcards table
      if (updatedCards != null && updatedCards.isNotEmpty) {
        final userId = _userStorage?.getUserId() ?? '';
        final cardsPayload =
            updatedCards.where((c) => _isValidUuid(c.id)).map((c) {
          return <String, dynamic>{
            'id': c.id,
            'deck_id': deckId,
            if (userId.isNotEmpty) 'user_id': userId,
            'front': c.front,
            'back': c.back,
            'front_latex': c.frontLatex,
            'back_latex': c.backLatex,
            'source_topic': c.sourceTopic,
            'interval': c.interval,
            'repetitions': c.repetitions,
            'ease_factor': c.easeFactor,
            'next_due_date':
                (c.nextDueDate ?? DateTime.now()).toIso8601String(),
          };
        }).toList();

        if (cardsPayload.isNotEmpty) {
          try {
            await _client.bulkInsertCards(cardsPayload);
          } on Object catch (_) {
            // Offline/Local continues gracefully
          }
        }
      }
    }
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    _localDeckCards.remove(deckId);
    _localCreatedDecks.removeWhere((d) => d.id == deckId);
    _persistLocalDecksToStorage();
    unawaited(_localDataSource?.deleteDeck(deckId));

    final pending = _getPendingDeckDeletions()..add(deckId);
    await _savePendingDeckDeletions(pending);

    if (_isValidUuid(deckId)) {
      try {
        await _client.deleteDeck(deckId);
        final remaining = _getPendingDeckDeletions()..remove(deckId);
        await _savePendingDeckDeletions(remaining);
      } on Object catch (_) {
        // Offline/Local deletion continues smoothly; retained in pending deletions queue
      }
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
      if (subject != null && d.subject.toLowerCase() == subject.toLowerCase()) {
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
    _persistLocalDecksToStorage();

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
      _persistLocalDecksToStorage();
    }

    unawaited(
      _localDataSource?.linkDeckToCourse(
        deckId: deckId,
        courseId: courseId,
        courseCode: courseCode,
        subject: subject,
      ),
    );

    if (_isValidUuid(deckId)) {
      try {
        await _client.updateDeckRecord(deckId, {
          'course_id': courseId,
          'course_code': courseCode,
        });
      } on Object catch (_) {}
    }
  }

  @override
  Future<void> deleteAllDecks() async {
    final allIds = _localCreatedDecks.map((d) => d.id).toList();
    _localDeckCards.clear();
    _localCreatedDecks.clear();
    _persistLocalDecksToStorage();
    unawaited(_localDataSource?.deleteAllDecks());

    for (final id in allIds) {
      try {
        await _client.deleteDeck(id);
      } on Object catch (_) {}
    }
  }
}
