import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
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

class MockCardSyncQueue extends Mock implements CardSyncQueue {}

class MockDecksRepository extends Mock implements DecksRepository {}

class FakeFsrsReviewLog extends Fake implements FsrsReviewLog {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeFsrsReviewLog());
  });

  group('QuizSessionCubit Test Suite', () {
    late MockGenerateQuizFromDeckUseCase mockGenerateUseCase;
    late MockSubmitQuizAnswersUseCase mockSubmitUseCase;
    late MockCardSyncQueue mockCardSyncQueue;
    late MockDecksRepository mockDecksRepository;
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
      mockCardSyncQueue = MockCardSyncQueue();
      mockDecksRepository = MockDecksRepository();

      when(() => mockCardSyncQueue.enqueueReview(any(), flushImmediately: any(named: 'flushImmediately')))
          .thenAnswer((_) async {});

      cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateUseCase,
        submitQuizUseCase: mockSubmitUseCase,
        decksRepository: mockDecksRepository,
        cardSyncQueue: mockCardSyncQueue,
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
        isA<QuizSessionState>().having(
          (s) => s.status,
          'status',
          QuizSessionStatus.loading,
        ),
        isA<QuizSessionState>()
            .having((s) => s.status, 'status', QuizSessionStatus.completed)
            .having((s) => s.result?.correctAnswers, 'correctAnswers', 2),
      ],
    );

    group('Millionaire Ascent Mode (ADHD Gamified Quiz)', () {
      test('startMillionaireQuiz sets up millionaire mode, 3 lifelines, and Tier 1', () {
        cubit.startMillionaireQuiz(
          title: 'Physics Ascent',
          questions: tQuestions,
        );

        expect(cubit.state.assessmentMode, equals(AssessmentMode.millionaireMode));
        expect(cubit.state.currentTier, equals(1));
        expect(cubit.state.bankedTier, equals(0));
        expect(cubit.state.isLifelineAvailable(LifelineType.fiftyFifty), isTrue);
        expect(cubit.state.isLifelineAvailable(LifelineType.aiClue), isTrue);
        expect(cubit.state.isLifelineAvailable(LifelineType.skipSwap), isTrue);
        expect(cubit.state.status, equals(QuizSessionStatus.inProgress));
      });

      test('useLifeline(fiftyFifty) eliminates exactly 2 incorrect options', () {
        cubit
          ..startMillionaireQuiz(
            title: 'Physics Ascent',
            questions: tQuestions,
          )
          ..useLifeline(LifelineType.fiftyFifty);

        expect(cubit.state.isLifelineAvailable(LifelineType.fiftyFifty), isFalse);
        expect(cubit.state.eliminatedOptionIndices.length, equals(2));
        expect(cubit.state.eliminatedOptionIndices.contains(0), isFalse);
      });

      test('useLifeline(aiClue) sets activeClueText from explanation', () {
        cubit
          ..startMillionaireQuiz(
            title: 'Physics Ascent',
            questions: tQuestions,
          )
          ..useLifeline(LifelineType.aiClue);

        expect(cubit.state.isLifelineAvailable(LifelineType.aiClue), isFalse);
        expect(cubit.state.activeClueText, isNotEmpty);
      });

      test('useLifeline(askAudience) computes distribution and disables lifeline', () {
        cubit
          ..startMillionaireQuiz(
            title: 'Physics Ascent',
            questions: tQuestions,
          )
          ..useLifeline(LifelineType.askAudience);

        expect(cubit.state.isLifelineAvailable(LifelineType.askAudience), isFalse);
        expect(cubit.state.audienceDistribution, isNotNull);
        expect(cubit.state.audienceDistribution!.containsKey('A'), isTrue);
        expect(cubit.state.audienceDistribution!['A'], greaterThan(30));
      });

      test('startMillionaireArcade initializes arcade mode with global scope', () async {
        when(() => mockDecksRepository.getUserDecks())
            .thenAnswer((_) async => const Right([]));

        await cubit.startMillionaireArcade();

        expect(cubit.state.assessmentMode, equals(AssessmentMode.millionaireMode));
        expect(cubit.state.millionaireScope, equals(MillionaireScope.globalArcade));
        expect(cubit.state.questions.length, equals(12));
        expect(cubit.state.status, equals(QuizSessionStatus.inProgress));
      });

      test('startMillionaireQuiz sets courseTied scope by default', () {
        cubit.startMillionaireQuiz(
          title: 'Unit 1 Mastery',
          questions: tQuestions,
        );

        expect(cubit.state.millionaireScope, equals(MillionaireScope.courseTied));
        expect(cubit.state.quizTitle, equals('Unit 1 Mastery'));
      });

      test('correct answer at safe checkpoint banks the tier', () {
        final twelveQuestions = List.generate(
          12,
          (i) => QuizQuestionEntity(
            id: 'tier-q-$i',
            prompt: 'Question $i',
            type: QuizQuestionType.multipleChoice,
            options: const ['Correct', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
            correctAnswer: 'Correct',
            explanation: 'Exp $i',
            subTopic: 'Physics',
          ),
        );

        cubit
          ..startMillionaireQuiz(
            title: 'Checkpoint Ascent',
            questions: twelveQuestions,
          )
          ..jumpToQuestion(3);

        expect(cubit.state.currentTier, equals(4));
        expect(cubit.state.bankedTier, equals(0));

        cubit.selectOption('Correct');

        expect(cubit.state.bankedTier, equals(4));
      });

      test('incorrect answer enqueues FSRS review log with rating again', () {
        cubit
          ..startMillionaireQuiz(
            title: 'Physics Ascent',
            questions: tQuestions,
          )
          ..selectOption('Wrong answer');

        verify(() => mockCardSyncQueue.enqueueReview(any())).called(1);
      });

      test('walkAwayAndBank submits quiz with banked XP', () async {
        when(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).thenAnswer((_) async => const Right(tResult));

        cubit.startMillionaireQuiz(
          title: 'Physics Ascent',
          questions: tQuestions,
        );

        await cubit.walkAwayAndBank();

        expect(cubit.state.isWalkedAway, isTrue);
        verify(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).called(1);
      });
    });
  });
}
