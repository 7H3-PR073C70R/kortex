import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
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
  });

  group('P2-01: Deadline-Based Resilient Exam Timer & Session Recovery', () {
    late MockGenerateQuizFromDeckUseCase mockGenerateUseCase;
    late MockSubmitQuizAnswersUseCase mockSubmitUseCase;
    late MockCardSyncQueue mockCardSyncQueue;
    late MockDecksRepository mockDecksRepository;
    late InMemoryLocalStorageService inMemoryStorage;
    late QuizSessionCubit cubit;

    const tQuestions = [
      QuizQuestionEntity(
        id: 'q-jamb-1',
        prompt: 'Which of the following particles has no electric charge?',
        type: QuizQuestionType.multipleChoice,
        options: ['Proton', 'Neutron', 'Electron', 'Alpha particle'],
        correctAnswer: 'Neutron',
        explanation: 'Neutrons are electrically neutral nucleons.',
        subTopic: 'Physics (2024 • Q1)',
      ),
      QuizQuestionEntity(
        id: 'q-jamb-2',
        prompt: 'Calculate the work done when a force of 10 N moves an object through 5 m.',
        type: QuizQuestionType.multipleChoice,
        options: ['50 J', '2 J', '15 J', '0.5 J'],
        correctAnswer: '50 J',
        explanation: 'Work = Force x Distance = 10 x 5 = 50 J.',
        subTopic: 'Physics (2024 • Q2)',
      ),
      QuizQuestionEntity(
        id: 'q-jamb-3',
        prompt: 'Sound waves are longitudinal waves in air.',
        type: QuizQuestionType.trueFalse,
        options: ['True', 'False'],
        correctAnswer: 'True',
        explanation: 'Sound propagates as longitudinal pressure waves in air.',
        subTopic: 'Physics (2024 • Q3)',
      ),
    ];

    const tResult = QuizResultEntity(
      id: 'mock-cbt-result-1',
      quizTitle: 'JAMB Physics Mock 2026',
      totalQuestions: 3,
      correctAnswers: 2,
      durationSeconds: 900,
      weaknesses: [],
    );

    setUp(() {
      mockGenerateUseCase = MockGenerateQuizFromDeckUseCase();
      mockSubmitUseCase = MockSubmitQuizAnswersUseCase();
      mockCardSyncQueue = MockCardSyncQueue();
      mockDecksRepository = MockDecksRepository();
      inMemoryStorage = InMemoryLocalStorageService();

      when(
        () => mockCardSyncQueue.enqueueReview(
          any(),
          flushImmediately: any(named: 'flushImmediately'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockCardSyncQueue.flushPendingLogs(),
      ).thenAnswer((_) async => 0);

      when(
        () => mockSubmitUseCase(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: any(named: 'attemptId'),
        ),
      ).thenAnswer((_) async => const Right(tResult));

      cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateUseCase,
        submitQuizUseCase: mockSubmitUseCase,
        decksRepository: mockDecksRepository,
        cardSyncQueue: mockCardSyncQueue,
        localStorageService: inMemoryStorage,
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('QuizSessionState calculates remainingSeconds monotonically from deadline', () {
      final now = DateTime.now();
      final deadline = now.add(const Duration(minutes: 10));

      final state = QuizSessionState(
        status: QuizSessionStatus.inProgress,
        startedAt: now,
        deadline: deadline,
        durationMinutes: 10,
      );

      // Remaining seconds should be approximately 600 seconds
      expect(state.remainingSeconds, inInclusiveRange(595, 600));
      expect(state.isTimeExpired, isFalse);
      expect(state.isTimeRunningLow, isFalse);

      // State near deadline (2 minutes remaining)
      final nearDeadline = now.add(const Duration(minutes: 2));
      final lowState = state.copyWith(deadline: nearDeadline);
      expect(lowState.isTimeRunningLow, isTrue);

      // Past deadline
      final expiredDeadline = now.subtract(const Duration(seconds: 5));
      final expiredState = state.copyWith(deadline: expiredDeadline);
      expect(expiredState.remainingSeconds, equals(0));
      expect(expiredState.isTimeExpired, isTrue);
    });

    test('startQuizFromPastQuestions initializes monotonic startedAt and deadline', () {
      final before = DateTime.now();
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Physics Mock 2026',
        questions: tQuestions,
        durationMinutes: 30,
        assessmentMode: AssessmentMode.examSimulationMode,
      );
      final after = DateTime.now();

      expect(cubit.state.status, equals(QuizSessionStatus.inProgress));
      expect(cubit.state.quizTitle, equals('JAMB Physics Mock 2026'));
      expect(cubit.state.durationMinutes, equals(30));
      expect(cubit.state.startedAt, isNotNull);
      expect(
        cubit.state.startedAt!.millisecondsSinceEpoch,
        inInclusiveRange(
          before.millisecondsSinceEpoch,
          after.millisecondsSinceEpoch,
        ),
      );
      expect(cubit.state.deadline, isNotNull);
      final expectedDeadline =
          cubit.state.startedAt!.add(const Duration(minutes: 30));
      expect(
        cubit.state.deadline!.millisecondsSinceEpoch,
        equals(expectedDeadline.millisecondsSinceEpoch),
      );
    });

    test('syncTimerWithDeadline synchronizes elapsed time monotonically on app resume', () {
      // Simulate an exam started 15 minutes ago
      final fifteenMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 15));
      final deadline = fifteenMinutesAgo.add(const Duration(minutes: 30));

      cubit
        ..startQuizFromPastQuestions(
          title: 'JAMB Physics Mock 2026',
          questions: tQuestions,
          durationMinutes: 30,
          assessmentMode: AssessmentMode.examSimulationMode,
        )
        ..emit(
          cubit.state.copyWith(
            startedAt: fifteenMinutesAgo,
            deadline: deadline,
            elapsedSeconds: 0, // Stale elapsed seconds before app resume
          ),
        )
        ..syncTimerWithDeadline();

      // Elapsed seconds should immediately catch up to ~15 minutes (900 seconds)
      expect(cubit.state.elapsedSeconds, inInclusiveRange(895, 905));
      expect(cubit.state.remainingSeconds, inInclusiveRange(895, 905));
    });

    test('syncTimerWithDeadline auto-submits immediately if deadline expired while backgrounded', () async {
      // Simulate an exam started 40 minutes ago with 30 minute duration
      final fortyMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 40));
      final deadline = fortyMinutesAgo.add(const Duration(minutes: 30));

      cubit
        ..startQuizFromPastQuestions(
          title: 'JAMB Physics Mock 2026',
          questions: tQuestions,
          durationMinutes: 30,
          assessmentMode: AssessmentMode.examSimulationMode,
        )
        ..emit(
          cubit.state.copyWith(
            startedAt: fortyMinutesAgo,
            deadline: deadline,
            elapsedSeconds: 10,
          ),
        )
        ..syncTimerWithDeadline();

      // Allow microtasks for auto-submit
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => mockSubmitUseCase(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: any(named: 'attemptId'),
        ),
      ).called(1);

      expect(cubit.state.status, equals(QuizSessionStatus.completed));
    });

    test('Auto-persists session state to LocalStorageService on answer selection and flagging', () async {
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Physics Mock 2026',
        questions: tQuestions,
        durationMinutes: 30,
        assessmentMode: AssessmentMode.examSimulationMode,
      );

      // Let initial async save execute
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final initialRaw = inMemoryStorage.getPreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
      );
      expect(initialRaw, isNotNull);
      final initialData = jsonDecode(initialRaw!) as Map<String, dynamic>;
      expect(initialData['quizTitle'], equals('JAMB Physics Mock 2026'));
      expect(initialData['currentIndex'], equals(0));

      // Candidate selects answer on question 0
      cubit.selectOption('Neutron');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final afterAnswerRaw = inMemoryStorage.getPreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
      );
      final afterAnswerData =
          jsonDecode(afterAnswerRaw!) as Map<String, dynamic>;
      final questionsList = afterAnswerData['questions'] as List<dynamic>;
      final firstQuestion = questionsList[0] as Map<String, dynamic>;
      expect(firstQuestion['user_selected_answer'], equals('Neutron'));
      expect(firstQuestion['is_answered'], isTrue);

      // Candidate flags question 1
      cubit.toggleFlagQuestion('q-jamb-2');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final afterFlagRaw = inMemoryStorage.getPreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
      );
      final afterFlagData = jsonDecode(afterFlagRaw!) as Map<String, dynamic>;
      expect(
        afterFlagData['flaggedQuestionIds'],
        contains('q-jamb-2'),
      );
    });

    test('Crash / Kill Resilience: restores active CBT exam with preserved answers and elapsed time', () async {
      // 1. Simulate active session stored before app was killed
      final startedAt = DateTime.now().subtract(const Duration(minutes: 10));
      final deadline = startedAt.add(const Duration(minutes: 30));

      final storedJson = jsonEncode({
        'quizTitle': 'JAMB Physics Mock 2026',
        'currentIndex': 1,
        'startedAt': startedAt.toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'durationMinutes': 30,
        'assessmentMode': AssessmentMode.examSimulationMode.name,
        'flaggedQuestionIds': ['q-jamb-1'],
        'questions': [
          {
            'id': 'q-jamb-1',
            'prompt': 'Which of the following particles has no electric charge?',
            'type': 'multipleChoice',
            'options': ['Proton', 'Neutron', 'Electron', 'Alpha particle'],
            'correct_answer': 'Neutron',
            'explanation': 'Neutrons are electrically neutral.',
            'sub_topic': 'Physics',
            'user_selected_answer': 'Neutron',
            'is_answered': true,
          },
          {
            'id': 'q-jamb-2',
            'prompt': 'Calculate work done...',
            'type': 'multipleChoice',
            'options': ['50 J', '2 J'],
            'correct_answer': '50 J',
            'explanation': 'Work formula.',
            'sub_topic': 'Physics',
            'user_selected_answer': null,
            'is_answered': false,
          },
        ],
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await inMemoryStorage.savePreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
        data: storedJson,
      );

      // 2. Create fresh cubit instance (simulating app relaunch)
      final newCubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateUseCase,
        submitQuizUseCase: mockSubmitUseCase,
        decksRepository: mockDecksRepository,
        cardSyncQueue: mockCardSyncQueue,
        localStorageService: inMemoryStorage,
      );

      // 3. Candidate restores session
      final restored = await newCubit.restoreActiveSession();
      expect(restored, isTrue);

      // Verify restored state
      expect(newCubit.state.status, equals(QuizSessionStatus.inProgress));
      expect(newCubit.state.quizTitle, equals('JAMB Physics Mock 2026'));
      expect(newCubit.state.currentIndex, equals(1));
      expect(newCubit.state.questions.length, equals(2));
      expect(
        newCubit.state.questions[0].userSelectedAnswer,
        equals('Neutron'),
      );
      expect(newCubit.state.questions[0].isAnswered, isTrue);
      expect(newCubit.state.flaggedQuestionIds, contains('q-jamb-1'));
      expect(newCubit.state.elapsedSeconds, inInclusiveRange(595, 605));
      expect(newCubit.state.remainingSeconds, inInclusiveRange(1195, 1205));

      await newCubit.close();
    });

    test('Restoring exam that expired while app was dead automatically grades and purges cache', () async {
      // Exam deadline expired 5 minutes ago while device was off
      final startedAt = DateTime.now().subtract(const Duration(minutes: 35));
      final deadline = startedAt.add(const Duration(minutes: 30));

      final storedJson = jsonEncode({
        'quizTitle': 'Expired Exam Test',
        'currentIndex': 0,
        'startedAt': startedAt.toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'durationMinutes': 30,
        'assessmentMode': AssessmentMode.examSimulationMode.name,
        'questions': [
          {
            'id': 'q-1',
            'prompt': 'Prompt',
            'type': 'multipleChoice',
            'options': ['A', 'B'],
            'correct_answer': 'A',
            'explanation': 'Exp',
            'sub_topic': 'Topic',
            'user_selected_answer': 'A',
            'is_answered': true,
          },
        ],
      });

      await inMemoryStorage.savePreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
        data: storedJson,
      );

      final newCubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateUseCase,
        submitQuizUseCase: mockSubmitUseCase,
        decksRepository: mockDecksRepository,
        cardSyncQueue: mockCardSyncQueue,
        localStorageService: inMemoryStorage,
      );

      final restored = await newCubit.restoreActiveSession();
      expect(restored, isFalse);

      // Verify submit was invoked and cache was purged
      verify(
        () => mockSubmitUseCase(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: any(named: 'attemptId'),
        ),
      ).called(1);

      expect(
        inMemoryStorage.getPreference(
          key: QuizSessionCubit.activeCbtSessionStorageKey,
        ),
        isNull,
      );

      await newCubit.close();
    });

    test('submitQuiz clears active session from LocalStorageService', () async {
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Physics Mock 2026',
        questions: tQuestions,
        durationMinutes: 30,
        assessmentMode: AssessmentMode.examSimulationMode,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        inMemoryStorage.getPreference(
          key: QuizSessionCubit.activeCbtSessionStorageKey,
        ),
        isNotNull,
      );

      await cubit.submitQuiz();

      expect(
        inMemoryStorage.getPreference(
          key: QuizSessionCubit.activeCbtSessionStorageKey,
        ),
        isNull,
      );
    });
  });
}
