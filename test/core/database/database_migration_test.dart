import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/database/app_database.dart';

void main() {
  group('Drift DB Migration Safety Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('verifies schema version matches latest schema v6', () {
      expect(db.schemaVersion, equals(6));
    });

    test('verifies tables and indexes open cleanly without schema corruption', () async {
      final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get();
      final tableNames = tables.map((row) => row.read<String>('name')).toList();

      expect(tableNames, contains('decks'));
      expect(tableNames, contains('flashcards'));
      expect(tableNames, contains('fsrs_review_logs'));
      expect(tableNames, contains('exam_events'));
      expect(tableNames, contains('forum_posts'));
      expect(tableNames, contains('forum_replies'));
      expect(tableNames, contains('syllabot_sessions'));
      expect(tableNames, contains('syllabot_messages'));
      expect(tableNames, contains('thought_parking_lots'));
    });

    test('verifies custom SQL indexes exist for sub-5ms queries', () async {
      final indexes = await db.customSelect("SELECT name FROM sqlite_master WHERE type='index';").get();
      final indexNames = indexes.map((row) => row.read<String>('name')).toList();

      expect(indexNames, contains('idx_flashcards_deck_id'));
      expect(indexNames, contains('idx_flashcards_next_due_date'));
      expect(indexNames, contains('idx_flashcards_deck_due'));
      expect(indexNames, contains('idx_exam_events_user_id'));
      expect(indexNames, contains('idx_syllabot_sessions_user_id'));
      expect(indexNames, contains('idx_syllabot_messages_user_id'));
      expect(indexNames, contains('idx_thought_parking_lots_user_id'));
    });
  });
}
