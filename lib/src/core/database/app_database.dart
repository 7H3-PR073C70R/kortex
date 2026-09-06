import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:kortex/src/core/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Decks, Flashcards, FsrsReviewLogs, PastQuestions, CourseModules],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'kortex_drift'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (m) async {
          await m.createAll();

          // Standard indices
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_flashcards_deck_id ON flashcards(deck_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_flashcards_next_due_date ON flashcards(next_due_date);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_decks_course_id ON decks(course_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_decks_course_code ON decks(course_code);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_fsrs_review_logs_is_synced ON fsrs_review_logs(is_synced);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_past_questions_exam_subject_year ON past_questions(exam_type, subject, year);',
          );

          // SQLite FTS5 Virtual Tables and triggers for sub-millisecond search
          try {
            await customStatement('''
              CREATE VIRTUAL TABLE IF NOT EXISTS flashcards_fts USING fts5(
                card_id UNINDEXED,
                front,
                back,
                source_topic
              );
            ''');

            await customStatement('''
              CREATE TRIGGER IF NOT EXISTS flashcards_ai AFTER INSERT ON flashcards BEGIN
                INSERT INTO flashcards_fts(card_id, front, back, source_topic)
                VALUES (new.id, new.front, new.back, new.source_topic);
              END;
            ''');

            await customStatement('''
              CREATE TRIGGER IF NOT EXISTS flashcards_ad AFTER DELETE ON flashcards BEGIN
                DELETE FROM flashcards_fts WHERE card_id = old.id;
              END;
            ''');

            await customStatement('''
              CREATE TRIGGER IF NOT EXISTS flashcards_au AFTER UPDATE ON flashcards BEGIN
                DELETE FROM flashcards_fts WHERE card_id = old.id;
                INSERT INTO flashcards_fts(card_id, front, back, source_topic)
                VALUES (new.id, new.front, new.back, new.source_topic);
              END;
            ''');

            await customStatement('''
              CREATE VIRTUAL TABLE IF NOT EXISTS past_questions_fts USING fts5(
                question_id UNINDEXED,
                prompt,
                explanation,
                topic
              );
            ''');

            await customStatement('''
              CREATE TRIGGER IF NOT EXISTS past_questions_ai AFTER INSERT ON past_questions BEGIN
                INSERT INTO past_questions_fts(question_id, prompt, explanation, topic)
                VALUES (new.id, new.prompt, new.explanation, new.topic);
              END;
            ''');

            await customStatement('''
              CREATE TRIGGER IF NOT EXISTS past_questions_ad AFTER DELETE ON past_questions BEGIN
                DELETE FROM past_questions_fts WHERE question_id = old.id;
              END;
            ''');

            await customStatement('''
              CREATE TRIGGER IF NOT EXISTS past_questions_au AFTER UPDATE ON past_questions BEGIN
                DELETE FROM past_questions_fts WHERE question_id = old.id;
                INSERT INTO past_questions_fts(question_id, prompt, explanation, topic)
                VALUES (new.id, new.prompt, new.explanation, new.topic);
              END;
            ''');
          } on Object {
            // Non-fatal if FTS5 is not enabled in standard mock build
          }
        },
      );

  // ==========================================
  // DECKS OPERATIONS
  // ==========================================

  Future<List<DeckEntry>> getAllDecks() {
    return (select(decks)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastStudied,
                  mode: OrderingMode.desc,
                  nulls: NullsOrder.last,
                ),
            (t) => OrderingTerm(expression: t.title),
          ]))
        .get();
  }

  Future<DeckEntry?> getDeckById(String id) {
    return (select(decks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertDeckEntry(DecksCompanion deck) {
    return into(decks).insertOnConflictUpdate(deck);
  }

  Future<void> updateDeckMetadataFields(
    String deckId, {
    double? masteryRate,
    int? dueCards,
    int? totalCards,
    DateTime? lastStudied,
    String? courseId,
    String? courseCode,
    String? subject,
    String? description,
    String? colorHex,
    String? iconName,
  }) async {
    final now = DateTime.now();
    await (update(decks)..where((t) => t.id.equals(deckId))).write(
      DecksCompanion(
        masteryRate: masteryRate != null ? Value(masteryRate) : const Value.absent(),
        dueCards: dueCards != null ? Value(dueCards) : const Value.absent(),
        totalCards: totalCards != null ? Value(totalCards) : const Value.absent(),
        lastStudied: lastStudied != null ? Value(lastStudied) : const Value.absent(),
        courseId: courseId != null ? Value(courseId) : const Value.absent(),
        courseCode: courseCode != null ? Value(courseCode) : const Value.absent(),
        subject: subject != null ? Value(subject) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
        iconName: iconName != null ? Value(iconName) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteDeckById(String deckId) {
    return (delete(decks)..where((t) => t.id.equals(deckId))).go();
  }

  Future<void> deleteDecksForCourseId(
    String courseId, {
    String? courseCode,
    String? subject,
  }) async {
    await (delete(decks)
          ..where((t) {
            var predicate = t.courseId.equals(courseId);
            if (courseCode != null && courseCode.isNotEmpty) {
              predicate = predicate |
                  t.courseCode.lower().equals(courseCode.toLowerCase());
            }
            if (subject != null && subject.isNotEmpty) {
              predicate = predicate |
                  t.subject.lower().equals(subject.toLowerCase());
            }
            return predicate;
          }))
        .go();
  }

  Future<void> deleteAllDeckEntries() async {
    await delete(flashcards).go();
    await delete(decks).go();
  }

  // ==========================================
  // FLASHCARDS OPERATIONS
  // ==========================================

  Future<List<FlashcardEntry>> getCardsForDeckId(String deckId) {
    return (select(flashcards)
          ..where((t) => t.deckId.equals(deckId))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.nextDueDate,
                  nulls: NullsOrder.first,
                ),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
  }

  Future<List<FlashcardEntry>> getDueCardsList({
    String? deckId,
    DateTime? beforeDate,
  }) {
    final threshold = beforeDate ?? DateTime.now();
    final query = select(flashcards);

    if (deckId != null && deckId.isNotEmpty) {
      query.where(
        (t) =>
            t.deckId.equals(deckId) &
            (t.nextDueDate.isNull() | t.nextDueDate.isSmallerOrEqualValue(threshold)),
      );
    } else {
      query.where(
        (t) =>
            t.nextDueDate.isNull() | t.nextDueDate.isSmallerOrEqualValue(threshold),
      );
    }

    query.orderBy([
      (t) => OrderingTerm(
            expression: t.nextDueDate,
            nulls: NullsOrder.first,
          ),
    ]);

    return query.get();
  }

  Future<void> upsertFlashcardEntry(FlashcardsCompanion card) async {
    await into(flashcards).insertOnConflictUpdate(card);
    if (card.deckId.present) {
      await recalculateDeckStatsForId(card.deckId.value);
    }
  }

  Future<void> batchUpsertFlashcards(List<FlashcardsCompanion> cardsList) async {
    if (cardsList.isEmpty) return;
    final deckIds = <String>{};

    await batch((b) {
      b.insertAllOnConflictUpdate(flashcards, cardsList);
    });

    for (final card in cardsList) {
      if (card.deckId.present && card.deckId.value.isNotEmpty) {
        deckIds.add(card.deckId.value);
      }
    }

    for (final deckId in deckIds) {
      await recalculateDeckStatsForId(deckId);
    }
  }

  Future<void> batchUpsertDeckAndCardsTransaction(
    DecksCompanion deck,
    List<FlashcardsCompanion> cardsList,
  ) async {
    await transaction(() async {
      await into(decks).insertOnConflictUpdate(deck);
      if (cardsList.isNotEmpty) {
        await batch((b) {
          b.insertAllOnConflictUpdate(flashcards, cardsList);
        });
      }
    });

    if (deck.id.present) {
      await recalculateDeckStatsForId(deck.id.value);
    }
  }

  Future<void> recalculateDeckStatsForId(String deckId) async {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final allCards = await (select(flashcards)
          ..where((t) => t.deckId.equals(deckId)))
        .get();

    if (allCards.isEmpty) {
      await (update(decks)..where((t) => t.id.equals(deckId))).write(
        DecksCompanion(
          totalCards: const Value(0),
          dueCards: const Value(0),
          masteryRate: const Value(0),
          updatedAt: Value(now),
        ),
      );
      return;
    }

    final total = allCards.length;
    var dueCount = 0;
    var masteredCount = 0;

    for (final card in allCards) {
      if (card.repetitions >= 1) {
        masteredCount++;
      }
      final dueDate = card.nextDueDate;
      if (dueDate == null || !dueDate.isAfter(todayEnd)) {
        dueCount++;
      }
    }

    final masteryRate = total > 0 ? (masteredCount / total) : 0.0;

    await (update(decks)..where((t) => t.id.equals(deckId))).write(
      DecksCompanion(
        totalCards: Value(total),
        dueCards: Value(dueCount),
        masteryRate: Value(masteryRate),
        updatedAt: Value(now),
      ),
    );
  }

  // ==========================================
  // FTS5 SEARCH (FLASHCARDS)
  // ==========================================

  Future<List<FlashcardEntry>> searchCardsFts(
    String query, {
    String? deckId,
    int limit = 50,
  }) async {
    final sanitized = query.replaceAll('"', '""').trim();
    if (sanitized.isEmpty) return const [];

    try {
      final rows = await customSelect(
        '''
        SELECT f.* FROM flashcards f
        JOIN flashcards_fts fts ON fts.card_id = f.id
        WHERE flashcards_fts MATCH ?
        ${deckId != null ? 'AND f.deck_id = ?' : ''}
        ORDER BY rank
        LIMIT ?
        ''',
        variables: [
          Variable.withString('$sanitized*'),
          if (deckId != null) Variable.withString(deckId),
          Variable.withInt(limit),
        ],
        readsFrom: {flashcards},
      ).get();

      return rows.map((row) => flashcards.map(row.data)).toList();
    } on Object {
      // Fallback to LIKE if FTS5 virtual table is not present
      final likePattern = '%$query%';
      final q = select(flashcards)
        ..where(
          (t) =>
              t.front.like(likePattern) |
              t.back.like(likePattern) |
              t.sourceTopic.like(likePattern),
        );
      if (deckId != null) {
        q.where((t) => t.deckId.equals(deckId));
      }
      return q.get();
    }
  }

  // ==========================================
  // FSRS REVIEW LOGS OPERATIONS
  // ==========================================

  Future<void> insertReviewLogEntry(FsrsReviewLogsCompanion log) {
    return into(fsrsReviewLogs).insertOnConflictUpdate(log);
  }

  Future<List<FsrsReviewLogEntry>> getUnsyncedReviewLogs() {
    return (select(fsrsReviewLogs)
          ..where((t) => t.isSynced.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.reviewedAtUtc)]))
        .get();
  }

  Future<void> markReviewLogsSynced(List<String> transactionUuids) async {
    if (transactionUuids.isEmpty) return;
    await (update(fsrsReviewLogs)
          ..where((t) => t.transactionUuid.isIn(transactionUuids)))
        .write(const FsrsReviewLogsCompanion(isSynced: Value(true)));
  }

  Future<List<FsrsReviewLogEntry>> getAllReviewLogs() {
    return (select(fsrsReviewLogs)
          ..orderBy([(t) => OrderingTerm(expression: t.reviewedAtUtc)]))
        .get();
  }

  // ==========================================
  // PAST QUESTIONS OPERATIONS
  // ==========================================

  Future<int> countPastQuestions() async {
    final countExp = pastQuestions.id.count();
    final row = await (selectOnly(pastQuestions)..addColumns([countExp]))
        .getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<void> batchInsertPastQuestions(
    List<PastQuestionsCompanion> questionsList,
  ) async {
    if (questionsList.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(pastQuestions, questionsList);
    });
  }

  Future<List<PastQuestionEntry>> getPastQuestionsList({
    String? examType,
    String? subject,
    int? year,
    String? searchQuery,
    int limit = 100,
  }) async {
    final normalizedQuery = searchQuery?.trim();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      try {
        final sanitized = normalizedQuery.replaceAll('"', '""');
        final rows = await customSelect(
          '''
          SELECT p.* FROM past_questions p
          JOIN past_questions_fts fts ON fts.question_id = p.id
          WHERE past_questions_fts MATCH ?
          ${examType != null ? 'AND LOWER(p.exam_type) = LOWER(?)' : ''}
          ${subject != null && subject != 'all' ? 'AND LOWER(p.subject) = LOWER(?)' : ''}
          ${year != null ? 'AND p.year = ?' : ''}
          ORDER BY rank
          ${limit > 0 ? 'LIMIT ?' : ''}
          ''',
          variables: [
            Variable.withString('$sanitized*'),
            if (examType != null) Variable.withString(examType),
            if (subject != null && subject != 'all') Variable.withString(subject),
            if (year != null) Variable.withInt(year),
            if (limit > 0) Variable.withInt(limit),
          ],
          readsFrom: {pastQuestions},
        ).get();

        return rows.map((row) => pastQuestions.map(row.data)).toList();
      } on Object {
        // Fallback to standard query if FTS5 fails
      }
    }

    final query = select(pastQuestions);
    if (examType != null && examType.isNotEmpty) {
      query.where((t) => t.examType.lower().equals(examType.toLowerCase()));
    }
    if (subject != null && subject.isNotEmpty && subject.toLowerCase() != 'all') {
      query.where((t) => t.subject.lower().equals(subject.toLowerCase()));
    }
    if (year != null) {
      query.where((t) => t.year.equals(year));
    }
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      final pattern = '%$normalizedQuery%';
      query.where(
        (t) =>
            t.prompt.like(pattern) |
            t.explanation.like(pattern) |
            t.topic.like(pattern),
      );
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.year, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.questionNumber),
    ]);

    if (limit > 0) {
      query.limit(limit);
    }

    return query.get();
  }

  Future<List<String>> getAvailableSubjectsForExam(String examType) async {
    final query = selectOnly(pastQuestions, distinct: true)
      ..addColumns([pastQuestions.subject])
      ..where(pastQuestions.examType.lower().equals(examType.toLowerCase()))
      ..orderBy([
        OrderingTerm(expression: pastQuestions.subject),
      ]);

    final rows = await query.get();
    return rows
        .map((r) => r.read(pastQuestions.subject))
        .whereType<String>()
        .toList();
  }

  Future<List<int>> getAvailableYearsForExam(String examType) async {
    final query = selectOnly(pastQuestions, distinct: true)
      ..addColumns([pastQuestions.year])
      ..where(pastQuestions.examType.lower().equals(examType.toLowerCase()))
      ..orderBy([
        OrderingTerm(expression: pastQuestions.year, mode: OrderingMode.desc),
      ]);

    final rows = await query.get();
    return rows
        .map((r) => r.read(pastQuestions.year))
        .whereType<int>()
        .toList();
  }

  // ==========================================
  // COURSE MODULES OPERATIONS
  // ==========================================

  Future<List<CourseModuleEntry>> getAllCourseModules() {
    return (select(courseModules)
          ..orderBy([(t) => OrderingTerm(expression: t.title)]))
        .get();
  }

  Future<CourseModuleEntry?> getCourseModuleById(String id) {
    return (select(courseModules)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> batchUpsertCourseModules(
    List<CourseModulesCompanion> modulesList,
  ) {
    return batch((b) {
      b.insertAllOnConflictUpdate(courseModules, modulesList);
    });
  }

  Future<void> deleteCourseModuleById(String id) {
    return (delete(courseModules)..where((t) => t.id.equals(id))).go();
  }
}
