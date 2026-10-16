import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/exam_question_selector.dart';
import 'package:kortex/src/features/quiz/domain/logic/exam_simulation_config.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';

void main() {
  group('P2-04: Non-Lossy QuizContentSanitizer', () {
    test('preserves scientific terms without option prefixes', () {
      expect(QuizContentSanitizer.cleanOptionText('E. coli'), 'E. coli');
      expect(QuizContentSanitizer.cleanOptionText('B. subtilis'), 'B. subtilis');
      expect(QuizContentSanitizer.cleanOptionText('C. elegans'), 'C. elegans');
      expect(QuizContentSanitizer.cleanOptionText('S. cerevisiae'), 'S. cerevisiae');
      expect(QuizContentSanitizer.cleanOptionText('pH level'), 'pH level');
      expect(QuizContentSanitizer.cleanOptionText('pOH scale'), 'pOH scale');
      expect(QuizContentSanitizer.cleanOptionText('pKa value'), 'pKa value');
      expect(QuizContentSanitizer.cleanOptionText('e.g. bacteria'), 'e.g. bacteria');
      expect(QuizContentSanitizer.cleanOptionText('i.e. model organism'), 'i.e. model organism');
    });

    test('strips option prefix without damaging trailing scientific term', () {
      expect(QuizContentSanitizer.cleanOptionText('A. E. coli'), 'E. coli');
      expect(QuizContentSanitizer.cleanOptionText('(B) E. coli'), 'E. coli');
      expect(QuizContentSanitizer.cleanOptionText('[C] B. subtilis'), 'B. subtilis');
      expect(QuizContentSanitizer.cleanOptionText('D) C. elegans'), 'C. elegans');
      expect(QuizContentSanitizer.cleanOptionText('A. pH of the solution'), 'pH of the solution');
      expect(QuizContentSanitizer.cleanOptionText('B. pKa determination'), 'pKa determination');
    });

    test('cleanly strips standard option prefixes from ordinary options', () {
      expect(QuizContentSanitizer.cleanOptionText('A. Photosynthesis'), 'Photosynthesis');
      expect(QuizContentSanitizer.cleanOptionText('b. Cellular respiration'), 'Cellular respiration');
      expect(QuizContentSanitizer.cleanOptionText('(C) Mitochondria'), 'Mitochondria');
      expect(QuizContentSanitizer.cleanOptionText('[D] Ribosomes'), 'Ribosomes');
      expect(QuizContentSanitizer.cleanOptionText('E) Endoplasmic reticulum'), 'Endoplasmic reticulum');
      expect(QuizContentSanitizer.cleanOptionText('  (A)  Nucleus  '), 'Nucleus');
    });

    test('handles empty or malformed inputs gracefully', () {
      expect(QuizContentSanitizer.cleanOptionText(''), '');
      expect(QuizContentSanitizer.cleanOptionText('   '), '');
      expect(QuizContentSanitizer.cleanOptionText('A.'), '');
      expect(QuizContentSanitizer.cleanOptionText('(B)'), '');
    });
  });

  group('P2-04: Unified Answer Matching (isAnswerMatching)', () {
    test('matches single letter option to letter or prefixed option', () {
      expect(QuizContentSanitizer.isAnswerMatching('A', 'A'), isTrue);
      expect(QuizContentSanitizer.isAnswerMatching('a', 'A'), isTrue);
      expect(QuizContentSanitizer.isAnswerMatching('A', 'A. Mitochondria'), isTrue);
      expect(QuizContentSanitizer.isAnswerMatching('B', '(B) Ribosome'), isTrue);
      expect(QuizContentSanitizer.isAnswerMatching('C', '[C] Chloroplast'), isTrue);
      expect(QuizContentSanitizer.isAnswerMatching('A', 'B'), isFalse);
    });

    test('matches full option text against stripped or full correct answer', () {
      expect(
        QuizContentSanitizer.isAnswerMatching(
          'Mitochondria',
          'A. Mitochondria',
        ),
        isTrue,
      );
      expect(
        QuizContentSanitizer.isAnswerMatching(
          'A. Mitochondria',
          'Mitochondria',
        ),
        isTrue,
      );
      expect(
        QuizContentSanitizer.isAnswerMatching(
          '(B) E. coli',
          'E. coli',
        ),
        isTrue,
      );
      expect(
        QuizContentSanitizer.isAnswerMatching(
          'E. coli',
          '(B) E. coli',
        ),
        isTrue,
      );
      expect(
        QuizContentSanitizer.isAnswerMatching(
          'Mitochondria',
          'Ribosome',
        ),
        isFalse,
      );
    });

    test('handles whitespace and casing insensitively', () {
      expect(
        QuizContentSanitizer.isAnswerMatching(
          '  photosynthesis  ',
          'PHOTOSYNTHESIS',
        ),
        isTrue,
      );
      expect(
        QuizContentSanitizer.isAnswerMatching(
          'a. e. coli',
          'A. E. COLI',
        ),
        isTrue,
      );
    });

    test('returns false for null inputs', () {
      expect(QuizContentSanitizer.isAnswerMatching(null, 'A'), isFalse);
      expect(QuizContentSanitizer.isAnswerMatching('A', null), isFalse);
      expect(QuizContentSanitizer.isAnswerMatching(null, null), isFalse);
    });
  });

  group('P2-04: ExamSimulationConfig', () {
    test('provides official defaults for major exam categories', () {
      expect(ExamSimulationConfig.jamb().durationMinutes, 120);
      expect(ExamSimulationConfig.jamb().totalQuestions, 180);
      expect(ExamSimulationConfig.jamb().singleSubjectDurationMinutes, 40);
      expect(ExamSimulationConfig.jamb().singleSubjectQuestions, 40);

      expect(ExamSimulationConfig.waec().durationMinutes, 60);
      expect(ExamSimulationConfig.waec().totalQuestions, 50);

      expect(ExamSimulationConfig.neco().durationMinutes, 60);
      expect(ExamSimulationConfig.neco().totalQuestions, 60);

      expect(ExamSimulationConfig.sat().durationMinutes, 134);
      expect(ExamSimulationConfig.sat().totalQuestions, 54);
    });

    test('resolves config from string identifiers correctly', () {
      expect(ExamSimulationConfig.fromString('JAMB').examName, 'JAMB / UTME');
      expect(ExamSimulationConfig.fromString('utme').examName, 'JAMB / UTME');
      expect(ExamSimulationConfig.fromString('WAEC').examName, 'WAEC / WASSCE');
      expect(ExamSimulationConfig.fromString('wassce').examName, 'WAEC / WASSCE');
      expect(ExamSimulationConfig.fromString('NECO').examName, 'NECO / SSCE');
      expect(ExamSimulationConfig.fromString('ssce').examName, 'NECO / SSCE');
      expect(ExamSimulationConfig.fromString('SAT').examName, 'SAT');
      expect(ExamSimulationConfig.fromString('unknown_exam').examName, 'General Studies');
    });

    test('calculates single-subject and multi-subject limits correctly', () {
      final jamb = ExamSimulationConfig.jamb();
      expect(jamb.getQuestionsForSubjectCount(1), 40);
      expect(jamb.getQuestionsForSubjectCount(4), 180);
      expect(jamb.getDurationMinutesForSubjectCount(1), 40);
      expect(jamb.getDurationMinutesForSubjectCount(4), 120);

      final waec = ExamSimulationConfig.waec();
      expect(waec.getQuestionsForSubjectCount(1), 50);
      expect(waec.getQuestionsForSubjectCount(3), 50);
      expect(waec.getDurationMinutesForSubjectCount(1), 60);
    });
  });

  group('P2-04: ExamQuestionSelector (Deterministic & Adaptive)', () {
    final sampleQuestions = List.generate(20, (i) {
      return PastQuestionEntity(
        id: 'q_$i',
        examType: ExamCategory.jamb,
        subject: 'Biology',
        year: 2024,
        questionNumber: i + 1,
        prompt: 'Question $i text',
        options: const ['Option A', 'Option B', 'Option C', 'Option D'],
        correctOptionIndex: 0,
        correctOptionLabel: 'A',
        explanation: 'Explanation $i',
        topic: i < 5 ? 'Cell Biology' : (i < 10 ? 'Genetics' : 'Ecology'),
      );
    });

    test('seeded selection is 100% deterministic and reproducible', () {
      final run1 = ExamQuestionSelector.selectPastQuestions(
        pool: sampleQuestions,
        count: 10,
        seed: 42,
      );
      final run2 = ExamQuestionSelector.selectPastQuestions(
        pool: sampleQuestions,
        count: 10,
        seed: 42,
      );

      expect(run1.map((q) => q.id).toList(), run2.map((q) => q.id).toList());

      final runDifferentSeed = ExamQuestionSelector.selectPastQuestions(
        pool: sampleQuestions,
        count: 10,
        seed: 9999,
      );
      expect(
        run1.map((q) => q.id).toList(),
        isNot(equals(runDifferentSeed.map((q) => q.id).toList())),
      );
    });

    test('prioritizes unseen weak topic questions over general unseen questions', () {
      final seenIds = sampleQuestions.take(10).map((q) => q.id).toSet();
      final selected = ExamQuestionSelector.selectPastQuestions(
        pool: sampleQuestions,
        count: 5,
        seenQuestionIds: seenIds,
        weakSubtopics: {'Ecology'},
        seed: 123,
      );

      for (final q in selected) {
        expect(seenIds.contains(q.id), isFalse);
        expect(q.topic, 'Ecology');
      }
    });

    test('prioritizes historical errors before mastered questions when seen', () {
      final seenIds = sampleQuestions.map((q) => q.id).toSet();
      final errorIds = {'q_2', 'q_7'};

      final selected = ExamQuestionSelector.selectPastQuestions(
        pool: sampleQuestions,
        count: 5,
        seenQuestionIds: seenIds,
        historicalErrorIds: errorIds,
        seed: 456,
      );

      final selectedIds = selected.map((q) => q.id).toList();
      expect(selectedIds.contains('q_2'), isTrue);
      expect(selectedIds.contains('q_7'), isTrue);
      expect(selectedIds.indexOf('q_2'), lessThan(3));
      expect(selectedIds.indexOf('q_7'), lessThan(3));
    });

    test('selectQuizQuestions works with QuizQuestionEntity pool', () {
      final quizPool = sampleQuestions.map(QuizQuestionEntity.fromPastQuestion).toList();
      final selected = ExamQuestionSelector.selectQuizQuestions(
        pool: quizPool,
        count: 7,
        seed: 777,
      );

      expect(selected.length, 7);
      expect(selected.toSet().length, 7);
    });

    test('respects count limits smaller or larger than pool', () {
      final selectedSmall = ExamQuestionSelector.selectPastQuestions(
        pool: sampleQuestions,
        count: 3,
        seed: 1,
      );
      expect(selectedSmall.length, 3);

      final selectedLarge = ExamQuestionSelector.selectPastQuestions(
        pool: sampleQuestions,
        count: 100,
        seed: 1,
      );
      expect(selectedLarge.length, sampleQuestions.length);
    });
  });

  group('P2-04: Question Count Clamping in Config Sheet', () {
    List<int> computeSelectableCounts(int availableCount) {
      final rawCounts = [5, 10, 20, 40]
          .where((c) => c <= availableCount)
          .toList();
      if (!rawCounts.contains(availableCount) &&
          availableCount > 0 &&
          availableCount < 40) {
        rawCounts.add(availableCount);
      }
      return rawCounts.isEmpty
          ? [if (availableCount > 0) availableCount else 5]
          : (rawCounts..sort());
    }

    test('clamps strictly to availableCount when fewer than 5 exist', () {
      final countsFor3 = computeSelectableCounts(3);
      expect(countsFor3, [3]);
      expect(countsFor3.contains(10), isFalse);
      expect(countsFor3.contains(5), isFalse);

      final countsFor1 = computeSelectableCounts(1);
      expect(countsFor1, [1]);
    });

    test('includes availableCount when between standard tiers', () {
      final countsFor8 = computeSelectableCounts(8);
      expect(countsFor8, [5, 8]);
      expect(countsFor8.contains(10), isFalse);

      final countsFor15 = computeSelectableCounts(15);
      expect(countsFor15, [5, 10, 15]);
      expect(countsFor15.contains(20), isFalse);

      final countsFor35 = computeSelectableCounts(35);
      expect(countsFor35, [5, 10, 20, 35]);
      expect(countsFor35.contains(40), isFalse);
    });

    test('returns standard tiers when availableCount is 40 or greater', () {
      final countsFor40 = computeSelectableCounts(40);
      expect(countsFor40, [5, 10, 20, 40]);

      final countsFor100 = computeSelectableCounts(100);
      expect(countsFor100, [5, 10, 20, 40]);
    });
  });
}
