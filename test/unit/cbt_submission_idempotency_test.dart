import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/study_activity_tracker.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/generate_quiz_from_deck_use_case.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/submit_quiz_answers_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:mocktail/mocktail.dart';

class FakeFsrsReviewLog extends Fake implements FsrsReviewLog {}

class MockGenerateQuizFromDeckUseCase extends Mock
    implements GenerateQuizFromDeckUseCase {}

class MockSubmitQuizAnswersUseCase extends Mock
    implements SubmitQuizAnswersUseCase {}

class MockCardSyncQueue extends Mock implements CardSyncQueue {}

class MockDecksRepository extends Mock implements DecksRepository {}

class MockUserActivityService extends Mock implements UserActivityService {}

class MockStudyActivityTracker extends Mock implements StudyActivityTracker {}

class MockDio extends Mock implements Dio {}

class MockUserStorageService extends Mock implements UserStorageService {}

class InMemoryLocalStorageService implements LocalStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => _data[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    _data[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<void> clearAllPreferences() async {
    _data.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeFsrsReviewLog());
    registerFallbackValue(XpActivityCategory.quizCompletion);
  });

  const tQuestions = [
    QuizQuestionEntity(
      id: 'q_chem_1',
      prompt: 'What is the atomic number of Carbon?',
      type: QuizQuestionType.multipleChoice,
      options: ['6', '12', '14', '8'],
      correctAnswer: '6',
      explanation: 'Carbon has 6 protons.',
      subTopic: 'Organic Chemistry',
      userSelectedAnswer: '6',
      isAnswered: true,
      isCorrect: true,
    ),
    QuizQuestionEntity(
      id: 'q_chem_2',
      prompt: 'Is water a polar molecule?',
      type: QuizQuestionType.trueFalse,
      options: ['True', 'False'],
      correctAnswer: 'True',
      explanation: 'Water has a bent shape with dipoles.',
      subTopic: 'Inorganic Chemistry',
      userSelectedAnswer: 'True',
      isAnswered: true,
      isCorrect: true,
    ),
  ];

  final tResult = QuizResultEntity(
    id: UuidUtils.generate(),
    quizTitle: 'JAMB Chemistry Mock',
    totalQuestions: 2,
    correctAnswers: 2,
    durationSeconds: 90,
    weaknesses: const [],
  );

  const tXpEvent = XpEarnedEvent(
    category: XpActivityCategory.quizCompletion,
    baseAmount: 50,
    multiplier: 1,
    xpEarned: 50,
    totalXp: 50,
  );

  group('P2-02 · Re-Entrancy Guard & Idempotent Submission Pipeline', () {
    late MockGenerateQuizFromDeckUseCase mockGenerateUseCase;
    late MockSubmitQuizAnswersUseCase mockSubmitUseCase;
    late MockCardSyncQueue mockCardSyncQueue;
    late MockDecksRepository mockDecksRepo;
    late MockUserActivityService mockUserActivity;
    late MockStudyActivityTracker mockTracker;
    late InMemoryLocalStorageService inMemoryStorage;
    late QuizSessionCubit cubit;

    setUp(() async {
      await locator.reset();

      mockGenerateUseCase = MockGenerateQuizFromDeckUseCase();
      mockSubmitUseCase = MockSubmitQuizAnswersUseCase();
      mockCardSyncQueue = MockCardSyncQueue();
      mockDecksRepo = MockDecksRepository();
      mockUserActivity = MockUserActivityService();
      mockTracker = MockStudyActivityTracker();
      inMemoryStorage = InMemoryLocalStorageService();

      when(() => mockCardSyncQueue.flushPendingLogs())
          .thenAnswer((_) async => 0);
      when(() => mockCardSyncQueue.enqueueReview(any(), flushImmediately: any(named: 'flushImmediately')))
          .thenAnswer((_) async {});

      when(() => mockUserActivity.awardXp(
            any(),
            customBaseAmount: any(named: 'customBaseAmount'),
            sourceId: any(named: 'sourceId'),
            metadata: any(named: 'metadata'),
          )).thenAnswer((_) async => tXpEvent);

      when(() => mockUserActivity.recordStudySession(
            cardsReviewed: any(named: 'cardsReviewed'),
            durationSeconds: any(named: 'durationSeconds'),
            retentionScore: any(named: 'retentionScore'),
            masteredCards: any(named: 'masteredCards'),
            activityCategory: any(named: 'activityCategory'),
            subject: any(named: 'subject'),
          )).thenAnswer((_) async {});

      when(() => mockTracker.recordActivityCompletion(
            durationSeconds: any(named: 'durationSeconds'),
            activityType: any(named: 'activityType'),
          )).thenAnswer((_) async => 2);

      locator
        ..registerSingleton<LocalStorageService>(inMemoryStorage)
        ..registerSingleton<UserActivityService>(mockUserActivity)
        ..registerSingleton<StudyActivityTracker>(mockTracker);

      when(
        () => mockSubmitUseCase(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: any(named: 'attemptId'),
        ),
      ).thenAnswer((_) async {
        // Simulate async network submission latency
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Right(tResult);
      });

      cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateUseCase,
        submitQuizUseCase: mockSubmitUseCase,
        decksRepository: mockDecksRepo,
        cardSyncQueue: mockCardSyncQueue,
        localStorageService: inMemoryStorage,
      );
    });

    tearDown(() async {
      await cubit.close();
      await locator.reset();
    });

    test('re-entrancy guard ensures 5 rapid simultaneous submitQuiz calls execute exactly once', () async {
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Chemistry Mock',
        questions: tQuestions,
        durationMinutes: 45,
        assessmentMode: AssessmentMode.examSimulationMode,
      );

      final initialAttemptId = cubit.state.attemptId;
      expect(initialAttemptId, isNotNull);
      expect(UuidUtils.isValidUuid(initialAttemptId), isTrue);

      // Fire 5 concurrent rapid submission requests
      final submissions = Future.wait([
        cubit.submitQuiz(),
        cubit.submitQuiz(),
        cubit.submitQuiz(),
        cubit.submitQuiz(),
        cubit.submitQuiz(),
      ]);

      await submissions;

      // Allow microtasks to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify submitQuizUseCase was called exactly ONCE
      verify(
        () => mockSubmitUseCase(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: initialAttemptId,
        ),
      ).called(1);

      // Verify XP was awarded exactly ONCE
      verify(
        () => mockUserActivity.awardXp(
          any(),
          customBaseAmount: any(named: 'customBaseAmount'),
          sourceId: any(named: 'sourceId'),
          metadata: any(named: 'metadata'),
        ),
      ).called(1);

      // Verify FSRS flush was called exactly ONCE
      verify(() => mockCardSyncQueue.flushPendingLogs()).called(1);

      // Verify state transitioned to completed with result
      expect(cubit.state.status, equals(QuizSessionStatus.completed));
      expect(cubit.state.result, equals(tResult));
      expect(cubit.state.attemptId, equals(initialAttemptId));
    });

    test('submitQuiz returns immediately when cubit is already closed', () async {
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Chemistry Mock',
        questions: tQuestions,
      );

      await cubit.close();
      await cubit.submitQuiz();

      verifyNever(
        () => mockSubmitUseCase(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: any(named: 'attemptId'),
        ),
      );
    });

    test('submitQuiz returns immediately when status is already submitting or completed', () async {
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Chemistry Mock',
        questions: tQuestions,
      );

      // Initial submit
      await cubit.submitQuiz();
      expect(cubit.state.status, equals(QuizSessionStatus.completed));

      // Second invocation while completed
      await cubit.submitQuiz();

      // Ensure mock was only called for the initial submit
      verify(
        () => mockSubmitUseCase(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: any(named: 'attemptId'),
        ),
      ).called(1);
    });

    test('session restoration restores the exact same attemptId across app restarts', () async {
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Chemistry Mock',
        questions: tQuestions,
        durationMinutes: 45,
        assessmentMode: AssessmentMode.examSimulationMode,
      );

      final originalAttemptId = cubit.state.attemptId;
      expect(originalAttemptId, isNotNull);

      // Verify saved session payload contains attemptId
      final raw = inMemoryStorage.getPreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
      );
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['attemptId'], equals(originalAttemptId));

      // Simulate app restart by instantiating fresh cubit with same storage
      final newCubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateUseCase,
        submitQuizUseCase: mockSubmitUseCase,
        decksRepository: mockDecksRepo,
        cardSyncQueue: mockCardSyncQueue,
        localStorageService: inMemoryStorage,
      );
      addTearDown(newCubit.close);

      final restored = await newCubit.restoreActiveSession();
      expect(restored, isTrue);
      expect(newCubit.state.attemptId, equals(originalAttemptId));

      await newCubit.submitQuiz();

      verify(
        () => mockSubmitUseCase(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: originalAttemptId,
        ),
      ).called(1);
    });

    test('QuizRepositoryImpl.submitQuizAnswers sends attempt_id as id and resolution=ignore-duplicates', () async {
      final mockDio = MockDio();
      final mockUserStorage = MockUserStorageService();

      when(mockUserStorage.getToken).thenReturn('token_123');
      when(mockUserStorage.getUserId).thenReturn('user_456');

      Map<String, dynamic>? capturedPayload;
      Options? capturedOptions;

      when(
        () => mockDio.post<dynamic>(
          any(that: contains('/rest/v1/quizzes')),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        capturedPayload = invocation.namedArguments[#data] as Map<String, dynamic>?;
        capturedOptions = invocation.namedArguments[#options] as Options?;
        return Response<dynamic>(
          requestOptions: RequestOptions(path: '/rest/v1/quizzes'),
          statusCode: 201,
        );
      });

      final repo = QuizRepositoryImpl(
        dio: mockDio,
        localStorageService: inMemoryStorage,
        userStorageService: mockUserStorage,
        userActivityService: mockUserActivity,
      );

      final clientUuid = UuidUtils.generate();

      final result = await repo.submitQuizAnswers(
        quizTitle: 'WAEC Physics Exam',
        questions: tQuestions,
        durationSeconds: 120,
        attemptId: clientUuid,
      );

      expect(result.isRight, isTrue);
      final quizResult = (result as Right).value as QuizResultEntity;

      // 1. Result id matches client UUID
      expect(quizResult.id, equals(clientUuid));

      // 2. Remote payload includes id as primary key
      expect(capturedPayload, isNotNull);
      expect(capturedPayload!['id'], equals(clientUuid));
      expect(capturedPayload!['user_id'], equals('user_456'));

      // 3. PostgREST Prefer header contains resolution=ignore-duplicates for ON CONFLICT DO NOTHING
      expect(capturedOptions, isNotNull);
      final headers = capturedOptions!.headers!;
      expect(headers['Prefer'], contains('resolution=ignore-duplicates'));

      // 4. Local storage idempotent de-duplication: submitting the same attemptId updates instead of duplicating
      final secondResult = await repo.submitQuizAnswers(
        quizTitle: 'WAEC Physics Exam',
        questions: tQuestions,
        durationSeconds: 120,
        attemptId: clientUuid,
      );
      expect(secondResult.isRight, isTrue);

      final submissionsRaw = inMemoryStorage.getPreference(
        key: QuizRepositoryImpl.cbtSubmissionsStorageKey,
      );
      expect(submissionsRaw, isNotNull);
      final storedList = (jsonDecode(submissionsRaw!) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final matchingSubmissions =
          storedList.where((item) => item['id'] == clientUuid).toList();
      expect(matchingSubmissions.length, equals(1));
    });
  });
}
