import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/convert_failed_quiz_to_deck_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockDecksRemoteDataSource extends Mock implements DecksRemoteDataSource {}
class FakeDeckModel extends Fake implements DeckModel {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDeckModel());
  });

  late MockDecksRemoteDataSource mockDecksDataSource;
  late ConvertFailedQuizToDeckUseCase useCase;

  setUp(() {
    mockDecksDataSource = MockDecksRemoteDataSource();
    useCase = ConvertFailedQuizToDeckUseCase(mockDecksDataSource);
  });

  const tQuestions = [
    QuizQuestionEntity(
      id: 'q1',
      prompt: 'What is O(1) time complexity?',
      type: QuizQuestionType.multipleChoice,
      options: ['Constant', 'Linear', 'Quadratic', 'Logarithmic'],
      correctAnswer: 'Constant',
      userSelectedAnswer: 'Linear',
      explanation: 'O(1) means execution time remains constant.',
      subTopic: 'Algorithms',
      isAnswered: true,
    ),
    QuizQuestionEntity(
      id: 'q2',
      prompt: 'What is 2 + 2?',
      type: QuizQuestionType.multipleChoice,
      options: ['3', '4', '5', '6'],
      correctAnswer: '4',
      userSelectedAnswer: '4',
      explanation: 'Basic math',
      subTopic: 'Arithmetic',
      isAnswered: true,
      isCorrect: true,
    ),
  ];

  const tResult = QuizResultEntity(
    id: 'quiz_123',
    quizTitle: 'Computer Science 101 CBT',
    durationSeconds: 120,
    correctAnswers: 1,
    totalQuestions: 2,
    weaknesses: [
      TopicWeakness(
        subTopic: 'Algorithms',
        correctCount: 0,
        totalQuestions: 1,
      ),
    ],
  );

  test('successfully converts failed questions into a practice flashcard deck', () async {
    when(
      () => mockDecksDataSource.saveGeneratedDeck(
        deck: any(named: 'deck'),
        cards: any(named: 'cards'),
      ),
    ).thenAnswer((_) async {});

    final either = await useCase(
      result: tResult,
      questions: tQuestions,
      courseId: 'course_cs101',
      courseCode: 'CS101',
    );

    expect(either.isRight, isTrue);
    final deck = either.fold((l) => throw Exception(), (r) => r);
    expect(deck.courseCode, equals('CS101'));
    expect(deck.title, contains('CS101 CBT Practice Deck'));
    // Only 1 question was incorrect
    expect(deck.cards.length, equals(1));
    expect(deck.cards.first.front, equals('What is O(1) time complexity?'));
    expect(deck.cards.first.back, contains('Constant'));
    expect(deck.cards.first.back, contains('💡 Explanation:'));

    verify(
      () => mockDecksDataSource.saveGeneratedDeck(
        deck: any(named: 'deck'),
        cards: any(named: 'cards'),
      ),
    ).called(1);
  });

  test('returns failure when no questions and no weaknesses exist', () async {
    const emptyResult = QuizResultEntity(
      id: 'q_empty',
      quizTitle: 'Empty Quiz',
      durationSeconds: 10,
      correctAnswers: 0,
      totalQuestions: 0,
      weaknesses: [],
    );

    final either = await useCase(
      result: emptyResult,
      questions: const [],
    );

    expect(either.isLeft, isTrue);
    verifyNever(
      () => mockDecksDataSource.saveGeneratedDeck(
        deck: any(named: 'deck'),
        cards: any(named: 'cards'),
      ),
    );
  });
}
