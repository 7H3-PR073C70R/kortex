import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/decks/domain/services/past_question_deck_factory.dart';
import 'package:kortex/src/features/decks/presentation/widgets/flashcard_gesture_canvas.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_local_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockPastQuestionsLocalDataSource extends Mock
    implements PastQuestionsLocalDataSource {}

void main() {
  late MockPastQuestionsLocalDataSource mockDataSource;
  late PastQuestionDeckFactory factory;

  setUp(() {
    mockDataSource = MockPastQuestionsLocalDataSource();
    factory = PastQuestionDeckFactory(
      pastQuestionsLocalDataSource: mockDataSource,
    );
  });

  const tQuestion = PastQuestionModel(
    id: 'pq_chem_1993_271',
    examType: ExamCategory.waec,
    subject: 'Chemistry',
    year: 1993,
    questionNumber: 271,
    prompt: 'Copper metal will react with concentrated trioxonitrate (V) acid to give?',
    options: [
      'A. Cu(NO 3 ) 3 + NO + N 2 O 4 + H 2 O',
      'B. Cu(NO 3 ) 2 + NO + H 2 O',
      'C. CuO + NO 2 + H 2 O',
      'D. Cu(NO 3 ) 2 + 2NO 2 + 2H 2 O',
    ],
    correctOptionIndex: 3,
    correctOptionLabel: 'D',
    explanation: 'Copper metal reacts with concentrated nitric acid to produce copper(II) nitrate.',
    topic: 'Acids, Bases & Salts',
  );

  group('PastQuestionDeckFactory Flashcard Generation', () {
    test('places question prompt and options on card front without repeating prefixes', () async {
      when(() => mockDataSource.isInitialized).thenReturn(true);
      when(() => mockDataSource.initialize()).thenAnswer((_) async {});
      when(
        () => mockDataSource.getPastQuestions(
          examCategory: any(named: 'examCategory'),
          subject: any(named: 'subject'),
          courseId: any(named: 'courseId'),
          courseCode: any(named: 'courseCode'),
          year: any(named: 'year'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [tQuestion]);

      final decks = await factory.generateCanonicalDecksForCourses(
        courses: const [
          CuratedCourseModel(
            id: 'c1',
            courseCode: 'CHM101',
            title: 'Chemistry',
            department: 'Science',
            totalMaterials: 5,
            hasActivePastPapers: true,
            iconName: 'science',
            colorHex: '#00FF00',
          ),
        ],
        track: 'WAEC',
      );

      expect(decks.isNotEmpty, isTrue);
      final card = decks.first.cards.first;

      // 1. Front contains prompt and Options A, B, C, D
      expect(card.front, contains('Copper metal will react with concentrated trioxonitrate (V) acid to give?'));
      expect(card.front, contains('**Options:**'));
      expect(card.front, contains(r'• A. $\mathrm{Cu(NO_3)_3 + NO + N_2O_4 + H_2O}$'));
      expect(card.front, contains(r'• B. $\mathrm{Cu(NO_3)_2 + NO + H_2O}$'));
      expect(card.front, contains(r'• C. $\mathrm{CuO + NO_2 + H_2O}$'));
      expect(card.front, contains(r'• D. $\mathrm{Cu(NO_3)_2 + 2NO_2 + 2H_2O}$'));

      // 2. Front must NOT duplicate letters like "A. A."
      expect(card.front.contains('A. A.'), isFalse);
      expect(card.front.contains('D. D.'), isFalse);

      // 3. Front must NOT leak the answer checkmark
      expect(card.front.contains('✅'), isFalse);

      // 4. Back contains correct answer and explanation, but NOT the options list
      expect(card.back, contains(r'**Correct Answer:** Option D — $\mathrm{Cu(NO_3)_2 + 2NO_2 + 2H_2O}$'));
      expect(card.back, contains('**Explanation:**\nCopper metal reacts with concentrated nitric acid to produce copper(II) nitrate.'));
      expect(card.back.contains('**Options:**'), isFalse);
      expect(card.back.contains('• A.'), isFalse);
    });
  });

  group('FlashcardGestureCanvas.resolveCardFaces dynamic migration', () {
    test('migrates legacy cards with options on back to show options on front and answer on back', () {
      const legacyFront = 'Copper metal will react with concentrated trioxonitrate (V) acid to give?';
      const legacyBack = '''
Options:
• A. A. Cu(NO 3 ) 3 + NO + N 2 O 4 + H 2 O
• B. B. Cu(NO 3 ) 2 + NO + H 2 O
• C. C. CuO + NO 2 + H 2 O
✅ D. D. Cu(NO 3 ) 2 + 2NO 2 + 2H 2 O

Correct Answer: Option D

Explanation:
Copper metal reacts with concentrated nitric acid in a redox reaction.
''';

      final (resolvedFront, resolvedBack) =
          FlashcardGestureCanvas.resolveCardFaces(legacyFront, legacyBack);

      // Front should now display the cleaned options without duplicates or checkmarks
      expect(resolvedFront, contains('Copper metal will react with concentrated trioxonitrate (V) acid to give?'));
      expect(resolvedFront, contains('**Options:**'));
      expect(resolvedFront, contains('• A. Cu(NO 3 ) 3 + NO + N 2 O 4 + H 2 O'));
      expect(resolvedFront, contains('• D. Cu(NO 3 ) 2 + 2NO 2 + 2H 2 O'));
      expect(resolvedFront.contains('A. A.'), isFalse);
      expect(resolvedFront.contains('✅'), isFalse);

      // Back should remove the options list and present the correct answer + explanation
      expect(resolvedBack.contains('• A.'), isFalse);
      expect(resolvedBack.contains('✅'), isFalse);
      expect(resolvedBack, contains('Correct Answer: Option D — Cu(NO 3 ) 2 + 2NO 2 + 2H 2 O'));
      expect(resolvedBack, contains('Explanation:\nCopper metal reacts with concentrated nitric acid'));
    });

    test('leaves non-legacy cards untouched if front already contains options', () {
      const normalFront = 'Prompt\n\n**Options:**\n• A. First\n• B. Second';
      const normalBack = '**Correct Answer:** Option A\n\n**Explanation:** Detail';

      final (resolvedFront, resolvedBack) =
          FlashcardGestureCanvas.resolveCardFaces(normalFront, normalBack);

      expect(resolvedFront, equals(normalFront));
      expect(resolvedBack, equals(normalBack));
    });
  });
}
