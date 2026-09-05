import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  group('QuizRepositoryImpl Dynamic AI Generation Suite', () {
    late MockDecksRepository mockDecksRepo;
    late MockIngestionRepository mockIngestionRepo;
    late MockStudyEngineRouter mockEngineRouter;
    late MockDio mockDio;
    late QuizRepositoryImpl repository;

    setUp(() {
      mockDecksRepo = MockDecksRepository();
      mockIngestionRepo = MockIngestionRepository();
      mockEngineRouter = MockStudyEngineRouter();
      mockDio = MockDio();

      repository = QuizRepositoryImpl(
        decksRepository: mockDecksRepo,
        ingestionRepository: mockIngestionRepo,
        studyEngineRouter: mockEngineRouter,
        dio: mockDio,
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
  });
}
