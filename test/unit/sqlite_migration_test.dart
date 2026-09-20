import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/database/app_database.dart';

void main() {
  test('AppDatabase self-heals on batchUpsertDeckAndCardsTransaction if stability is missing', () async {
    final rawDb = NativeDatabase.memory();
    // Simulate database already open without calling beforeOpen/migration
    await rawDb.ensureOpen(_FakeUser(6));
    await rawDb.runCustom(
      'CREATE TABLE decks (id TEXT PRIMARY KEY, title TEXT, subject TEXT, category TEXT, total_cards INTEGER, due_cards INTEGER, mastery_rate REAL, description TEXT, last_studied INTEGER, color_hex TEXT, icon_name TEXT, course_id TEXT, course_code TEXT, created_at INTEGER, updated_at INTEGER);',
    );
    await rawDb.runCustom(
      'CREATE TABLE flashcards ('
      'id TEXT PRIMARY KEY, '
      'deck_id TEXT REFERENCES decks(id), '
      'front TEXT NOT NULL, '
      'back TEXT NOT NULL, '
      'front_latex TEXT, '
      'back_latex TEXT, '
      'image_url TEXT, '
      'interval INTEGER DEFAULT 1, '
      'repetitions INTEGER DEFAULT 0, '
      'ease_factor REAL DEFAULT 2.5, '
      'last_reviewed INTEGER, '
      'next_due_date INTEGER, '
      'source_topic TEXT, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL'
      ');',
    );

    final appDb = AppDatabase(rawDb);
    // Should self-heal without throwing SqliteException
    await appDb.batchUpsertDeckAndCardsTransaction(
      DecksCompanion.insert(
        id: 'deck_1',
        title: 'Test Deck',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      [
        FlashcardsCompanion.insert(
          id: 'card_1',
          deckId: 'deck_1',
          front: 'Front text',
          back: 'Back text',
          stability: const Value(2.5),
          difficulty: const Value(5.0),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );

    final card = await (appDb.select(appDb.flashcards)..where((c) => c.id.equals('card_1'))).getSingle();
    expect(card.stability, equals(2.5));
    expect(card.difficulty, equals(5.0));
    await appDb.close();
  });

  test('AppDatabase self-heals flashcards table if already at version 5 but missing columns', () async {
    final tempDir = await Directory.systemTemp.createTemp('drift_test_v5_');
    final file = File('${tempDir.path}/test_v5.db');

    // 1. Create DB at version 5 WITHOUT stability column (simulating an interrupted or dirty v5 upgrade)
    final setupDb = NativeDatabase(file);
    await setupDb.ensureOpen(_FakeUser(5));
    await setupDb.runCustom(
      'CREATE TABLE decks (id TEXT PRIMARY KEY, title TEXT, subject TEXT, category TEXT, total_cards INTEGER, due_cards INTEGER, mastery_rate REAL, description TEXT, last_studied INTEGER, color_hex TEXT, icon_name TEXT, course_id TEXT, course_code TEXT, created_at INTEGER, updated_at INTEGER);',
    );
    await setupDb.runCustom(
      'CREATE TABLE flashcards ('
      'id TEXT PRIMARY KEY, '
      'deck_id TEXT REFERENCES decks(id), '
      'front TEXT NOT NULL, '
      'back TEXT NOT NULL, '
      'front_latex TEXT, '
      'back_latex TEXT, '
      'image_url TEXT, '
      'interval INTEGER DEFAULT 1, '
      'repetitions INTEGER DEFAULT 0, '
      'ease_factor REAL DEFAULT 2.5, '
      'last_reviewed INTEGER, '
      'next_due_date INTEGER, '
      'source_topic TEXT, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL'
      ');',
    );
    await setupDb.runCustom('PRAGMA user_version = 5;');
    await setupDb.close();

    // 2. Open via AppDatabase on closed file
    final appDb = AppDatabase(NativeDatabase(file));
    final tableInfo = await appDb.customSelect('PRAGMA table_info(flashcards);').get();
    final columns = tableInfo.map((r) => r.read<String>('name')).toSet();
    print('COLUMNS IN FILE FLASHCARDS V5: $columns');
    expect(columns.contains('stability'), isTrue);
    await appDb.close();
    await tempDir.delete(recursive: true);
  });
}

class _FakeUser extends QueryExecutorUser {
  _FakeUser([this.schemaVersion = 1]);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}

  @override
  Future<void> create(QueryExecutor executor) async {}

  @override
  Future<void> migrate(QueryExecutor executor, int from, int to) async {}
}
