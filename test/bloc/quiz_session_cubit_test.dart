import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/generate_quiz_from_deck_use_case.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/submit_quiz_answers_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerateQuizFromDeckUseCase extends Mock
    implements GenerateQuizFromDeckUseCase {}

class MockSubmitQuizAnswersUseCase extends Mock
    implements SubmitQuizAnswersUseCase {}

void main() {
  group('QuizSessionCubit Test Suite', () {
    late MockGenerateQuizFromDeckUseCase mockGenerateUseCase;
    late MockSubmitQuizAnswersUseCase mockSubmitUseCase;
    late QuizSessionCubit cubit;

    const tQuestions = [
      QuizQuestionEntity(
        id: 'q-1',
        prompt: 'What is acceleration due to gravity on Earth?',
        type: QuizQuestionType.multipleChoice,
        options: ['9.8 m/s^2', '8.9 m/s^2', '10.8 m/s^2', '0 m/s^2'],
        correctAnswer: '9.8 m/s^2',
        explanation: 'Standard gravity is approximately 9.80665 m/s^2.',
        subTopic: 'Kinematics',
      ),
      QuizQuestionEntity(
        id: 'q-2',
        prompt: 'Is momentum conserved in an isolated system?',
        type: QuizQuestionType.trueFalse,
        options: ['True', 'False'],
        correctAnswer: 'True',
        explanation: 'Law of conservation of linear momentum.',
        subTopic: 'Momentum',
      ),
    ];

    const tResult = QuizResultEntity(
      id: 'res-1',
      quizTitle: 'Physics Mock',
      totalQuestions: 2,
      correctAnswers: 2,
      durationSeconds: 15,
      weaknesses: [],
    );

    setUp(() {
      mockGenerateUseCase = MockGenerateQuizFromDeckUseCase();
      mockSubmitUseCase = MockSubmitQuizAnswersUseCase();
      cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateUseCase,
        submitQuizUseCase: mockSubmitUseCase,
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initial state has initial status', () {
      expect(cubit.state.status, equals(QuizSessionStatus.initial));
    });

    blocTest<QuizSessionCubit, QuizSessionState>(
      'emits [loading, inProgress] when startQuizFromDeck succeeds',
      build: () {
        when(
          () => mockGenerateUseCase(
            deckId: 'deck-1',
            deckTitle: 'Physics Deck',
            questionCount: 2,
          ),
        ).thenAnswer((_) async => const Right(tQuestions));
        return cubit;
      },
      act: (cubit) => cubit.startQuizFromDeck(
        deckId: 'deck-1',
        deckTitle: 'Physics Deck',
        questionCount: 2,
      ),
      expect: () => [
        const QuizSessionState(
          status: QuizSessionStatus.loading,
          quizTitle: 'Physics Deck',
        ),
        isA<QuizSessionState>()
            .having((s) => s.status, 'status', QuizSessionStatus.inProgress)
            .having((s) => s.questions.length, 'questions length', 2)
            .having((s) => s.currentIndex, 'currentIndex', 0),
      ],
    );

    blocTest<QuizSessionCubit, QuizSessionState>(
      'emits [loading, error] when startQuizFromDeck fails',
      build: () {
        when(
          () => mockGenerateUseCase(
            deckId: 'deck-1',
            deckTitle: 'Physics Deck',
          ),
        ).thenAnswer(
          (_) async => const Left(
            ServerFailure(message: 'AI Generation Failed'),
          ),
        );
        return cubit;
      },
      act: (cubit) => cubit.startQuizFromDeck(
        deckId: 'deck-1',
        deckTitle: 'Physics Deck',
      ),
      expect: () => [
        const QuizSessionState(
          status: QuizSessionStatus.loading,
          quizTitle: 'Physics Deck',
        ),
        const QuizSessionState(
          status: QuizSessionStatus.error,
          quizTitle: 'Physics Deck',
          errorMessage: 'AI Generation Failed',
        ),
      ],
    );

    blocTest<QuizSessionCubit, QuizSessionState>(
      'selectOption marks question as answered and determines correctness',
      build: () {
        when(
          () => mockGenerateUseCase(
            deckId: 'deck-1',
            deckTitle: 'Physics Deck',
          ),
        ).thenAnswer((_) async => const Right(tQuestions));
        return cubit;
      },
      seed: () => const QuizSessionState(
        status: QuizSessionStatus.inProgress,
        questions: tQuestions,
      ),
      act: (cubit) => cubit.selectOption('9.8 m/s^2'),
      expect: () => [
        isA<QuizSessionState>()
            .having(
              (s) => s.status,
              'status',
              QuizSessionStatus.questionAnswered,
            )
            .having(
              (s) => s.questions[0].isCorrect,
              'isCorrect',
              isTrue,
            )
            .having(
              (s) => s.questions[0].userSelectedAnswer,
              'userSelectedAnswer',
              '9.8 m/s^2',
            ),
      ],
    );

    blocTest<QuizSessionCubit, QuizSessionState>(
      'submitQuiz transitions to completed state with result',
      build: () {
        when(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).thenAnswer((_) async => const Right(tResult));
        return cubit;
      },
      seed: () => const QuizSessionState(
        status: QuizSessionStatus.questionAnswered,
        questions: tQuestions,
        currentIndex: 1,
        elapsedSeconds: 15,
      ),
      act: (cubit) => cubit.submitQuiz(),
      expect: () => [
        isA<QuizSessionState>()
            .having((s) => s.status, 'status', QuizSessionStatus.loading),
        isA<QuizSessionState>()
            .having((s) => s.status, 'status', QuizSessionStatus.completed)
            .having((s) => s.result?.correctAnswers, 'correctAnswers', 2),
      ],
    );
  });
}
