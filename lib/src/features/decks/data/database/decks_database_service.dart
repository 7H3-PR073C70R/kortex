import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DecksDatabaseService {
  DecksDatabaseService({
    AppDatabase? appDatabase,
    Database? database,
    LocalStorageService? localStorageService,
  })  : _appDatabase = appDatabase,
        _db = database,
        _localStorage = localStorageService;

  final AppDatabase? _appDatabase;
  Database? _db;
  final LocalStorageService? _localStorage;

  AppDatabase? get appDatabase => _appDatabase;
  static bool _ffiInitialized = false;

  static void ensureFfiInitialized() {
    if (kIsWeb) return;
    if (!_ffiInitialized) {
      if (Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.environment.containsKey('FLUTTER_TEST')) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _ffiInitialized = true;
      }
    }
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await initDatabase();
    return _db!;
  }

  Future<Database> initDatabase({String? customPath}) async {
    ensureFfiInitialized();

    final String dbPath;
    if (customPath != null) {
      dbPath = customPath;
    } else {
      final databasesPath = await getDatabasesPath();
      dbPath = p.join(databasesPath, 'kortex_decks.db');
    }

    final db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );

    _db = db;
    await migrateFromLegacyStorageIfNeeded();
    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE decks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subject TEXT NOT NULL DEFAULT 'General',
        category TEXT NOT NULL DEFAULT 'General',
        total_cards INTEGER NOT NULL DEFAULT 0,
        due_cards INTEGER NOT NULL DEFAULT 0,
        mastery_rate REAL NOT NULL DEFAULT 0.0,
        description TEXT,
        last_studied TEXT,
        color_hex TEXT,
        icon_name TEXT,
        course_id TEXT,
        course_code TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE flashcards (
        id TEXT PRIMARY KEY,
        deck_id TEXT NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        front_latex TEXT,
        back_latex TEXT,
        image_url TEXT,
        interval INTEGER NOT NULL DEFAULT 1,
        repetitions INTEGER NOT NULL DEFAULT 0,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        last_reviewed TEXT,
        next_due_date TEXT,
        source_topic TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_flashcards_deck_id ON flashcards(deck_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_flashcards_next_due_date ON flashcards(next_due_date);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_decks_course_id ON decks(course_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_decks_course_code ON decks(course_code);',
    );
  }

  /// Automatically migrates any legacy monolithic JSON decks and cards into SQLite
  Future<void> migrateFromLegacyStorageIfNeeded() async {
    if (_localStorage == null) return;
    try {
      final raw = _localStorage.getPreference(key: PrefKeys.persistedUserDecks);
      if (raw == null || raw.trim().isEmpty) return;

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final db = _db;
      if (db == null || !db.isOpen) return;

      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        for (final item in decoded) {
          if (item is! Map<String, dynamic>) continue;
          final deckId = item['id'] as String? ?? '';
          if (deckId.isEmpty) continue;

          // Check if deck already in database
          final existing = await txn.query(
            'decks',
            where: 'id = ?',
            whereArgs: [deckId],
            limit: 1,
          );

          if (existing.isEmpty) {
            await txn.insert(
              'decks',
              {
                'id': deckId,
                'title': item['title'] as String? ?? 'Untitled Deck',
                'subject': item['subject'] as String? ?? 'General',
                'category': item['category'] as String? ?? 'General',
                'total_cards': (item['totalCards'] ?? item['total_cards']) as int? ?? 0,
                'due_cards': (item['dueCards'] ?? item['due_cards']) as int? ?? 0,
                'mastery_rate': ((item['masteryRate'] ?? item['mastery_rate']) as num?)?.toDouble() ?? 0.0,
                'description': item['description'] as String?,
                'last_studied': item['lastStudied'] != null
                    ? (item['lastStudied'] is String
                        ? item['lastStudied'] as String
                        : (item['lastStudied'] as DateTime).toIso8601String())
                    : null,
                'color_hex': item['colorHex'] as String?,
                'icon_name': item['iconName'] as String?,
                'course_id': item['course_id'] as String? ?? item['courseId'] as String?,
                'course_code': item['course_code'] as String? ?? item['courseCode'] as String?,
                'created_at': now,
                'updated_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Migrate associated cards: either inside deck JSON or from prefix key
          var cardsRaw = item['cards'] as List<dynamic>?;
          if (cardsRaw == null || cardsRaw.isEmpty) {
            final cardPrefKey = '${PrefKeys.persistedDeckCardsPrefix}$deckId';
            final prefixRaw = _localStorage.getPreference(key: cardPrefKey);
            if (prefixRaw != null && prefixRaw.isNotEmpty) {
              final dynamic prefixDecoded = jsonDecode(prefixRaw);
              if (prefixDecoded is List) {
                cardsRaw = prefixDecoded;
              }
            }
          }

          if (cardsRaw != null && cardsRaw.isNotEmpty) {
            for (final c in cardsRaw) {
              if (c is! Map<String, dynamic>) continue;
              final cardId = c['id'] as String? ?? '';
              if (cardId.isEmpty) continue;

              await txn.insert(
                'flashcards',
                {
                  'id': cardId,
                  'deck_id': deckId,
                  'front': c['front'] as String? ?? '',
                  'back': c['back'] as String? ?? '',
                  'front_latex': c['frontLatex'] as String? ?? c['front_latex'] as String?,
                  'back_latex': c['backLatex'] as String? ?? c['back_latex'] as String?,
                  'image_url': c['imageUrl'] as String? ?? c['image_url'] as String?,
                  'interval': (c['interval'] as int?) ?? 1,
                  'repetitions': (c['repetitions'] as int?) ?? 0,
                  'ease_factor': (c['easeFactor'] as num?)?.toDouble() ?? (c['ease_factor'] as num?)?.toDouble() ?? 2.5,
                  'last_reviewed': c['lastReviewed'] as String? ?? c['last_reviewed'] as String?,
                  'next_due_date': c['nextDueDate'] as String? ?? c['next_due_date'] as String?,
                  'source_topic': c['sourceTopic'] as String? ?? c['source_topic'] as String?,
                  'created_at': now,
                  'updated_at': now,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      });

      // Cleanup legacy monolithic preference to free up device storage
      await _localStorage.deletePreference(key: PrefKeys.persistedUserDecks);
    } on Object {
      // Non-fatal fallback for unparseable legacy data
    }
  }

  // --- CRUD Queries ---

  Future<List<Map<String, dynamic>>> queryDecks() async {
    final db = await database;
    return db.query('decks', orderBy: 'last_studied DESC, title ASC');
  }

  Future<Map<String, dynamic>?> queryDeck(String id) async {
    final db = await database;
    final results = await db.query(
      'decks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<List<Map<String, dynamic>>> queryCardsForDeck(String deckId) async {
    final db = await database;
    return db.query(
      'flashcards',
      where: 'deck_id = ?',
      whereArgs: [deckId],
      orderBy: 'next_due_date ASC, id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> queryDueCards({
    String? deckId,
    DateTime? beforeDate,
  }) async {
    final db = await database;
    final threshold = (beforeDate ?? DateTime.now()).toIso8601String();

    if (deckId != null && deckId.isNotEmpty) {
      return db.query(
        'flashcards',
        where: 'deck_id = ? AND (next_due_date IS NULL OR next_due_date <= ?)',
        whereArgs: [deckId, threshold],
        orderBy: 'next_due_date ASC',
      );
    }

    return db.query(
      'flashcards',
      where: 'next_due_date IS NULL OR next_due_date <= ?',
      whereArgs: [threshold],
      orderBy: 'next_due_date ASC',
    );
  }

  Future<void> upsertDeck(Map<String, dynamic> deckData) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final data = Map<String, dynamic>.from(deckData)
      ..['updated_at'] = now
      ..putIfAbsent('created_at', () => now)
      ..putIfAbsent('subject', () => 'General')
      ..putIfAbsent('category', () => 'General')
      ..putIfAbsent('total_cards', () => 0)
      ..putIfAbsent('due_cards', () => 0)
      ..putIfAbsent('mastery_rate', () => 0.0);

    await db.insert(
      'decks',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDeckMetadata(
    String deckId,
    Map<String, dynamic> values,
  ) async {
    final db = await database;
    final data = Map<String, dynamic>.from(values);
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'decks',
      data,
      where: 'id = ?',
      whereArgs: [deckId],
    );
  }

  Future<void> upsertCard(Map<String, dynamic> cardData) async {
    final db = await database;
    final data = Map<String, dynamic>.from(cardData);
    final now = DateTime.now().toIso8601String();
    data['updated_at'] = now;
    data.putIfAbsent('created_at', () => now);

    await db.insert(
      'flashcards',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Automatically recalculate deck statistics if deck_id is present
    final deckId = data['deck_id'] as String?;
    if (deckId != null && deckId.isNotEmpty) {
      await recalculateDeckStats(deckId);
    }
  }

  Future<void> batchUpsertCards(List<Map<String, dynamic>> cardsData) async {
    if (cardsData.isEmpty) return;
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final deckIds = <String>{};

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final card in cardsData) {
        final data = Map<String, dynamic>.from(card);
        data['updated_at'] = now;
        data.putIfAbsent('created_at', () => now);
        final deckId = data['deck_id'] as String?;
        if (deckId != null && deckId.isNotEmpty) {
          deckIds.add(deckId);
        }
        batch.insert(
          'flashcards',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    for (final deckId in deckIds) {
      await recalculateDeckStats(deckId);
    }
  }

  Future<void> batchUpsertDeckAndCards(
    Map<String, dynamic> deckData,
    List<Map<String, dynamic>> cardsData,
  ) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final deck = Map<String, dynamic>.from(deckData)
      ..['updated_at'] = now
      ..putIfAbsent('created_at', () => now)
      ..putIfAbsent('subject', () => 'General')
      ..putIfAbsent('category', () => 'General')
      ..['total_cards'] = cardsData.length;

    await db.transaction((txn) async {
      await txn.insert(
        'decks',
        deck,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final batch = txn.batch();
      for (final card in cardsData) {
        final c = Map<String, dynamic>.from(card);
        c['deck_id'] = deck['id'];
        c['updated_at'] = now;
        c.putIfAbsent('created_at', () => now);
        batch.insert(
          'flashcards',
          c,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    await recalculateDeckStats(deck['id'] as String);
  }

  Future<void> recalculateDeckStats(String deckId) async {
    final db = await database;
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day, 23, 59, 59)
        .toIso8601String();

    final allCards = await db.query(
      'flashcards',
      columns: ['id', 'repetitions', 'next_due_date'],
      where: 'deck_id = ?',
      whereArgs: [deckId],
    );

    if (allCards.isEmpty) {
      await db.update(
        'decks',
        {
          'total_cards': 0,
          'due_cards': 0,
          'mastery_rate': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [deckId],
      );
      return;
    }

    final total = allCards.length;
    var dueCount = 0;
    var masteredCount = 0;

    for (final c in allCards) {
      final reps = (c['repetitions'] as int?) ?? 0;
      if (reps >= 1) {
        masteredCount++;
      }
      final dueDateStr = c['next_due_date'] as String?;
      if (dueDateStr == null || dueDateStr.compareTo(todayStr) <= 0) {
        dueCount++;
      }
    }

    final masteryRate = total > 0 ? (masteredCount / total) : 0.0;

    await db.update(
      'decks',
      {
        'total_cards': total,
        'due_cards': dueCount,
        'mastery_rate': masteryRate,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [deckId],
    );
  }

  Future<void> deleteDeck(String deckId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'flashcards',
        where: 'deck_id = ?',
        whereArgs: [deckId],
      );
      await txn.delete(
        'decks',
        where: 'id = ?',
        whereArgs: [deckId],
      );
    });
  }

  Future<void> deleteDecksForCourse(
    String courseId, {
    String? courseCode,
    String? subject,
  }) async {
    final db = await database;
    final whereClauses = <String>['course_id = ?'];
    final whereArgs = <dynamic>[courseId];

    if (courseCode != null && courseCode.isNotEmpty) {
      whereClauses.add('LOWER(course_code) = LOWER(?)');
      whereArgs.add(courseCode);
    }
    if (subject != null && subject.isNotEmpty) {
      whereClauses.add('LOWER(subject) = LOWER(?)');
      whereArgs.add(subject);
    }

    final whereStr = whereClauses.join(' OR ');
    final decks = await db.query(
      'decks',
      columns: ['id'],
      where: whereStr,
      whereArgs: whereArgs,
    );

    final deckIds = decks.map((d) => d['id']?.toString()).whereType<String>().toList();
    if (deckIds.isEmpty) return;

    await db.transaction((txn) async {
      for (final id in deckIds) {
        await txn.delete(
          'flashcards',
          where: 'deck_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'decks',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> deleteAllDecks() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('flashcards');
      await txn.delete('decks');
    });
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
