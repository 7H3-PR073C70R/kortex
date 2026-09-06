import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';
import 'package:kortex/src/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockDecksRepository extends Mock implements DecksRepository {}

class MockIngestionRepository extends Mock implements IngestionRepository {}

class MockStudyEngineRouter extends Mock implements StudyEngineRouter {}

class MockDio extends Mock implements Dio {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockUserActivityService extends Mock implements UserActivityService {}

class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  group('QuizRepositoryImpl Dynamic AI Generation Suite', () {
    late MockDecksRepository mockDecksRepo;
    late MockIngestionRepository mockIngestionRepo;
    late MockStudyEngineRouter mockEngineRouter;
    late MockDio mockDio;
    late MockLocalStorageService mockLocalStorage;
    late MockUserActivityService mockUserActivity;
    late MockUserStorageService mockUserStorage;
    late QuizRepositoryImpl repository;

    setUp(() {
      mockDecksRepo = MockDecksRepository();
      mockIngestionRepo = MockIngestionRepository();
      mockEngineRouter = MockStudyEngineRouter();
      mockDio = MockDio();
      mockLocalStorage = MockLocalStorageService();
      mockUserActivity = MockUserActivityService();
      mockUserStorage = MockUserStorageService();

      when(() => mockLocalStorage.getPreference(key: any(named: 'key')))
          .thenReturn(null);
      when(
        () => mockLocalStorage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockUserActivity.recordStudySession(
          cardsReviewed: any(named: 'cardsReviewed'),
          durationSeconds: any(named: 'durationSeconds'),
          retentionScore: any(named: 'retentionScore'),
          masteredCards: any(named: 'masteredCards'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockUserStorage.getToken()).thenReturn(null);
      when(() => mockUserStorage.getUserId()).thenReturn(null);

      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/rest/v1/quizzes'),
          statusCode: 201,
        ),
      );

      repository = QuizRepositoryImpl(
        decksRepository: mockDecksRepo,
        ingestionRepository: mockIngestionRepo,
        studyEngineRouter: mockEngineRouter,
        dio: mockDio,
        localStorageService: mockLocalStorage,
        userActivityService: mockUserActivity,
        userStorageService: mockUserStorage,
      );
    });

    test('generateQuizFromDeck parses questions from remote AI API', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/functions/v1/generate-quiz-questions'),
          data: {
            'quiz_title': 'Advanced Electromagnetism',
            'questions': [
              {
                'id': 'ai_q_1',
                'question': 'What is Faraday law of induction?',
                'options': [
                  r'\mathcal{E} = -\frac{d\Phi_B}{dt}',
                  r'\mathcal{E} = \frac{d\Phi_B}{dt}',
                  r'F = q(E + v \times B)',
                  r'\nabla \cdot B = 0',
                ],
                'correct_index': 0,
                'correct_answer': r'\mathcal{E} = -\frac{d\Phi_B}{dt}',
                'explanation': 'The induced EMF is equal to the negative rate of magnetic flux change.',
                'sub_topic': 'Electromagnetism',
                'latex_formula': r'\mathcal{E} = -\frac{d\Phi_B}{dt}',
              },
            ],
          },
        ),
      );

      final result = await repository.generateQuizFromDeck(
        deckId: 'deck_physics_101',
        deckTitle: 'Advanced Electromagnetism',
        questionCount: 1,
      );

      expect(result.isRight, isTrue);
      final questions = (result as Right).value as List<QuizQuestionEntity>;
      expect(questions.length, 1);
      expect(questions.first.id, 'ai_q_1');
      expect(questions.first.prompt, 'What is Faraday law of induction?');
      expect(questions.first.correctAnswer, r'\mathcal{E} = -\frac{d\Phi_B}{dt}');
      expect(questions.first.subTopic, 'Electromagnetism');
    });

    test('generateQuizFromDeck falls back to deck flashcards when remote AI fails', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/functions/v1/generate-quiz-questions'),
          type: DioExceptionType.connectionError,
        ),
      );

      final deckCards = [
        const FlashcardEntity(
          id: 'card_1',
          deckId: 'deck_bio_1',
          front: 'Mitochondria',
          back: 'The powerhouse of the eukaryotic cell producing ATP',
          sourceTopic: 'Cell Biology',
        ),
        const FlashcardEntity(
          id: 'card_2',
          deckId: 'deck_bio_1',
          front: 'Ribosome',
          back: 'Site of biological protein synthesis',
          sourceTopic: 'Cell Biology',
        ),
      ];

      when(() => mockDecksRepo.getDeckCards('deck_bio_1'))
          .thenAnswer((_) async => Right(deckCards));

      when(
        () => mockEngineRouter.processDirectAsset(
          assetId: any(named: 'assetId'),
          content: any(named: 'content'),
          topic: any(named: 'topic'),
          count: any(named: 'count'),
        ),
      ).thenAnswer(
        (_) async => const StudyPackResult(
          cards: [],
          executionMode: StudyEngineExecutionMode.unavailable,
          isOfflineModelMissing: true,
        ),
      );

      final result = await repository.generateQuizFromDeck(
        deckId: 'deck_bio_1',
        deckTitle: 'Cell Biology Deck',
        questionCount: 2,
      );

      expect(result.isRight, isTrue);
      final questions = (result as Right).value as List<QuizQuestionEntity>;
      expect(questions.length, 2);
      expect(questions.first.correctAnswer, 'The powerhouse of the eukaryotic cell producing ATP');
      expect(questions.first.options.length, 4);
      expect(questions.first.options, contains('The powerhouse of the eukaryotic cell producing ATP'));
    });

    test('generateQuizFromDocument parses questions from remote AI API', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/functions/v1/generate-quiz-questions'),
          data: {
            'quiz_title': 'Calculus Notes',
            'questions': [
              {
                'id': 'doc_q_1',
                'question': 'What is the limit of sin(x)/x as x approaches 0?',
                'options': ['1', '0', 'Infinity', 'Undefined'],
                'correct_index': 0,
                'correct_answer': '1',
                'explanation': 'A fundamental trigonometric limit proven by the squeeze theorem.',
                'sub_topic': 'Limits',
              },
            ],
          },
        ),
      );

      final result = await repository.generateQuizFromDocument(
        documentId: 'doc_calculus_pdf',
        questionCount: 1,
      );

      expect(result.isRight, isTrue);
      final questions = (result as Right).value as List<QuizQuestionEntity>;
      expect(questions.length, 1);
      expect(questions.first.id, 'doc_q_1');
      expect(questions.first.prompt, 'What is the limit of sin(x)/x as x approaches 0?');
      expect(questions.first.correctAnswer, '1');
    });

    test('submitQuizAnswers calculates scores and topic weaknesses accurately', () async {
      final questions = [
        const QuizQuestionEntity(
          id: 'q1',
          prompt: 'Q1',
          type: QuizQuestionType.multipleChoice,
          options: ['A', 'B'],
          correctAnswer: 'A',
          explanation: 'Exp',
          subTopic: 'Thermodynamics',
          isAnswered: true,
          isCorrect: true,
        ),
        const QuizQuestionEntity(
          id: 'q2',
          prompt: 'Q2',
          type: QuizQuestionType.multipleChoice,
          options: ['A', 'B'],
          correctAnswer: 'B',
          explanation: 'Exp',
          subTopic: 'Thermodynamics',
          isAnswered: true,
        ),
        const QuizQuestionEntity(
          id: 'q3',
          prompt: 'Q3',
          type: QuizQuestionType.multipleChoice,
          options: ['A', 'B'],
          correctAnswer: 'A',
          explanation: 'Exp',
          subTopic: 'Mechanics',
          isAnswered: true,
          isCorrect: true,
        ),
      ];

      final result = await repository.submitQuizAnswers(
        quizTitle: 'Midterm Practice',
        questions: questions,
        durationSeconds: 120,
      );

      expect(result.isRight, isTrue);
      final summary = (result as Right).value as QuizResultEntity;
      expect(summary.totalQuestions, 3);
      expect(summary.correctAnswers, 2);
      expect(summary.durationSeconds, 120);
      expect(summary.weaknesses.length, 2);
    });

    test('generateQuizFromDeck returns Failure when deck has no flashcards', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/functions/v1/generate-quiz-questions'),
          type: DioExceptionType.connectionError,
        ),
      );

      when(() => mockDecksRepo.getDeckCards('empty_deck'))
          .thenAnswer((_) async => const Right([]));

      final result = await repository.generateQuizFromDeck(
        deckId: 'empty_deck',
        deckTitle: 'Empty Topic',
        questionCount: 5,
      );

      expect(result.isLeft, isTrue);
      final failure =
          (result as Left<Failure, List<QuizQuestionEntity>>).value;
      expect(
        failure.message,
        contains('Cannot generate a quiz from an empty deck'),
      );
    });

    test('generateQuizFromDeck produces semantic distractors without placeholder strings', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/functions/v1/generate-quiz-questions'),
          type: DioExceptionType.connectionError,
        ),
      );

      // A deck with only 1 card, requiring 3 synthesized distractors
      const singleCard = [
        FlashcardEntity(
          id: 'card_solitary',
          deckId: 'deck_physics',
          front: 'Inertia',
          back: 'Resistance of an object to any change in its velocity',
          sourceTopic: 'Classical Physics',
        ),
      ];

      when(() => mockDecksRepo.getDeckCards('deck_physics'))
          .thenAnswer((_) async => const Right(singleCard));

      when(
        () => mockEngineRouter.processDirectAsset(
          assetId: any(named: 'assetId'),
          content: any(named: 'content'),
          topic: any(named: 'topic'),
          count: any(named: 'count'),
        ),
      ).thenAnswer(
        (_) async => const StudyPackResult(
          cards: [],
          executionMode: StudyEngineExecutionMode.unavailable,
          isOfflineModelMissing: true,
        ),
      );

      final result = await repository.generateQuizFromDeck(
        deckId: 'deck_physics',
        deckTitle: 'Classical Physics',
        questionCount: 1,
      );

      expect(result.isRight, isTrue);
      final questions = (result as Right).value as List<QuizQuestionEntity>;
      expect(questions.length, 1);
      final question = questions.first;
      expect(question.options.length, 4);
      expect(question.options, contains('Resistance of an object to any change in its velocity'));

      // Ensure NO generic placeholder strings exist in any option
      for (final opt in question.options) {
        expect(opt, isNot(contains('Concept Alternative')));
        expect(opt, isNot(contains('Alternative definition')));
      }
    });

    test('submitQuizAnswers persists submission to local storage, records user activity, and posts to remote API', () async {
      final questions = [
        const QuizQuestionEntity(
          id: 'q1',
          prompt: 'Q1',
          type: QuizQuestionType.multipleChoice,
          options: ['A', 'B'],
          correctAnswer: 'A',
          explanation: 'Exp',
          subTopic: 'Thermodynamics',
          isAnswered: true,
          isCorrect: true,
        ),
      ];

      when(() => mockLocalStorage.getPreference(key: any(named: 'key')))
          .thenReturn(null);
      when(
        () => mockLocalStorage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockUserActivity.recordStudySession(
          cardsReviewed: any(named: 'cardsReviewed'),
          durationSeconds: any(named: 'durationSeconds'),
          retentionScore: any(named: 'retentionScore'),
          masteredCards: any(named: 'masteredCards'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockUserStorage.getToken()).thenReturn('jwt_token_123');
      when(() => mockUserStorage.getUserId()).thenReturn('user_456');

      final result = await repository.submitQuizAnswers(
        quizTitle: 'Final Exam Practice',
        questions: questions,
        durationSeconds: 60,
      );

      expect(result.isRight, isTrue);

      // Verify local storage persistence was invoked
      verify(
        () => mockLocalStorage.savePreference(
          key: QuizRepositoryImpl.cbtSubmissionsStorageKey,
          data: any(named: 'data'),
        ),
      ).called(1);

      // Verify UserActivityService recorded the session
      verify(
        () => mockUserActivity.recordStudySession(
          cardsReviewed: 1,
          durationSeconds: 60,
          retentionScore: 1,
          masteredCards: 1,
        ),
      ).called(1);

      // Verify Remote Database API was called
      verify(
        () => mockDio.post<dynamic>(
          any(that: contains('/rest/v1/quizzes')),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).called(1);
    });
  });
}
