import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/decks/data/database/decks_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class InMemoryLocalStorageService implements LocalStorageService {
  final Map<String, String> data = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => data[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    this.data[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    data.remove(key);
  }
}

void main() {
  setUpAll(DecksDatabaseService.ensureFfiInitialized);

  group('DecksDatabaseService', () {
    late DecksDatabaseService service;
    late InMemoryLocalStorageService localStorage;

    setUp(() async {
      localStorage = InMemoryLocalStorageService();
      service = DecksDatabaseService(localStorageService: localStorage);
      await service.initDatabase(customPath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await service.close();
    });

    test('initializes schema and tables correctly', () async {
      final db = await service.database;
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );
      final tableNames = tables.map((t) => t['name']?.toString()).whereType<String>().toSet();

      expect(tableNames.contains('decks'), isTrue);
      expect(tableNames.contains('flashcards'), isTrue);
    });

    test('cascades deletion from decks to flashcards', () async {
      const deckId = 'test_deck_1';
      await service.upsertDeck({
        'id': deckId,
        'title': 'Anatomy 101',
        'subject': 'Biology',
        'category': 'Medicine',
      });

      await service.batchUpsertCards([
        {
          'id': 'card_1',
          'deck_id': deckId,
          'front': 'Front 1',
          'back': 'Back 1',
        },
        {
          'id': 'card_2',
          'deck_id': deckId,
          'front': 'Front 2',
          'back': 'Back 2',
        },
      ]);

      var cards = await service.queryCardsForDeck(deckId);
      expect(cards.length, equals(2));

      await service.deleteDeck(deckId);

      final deck = await service.queryDeck(deckId);
      expect(deck, isNull);

      cards = await service.queryCardsForDeck(deckId);
      expect(cards, isEmpty);
    });

    test('queryDueCards filters by threshold date and null next_due_date', () async {
      const deckId = 'due_test_deck';
      await service.upsertDeck({
        'id': deckId,
        'title': 'Due Deck',
        'subject': 'General',
      });

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final tomorrow = now.add(const Duration(days: 1));

      await service.batchUpsertCards([
        {
          'id': 'overdue_card',
          'deck_id': deckId,
          'front': 'Q1',
          'back': 'A1',
          'next_due_date': yesterday.toIso8601String(),
        },
        {
          'id': 'unreviewed_card',
          'deck_id': deckId,
          'front': 'Q2',
          'back': 'A2',
          'next_due_date': null,
        },
        {
          'id': 'future_card',
          'deck_id': deckId,
          'front': 'Q3',
          'back': 'A3',
          'next_due_date': tomorrow.toIso8601String(),
        },
      ]);

      final dueCards = await service.queryDueCards(
        deckId: deckId,
        beforeDate: now,
      );

      final dueIds = dueCards.map((c) => c['id'] as String).toList();
      expect(dueIds, contains('overdue_card'));
      expect(dueIds, contains('unreviewed_card'));
      expect(dueIds, isNot(contains('future_card')));
    });

    test('recalculateDeckStats updates total_cards, due_cards, and mastery_rate', () async {
      const deckId = 'stats_deck';
      await service.upsertDeck({
        'id': deckId,
        'title': 'Stats Deck',
        'subject': 'Math',
      });

      final now = DateTime.now();
      await service.batchUpsertCards([
        {
          'id': 'c1',
          'deck_id': deckId,
          'front': '2+2',
          'back': '4',
          'repetitions': 1,
          'next_due_date': now.add(const Duration(days: 5)).toIso8601String(),
        },
        {
          'id': 'c2',
          'deck_id': deckId,
          'front': '3+3',
          'back': '6',
          'repetitions': 2,
          'next_due_date': now.add(const Duration(days: 10)).toIso8601String(),
        },
        {
          'id': 'c3',
          'deck_id': deckId,
          'front': '4+4',
          'back': '8',
          'repetitions': 0,
          'next_due_date': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
      ]);

      final deck = await service.queryDeck(deckId);
      expect(deck, isNotNull);
      expect(deck!['total_cards'], equals(3));
      expect(deck['due_cards'], equals(1));
      expect(deck['mastery_rate'], closeTo(2 / 3, 0.01));
    });

    test('migrates legacy SharedPreferences JSON seamlessly on first launch', () async {
      final legacyDeck = {
        'id': 'legacy_deck_1',
        'title': 'Legacy Chemistry',
        'subject': 'Chemistry',
        'category': 'Science',
        'totalCards': 1,
        'dueCards': 1,
        'masteryRate': 0.0,
        'cards': [
          {
            'id': 'legacy_card_1',
            'front': 'H2O',
            'back': 'Water',
            'interval': 1,
            'repetitions': 0,
            'easeFactor': 2.5,
          }
        ],
      };

      await localStorage.savePreference(
        key: PrefKeys.persistedUserDecks,
        data: jsonEncode([legacyDeck]),
      );

      // Create a new instance pointing to this localStorage
      final newService = DecksDatabaseService(localStorageService: localStorage);
      await newService.initDatabase(customPath: inMemoryDatabasePath);

      final decks = await newService.queryDecks();
      expect(decks.length, equals(1));
      expect(decks.first['id'], equals('legacy_deck_1'));
      expect(decks.first['title'], equals('Legacy Chemistry'));

      final cards = await newService.queryCardsForDeck('legacy_deck_1');
      expect(cards.length, equals(1));
      expect(cards.first['front'], equals('H2O'));
      expect(cards.first['back'], equals('Water'));

      // Legacy key should be removed to free storage
      expect(localStorage.getPreference(key: PrefKeys.persistedUserDecks), isNull);

      await newService.close();
    });
  });
}
