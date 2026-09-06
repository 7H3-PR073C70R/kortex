import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/database/app_database.dart';

void main() {
  group('AppDatabase Drift SQLite & FTS5 Test Suite', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('initializes all 5 relational tables and indices cleanly', () async {
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ).get();

      final tableNames = tables.map((r) => r.read<String>('name')).toSet();

      expect(tableNames.contains('decks'), isTrue);
      expect(tableNames.contains('flashcards'), isTrue);
      expect(tableNames.contains('fsrs_review_logs'), isTrue);
      expect(tableNames.contains('past_questions'), isTrue);
      expect(tableNames.contains('course_modules'), isTrue);
    });

    test('handles decks & flashcards relational lifecycle with CASCADE deletion', () async {
      final now = DateTime.now();
      const deckId = 'deck_cell_bio';

      await db.upsertDeckEntry(
        DecksCompanion(
          id: const Value(deckId),
          title: const Value('Cell Biology 101'),
          subject: const Value('Biology'),
          category: const Value('Science'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final cards = [
        FlashcardsCompanion(
          id: const Value('card_1'),
          deckId: const Value(deckId),
          front: const Value('Powerhouse of the cell'),
          back: const Value('Mitochondria'),
          sourceTopic: const Value('Organelles'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        FlashcardsCompanion(
          id: const Value('card_2'),
          deckId: const Value(deckId),
          front: const Value('Site of photosynthesis'),
          back: const Value('Chloroplast'),
          sourceTopic: const Value('Plant Cells'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      ];

      await db.batchUpsertFlashcards(cards);

      final deck = await db.getDeckById(deckId);
      expect(deck, isNotNull);
      expect(deck!.title, equals('Cell Biology 101'));
      expect(deck.totalCards, equals(2));

      final deckCards = await db.getCardsForDeckId(deckId);
      expect(deckCards.length, equals(2));

      // Test cascade deletion
      await db.deleteDeckById(deckId);

      final deletedDeck = await db.getDeckById(deckId);
      expect(deletedDeck, isNull);

      final remainingCards = await db.getCardsForDeckId(deckId);
      expect(remainingCards, isEmpty);
    });

    test('SQLite FTS5 full-text search retrieves cards instantaneously by keyword prefix', () async {
      final now = DateTime.now();
      const deckId = 'deck_fts_test';

      await db.upsertDeckEntry(
        DecksCompanion(
          id: const Value(deckId),
          title: const Value('Physics & Chemistry'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.batchUpsertFlashcards([
        FlashcardsCompanion(
          id: const Value('card_relativity'),
          deckId: const Value(deckId),
          front: const Value('Theory of General Relativity'),
          back: const Value('Spacetime curvature described by Einstein'),
          sourceTopic: const Value('Modern Physics'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        FlashcardsCompanion(
          id: const Value('card_thermo'),
          deckId: const Value(deckId),
          front: const Value('Second Law of Thermodynamics'),
          back: const Value('Total entropy of an isolated system always increases'),
          sourceTopic: const Value('Thermodynamics'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        FlashcardsCompanion(
          id: const Value('card_chem_bond'),
          deckId: const Value(deckId),
          front: const Value('Covalent chemical bond sharing electrons'),
          back: const Value('Forms molecular orbitals between non-metals'),
          sourceTopic: const Value('Inorganic Chemistry'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      ]);

      // FTS search for "Relativity"
      final relativityResults = await db.searchCardsFts('Relativ');
      expect(relativityResults.length, equals(1));
      expect(relativityResults.first.id, equals('card_relativity'));

      // FTS search for "entropy"
      final entropyResults = await db.searchCardsFts('entropy');
      expect(entropyResults.length, equals(1));
      expect(entropyResults.first.id, equals('card_thermo'));

      // FTS search for "electrons"
      final electronResults = await db.searchCardsFts('electr');
      expect(electronResults.length, equals(1));
      expect(electronResults.first.id, equals('card_chem_bond'));
    });

    test('FsrsReviewLogs supports atomic ACID queue operations and sync tracking', () async {
      final now = DateTime.now();

      await db.insertReviewLogEntry(
        FsrsReviewLogsCompanion(
          id: const Value('log_1'),
          transactionUuid: const Value('tx-uuid-1111'),
          cardId: const Value('card_abc'),
          rating: const Value(3),
          stability: const Value(4.2),
          difficulty: const Value(5.1),
          elapsedDays: const Value(1),
          scheduledDays: const Value(4),
          reviewedAtUtc: Value(now),
          reviewedAtEpoch: Value(now.millisecondsSinceEpoch),
          state: const Value(2),
          isSynced: const Value(false),
        ),
      );

      await db.insertReviewLogEntry(
        FsrsReviewLogsCompanion(
          id: const Value('log_2'),
          transactionUuid: const Value('tx-uuid-2222'),
          cardId: const Value('card_xyz'),
          rating: const Value(4),
          stability: const Value(9.8),
          difficulty: const Value(3.4),
          elapsedDays: const Value(3),
          scheduledDays: const Value(10),
          reviewedAtUtc: Value(now),
          reviewedAtEpoch: Value(now.millisecondsSinceEpoch),
          state: const Value(2),
          isSynced: const Value(false),
        ),
      );

      var unsynced = await db.getUnsyncedReviewLogs();
      expect(unsynced.length, equals(2));

      // Mark tx-uuid-1111 as synced
      await db.markReviewLogsSynced(['tx-uuid-1111']);

      unsynced = await db.getUnsyncedReviewLogs();
      expect(unsynced.length, equals(1));
      expect(unsynced.first.transactionUuid, equals('tx-uuid-2222'));

      // Mark tx-uuid-2222 as synced
      await db.markReviewLogsSynced(['tx-uuid-2222']);
      unsynced = await db.getUnsyncedReviewLogs();
      expect(unsynced, isEmpty);
    });

    test('PastQuestions supports batch seeding, distinct filtering, and FTS5 search', () async {
      final questions = [
        const PastQuestionsCompanion(
          id: Value('pq_1'),
          examType: Value('WAEC'),
          subject: Value('Mathematics'),
          year: Value(2023),
          questionNumber: Value(1),
          prompt: Value('Solve for x: 2x + 5 = 15 quadratic equation fundamentals'),
          optionsJson: Value('["x = 5", "x = 10", "x = 2", "x = 7"]'),
          correctOptionIndex: Value(0),
          correctOptionLabel: Value('A'),
          explanation: Value('Subtract 5 from both sides, 2x = 10, hence x = 5.'),
          topic: Value('Algebra'),
        ),
        const PastQuestionsCompanion(
          id: Value('pq_2'),
          examType: Value('WAEC'),
          subject: Value('Physics'),
          year: Value(2023),
          questionNumber: Value(2),
          prompt: Value('Calculate velocity of a falling projectile under gravitational acceleration'),
          optionsJson: Value('["9.8 m/s", "19.6 m/s", "4.9 m/s", "0 m/s"]'),
          correctOptionIndex: Value(1),
          correctOptionLabel: Value('B'),
          explanation: Value('v = u + gt with u = 0, v = 9.8 * 2 = 19.6 m/s.'),
          topic: Value('Mechanics'),
        ),
        const PastQuestionsCompanion(
          id: Value('pq_3'),
          examType: Value('JAMB'),
          subject: Value('Biology'),
          year: Value(2022),
          questionNumber: Value(15),
          prompt: Value('Which blood cell is responsible for oxygen transport and hemoglobin binding?'),
          optionsJson: Value('["Erythrocytes", "Leukocytes", "Thrombocytes", "Plasma"]'),
          correctOptionIndex: Value(0),
          correctOptionLabel: Value('A'),
          explanation: Value('Erythrocytes (red blood cells) carry oxygen throughout mammalian circulation.'),
          topic: Value('Circulatory System'),
        ),
      ];

      await db.batchInsertPastQuestions(questions);

      final count = await db.countPastQuestions();
      expect(count, equals(3));

      // Test distinct subjects & years
      final waecSubjects = await db.getAvailableSubjectsForExam('WAEC');
      expect(waecSubjects, containsAll(['Mathematics', 'Physics']));

      final waecYears = await db.getAvailableYearsForExam('WAEC');
      expect(waecYears, equals([2023]));

      // Test FTS5 search across past questions
      final projectileResults = await db.getPastQuestionsList(
        searchQuery: 'projectile',
      );
      expect(projectileResults.length, equals(1));
      expect(projectileResults.first.id, equals('pq_2'));

      final hemoglobinResults = await db.getPastQuestionsList(
        searchQuery: 'hemoglobin',
      );
      expect(hemoglobinResults.length, equals(1));
      expect(hemoglobinResults.first.id, equals('pq_3'));
    });

    test('CourseModules supports batch caching and retrieval', () async {
      final now = DateTime.now();

      await db.batchUpsertCourseModules([
        CourseModulesCompanion(
          id: const Value('course_mth101'),
          courseCode: const Value('MTH 101'),
          title: const Value('Elementary Mathematics I'),
          department: const Value('Mathematics'),
          totalMaterials: const Value(12),
          hasActivePastPapers: const Value(true),
          iconName: const Value('functions'),
          colorHex: const Value('#3B82F6'),
          syllabusCoverage: const Value(0.85),
          updatedAt: Value(now),
        ),
        CourseModulesCompanion(
          id: const Value('course_csc201'),
          courseCode: const Value('CSC 201'),
          title: const Value('Data Structures & Algorithms'),
          department: const Value('Computer Science'),
          totalMaterials: const Value(8),
          hasActivePastPapers: const Value(true),
          iconName: const Value('code'),
          colorHex: const Value('#10B981'),
          syllabusCoverage: const Value(0.92),
          updatedAt: Value(now),
        ),
      ]);

      final allModules = await db.getAllCourseModules();
      expect(allModules.length, equals(2));

      final cscModule = await db.getCourseModuleById('course_csc201');
      expect(cscModule, isNotNull);
      expect(cscModule!.courseCode, equals('CSC 201'));
      expect(cscModule.syllabusCoverage, equals(0.92));
    });
  });
}
