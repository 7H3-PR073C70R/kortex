import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
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

  group('P3-02: fake_async CBT Timer, Concurrency & Lifecycle Test Suite', () {
    late MockGenerateQuizFromDeckUseCase mockGenerateUseCase;
    late MockSubmitQuizAnswersUseCase mockSubmitUseCase;
    late MockCardSyncQueue mockCardSyncQueue;
    late MockDecksRepository mockDecksRepository;
    late InMemoryLocalStorageService inMemoryStorage;

    const tQuestions = [
      QuizQuestionEntity(
        id: 'q-jamb-physics-01',
        prompt: 'Which of the following is a fundamental SI quantity?',
        type: QuizQuestionType.multipleChoice,
        options: ['Luminous Intensity', 'Velocity', 'Force', 'Electric Charge'],
        correctAnswer: 'Luminous Intensity',
        explanation: 'Luminous intensity is one of the 7 base SI quantities (candela).',
        subTopic: 'JAMB Physics (Units & Dimensions)',
      ),
      QuizQuestionEntity(
        id: 'q-jamb-physics-02',
        prompt: 'A car accelerates uniformly from rest at 2 m/s² for 5 s. Calculate distance covered.',
        type: QuizQuestionType.multipleChoice,
        options: ['25 m', '10 m', '50 m', '5 m'],
        correctAnswer: '25 m',
        explanation: 's = ut + 0.5at² = 0 + 0.5(2)(25) = 25 m.',
        subTopic: 'JAMB Physics (Linear Motion)',
      ),
      QuizQuestionEntity(
        id: 'q-jamb-physics-03',
        prompt: 'Pressure in a static liquid depends on the shape of the container.',
        type: QuizQuestionType.trueFalse,
        options: ['True', 'False'],
        correctAnswer: 'False',
        explanation: 'Liquid pressure depends solely on depth, density, and g: P = ρgh.',
        subTopic: 'JAMB Physics (Hydrostatics)',
      ),
    ];

    const tQuizResult = QuizResultEntity(
      id: 'mock-exam-attempt-res-1',
      quizTitle: 'JAMB CBT Physics Mock 2026',
      totalQuestions: 3,
      correctAnswers: 2,
      durationSeconds: 600,
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
      ).thenAnswer((_) async => const Right(tQuizResult));
    });

    group('1. fakeAsync Timer Countdown & Automatic Submission on Expiry', () {
      test('Timer ticks every second and updates elapsed and remaining seconds monotonically', () async {
        late QuizSessionCubit cubit;
        fakeAsync((async) {
          var fakeClock = DateTime(2026, 10, 16, 9);
          cubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          )..startQuizFromPastQuestions(
            title: 'JAMB CBT Physics Mock 2026',
            questions: tQuestions,
            durationMinutes: 10, // 600 seconds
            assessmentMode: AssessmentMode.examSimulationMode,
          );

          expect(cubit.state.status, equals(QuizSessionStatus.inProgress));
          expect(cubit.state.elapsedSeconds, equals(0));
          expect(cubit.state.getRemainingSeconds(fakeClock), equals(600));
          expect(cubit.state.getIsTimeExpired(fakeClock), isFalse);
          expect(cubit.state.getIsTimeRunningLow(fakeClock), isFalse);

          // Advance 45 seconds tick by tick
          for (var i = 0; i < 45; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }

          expect(cubit.state.elapsedSeconds, equals(45));
          expect(cubit.state.getRemainingSeconds(fakeClock), equals(555));
          expect(cubit.state.getIsTimeExpired(fakeClock), isFalse);
        });
        await cubit.close();
      });

      test('Timer triggers isTimeRunningLow warning when remaining time drops to <= 300s', () async {
        late QuizSessionCubit cubit;
        fakeAsync((async) {
          var fakeClock = DateTime(2026, 10, 16, 9);
          cubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          )..startQuizFromPastQuestions(
            title: 'JAMB CBT Physics Mock 2026',
            questions: tQuestions,
            durationMinutes: 10, // 600 seconds
            assessmentMode: AssessmentMode.examSimulationMode,
          );

          // Advance 305 seconds -> 295 seconds remaining
          for (var i = 0; i < 305; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }

          expect(cubit.state.elapsedSeconds, equals(305));
          expect(cubit.state.getRemainingSeconds(fakeClock), equals(295));
          expect(cubit.state.getIsTimeRunningLow(fakeClock), isTrue);
          expect(cubit.state.getIsTimeExpired(fakeClock), isFalse);
        });
        await cubit.close();
      });

      test('Timer automatically submits quiz upon reaching deadline and cancels periodic timer', () async {
        late QuizSessionCubit cubit;
        fakeAsync((async) {
          var fakeClock = DateTime(2026, 10, 16, 9);
          cubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          )
            ..startQuizFromPastQuestions(
              title: 'JAMB CBT Physics Mock 2026',
              questions: tQuestions,
              durationMinutes: 10, // 600 seconds
              assessmentMode: AssessmentMode.examSimulationMode,
            )
            ..selectOption('Luminous Intensity')
            ..jumpToQuestion(1)
            ..selectOption('10 m') // Incorrect (correct is 25 m)
            ..jumpToQuestion(2); // Leave question 2 unanswered

          // Advance time until 601 seconds (past 600s deadline)
          for (var i = 0; i < 601; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }

          // Allow asynchronous submit execution to complete
          async.flushMicrotasks();

          // Verify submission usecase was called exactly once with 600 seconds duration
          verify(
            () => mockSubmitUseCase(
              quizTitle: 'JAMB CBT Physics Mock 2026',
              questions: any(
                named: 'questions',
                that: predicate<List<QuizQuestionEntity>>((list) {
                  return list.length == 3 &&
                      list[0].isCorrect &&
                      !list[1].isCorrect &&
                      !list[2].isCorrect; // Unanswered question marked incorrect
                }),
              ),
              durationSeconds: 600,
              attemptId: any(named: 'attemptId'),
            ),
          ).called(1);

          expect(cubit.state.status, equals(QuizSessionStatus.completed));
          expect(cubit.state.getIsTimeExpired(fakeClock), isTrue);

          // Verify advancing further does not trigger additional submissions (timer cancelled)
          for (var i = 0; i < 60; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }
          async.flushMicrotasks();

          verifyNever(
            () => mockSubmitUseCase(
              quizTitle: any(named: 'quizTitle'),
              questions: any(named: 'questions'),
              durationSeconds: any(named: 'durationSeconds'),
              attemptId: any(named: 'attemptId'),
            ),
          );
        });
        await cubit.close();
      });
    });

    group('2. fakeAsync Lifecycle Transitions (Backgrounding & App Resume)', () {
      test('Simulates 15-minute backgrounding (paused -> resumed): elapsed drops by 900s monotonically', () async {
        late QuizSessionCubit cubit;
        fakeAsync((async) {
          var fakeClock = DateTime(2026, 10, 16, 9);
          cubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          )..startQuizFromPastQuestions(
            title: 'JAMB CBT Physics Mock 2026',
            questions: tQuestions,
            durationMinutes: 30,
            assessmentMode: AssessmentMode.examSimulationMode,
          );

          // Run active in foreground for 5 minutes (300s)
          for (var i = 0; i < 300; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }

          expect(cubit.state.elapsedSeconds, equals(300));
          expect(cubit.state.getRemainingSeconds(fakeClock), equals(1500));

          // Simulate user switching away / locking phone for 15 minutes (900 seconds)
          fakeClock = fakeClock.add(const Duration(minutes: 15));

          // User re-opens app: AppLifecycleState.resumed triggers syncTimerWithDeadline()
          cubit.syncTimerWithDeadline();

          // Elapsed time catches up immediately to 20 minutes (1200 seconds)
          expect(cubit.state.elapsedSeconds, equals(1200));
          // Remaining time drops from 1500s down to 600s (10 minutes)
          expect(cubit.state.getRemainingSeconds(fakeClock), equals(600));
          expect(cubit.state.getIsTimeExpired(fakeClock), isFalse);
        });
        await cubit.close();
      });

      test('Simulates backgrounding past the deadline: syncTimerWithDeadline auto-submits immediately', () async {
        late QuizSessionCubit cubit;
        fakeAsync((async) {
          var fakeClock = DateTime(2026, 10, 16, 9);
          cubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          )..startQuizFromPastQuestions(
            title: 'JAMB CBT Physics Mock 2026',
            questions: tQuestions,
            durationMinutes: 20,
            assessmentMode: AssessmentMode.examSimulationMode,
          );

          // Student works for 2 minutes
          for (var i = 0; i < 120; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }

          // Student puts app in background for 35 minutes (2100 seconds)
          fakeClock = fakeClock.add(const Duration(minutes: 35));

          // App resumes after deadline passed
          cubit.syncTimerWithDeadline();
          async.flushMicrotasks();

          verify(
            () => mockSubmitUseCase(
              quizTitle: 'JAMB CBT Physics Mock 2026',
              questions: any(named: 'questions'),
              durationSeconds: 1200, // Capped to exam duration
              attemptId: any(named: 'attemptId'),
            ),
          ).called(1);

          expect(cubit.state.status, equals(QuizSessionStatus.completed));
          expect(cubit.state.getIsTimeExpired(fakeClock), isTrue);
        });
        await cubit.close();
      });
    });

    group('3. Re-entrancy & Concurrency Hardening', () {
      test('5 simultaneous calls to submitQuiz execute repository use case exactly once', () async {
        final cubit = QuizSessionCubit(
          generateQuizUseCase: mockGenerateUseCase,
          submitQuizUseCase: mockSubmitUseCase,
          decksRepository: mockDecksRepository,
          cardSyncQueue: mockCardSyncQueue,
          localStorageService: inMemoryStorage,
        )..startQuizFromPastQuestions(
          title: 'JAMB CBT Physics Mock 2026',
          questions: tQuestions,
          durationMinutes: 30,
          assessmentMode: AssessmentMode.examSimulationMode,
        );

        // Rapidly dispatch 5 submit requests concurrently
        await Future.wait([
          cubit.submitQuiz(),
          cubit.submitQuiz(),
          cubit.submitQuiz(),
          cubit.submitQuiz(),
          cubit.submitQuiz(),
        ]);

        verify(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
            attemptId: any(named: 'attemptId'),
          ),
        ).called(1);

        expect(cubit.state.status, equals(QuizSessionStatus.completed));
        await cubit.close();
      });

      test('Submitting after cubit is closed safely returns without throwing exception', () async {
        final cubit = QuizSessionCubit(
          generateQuizUseCase: mockGenerateUseCase,
          submitQuizUseCase: mockSubmitUseCase,
          decksRepository: mockDecksRepository,
          cardSyncQueue: mockCardSyncQueue,
          localStorageService: inMemoryStorage,
        )..startQuizFromPastQuestions(
          title: 'JAMB CBT Physics Mock 2026',
          questions: tQuestions,
          durationMinutes: 30,
          assessmentMode: AssessmentMode.examSimulationMode,
        );

        await cubit.close();

        // Must not throw "Bad state: Cannot emit new states after calling close"
        await expectLater(cubit.submitQuiz(), completes);

        verifyNever(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
            attemptId: any(named: 'attemptId'),
          ),
        );
      });

      test('Submitting when already submitting or completed does not trigger duplicate submissions', () async {
        final cubit = QuizSessionCubit(
          generateQuizUseCase: mockGenerateUseCase,
          submitQuizUseCase: mockSubmitUseCase,
          decksRepository: mockDecksRepository,
          cardSyncQueue: mockCardSyncQueue,
          localStorageService: inMemoryStorage,
        )..startQuizFromPastQuestions(
          title: 'JAMB CBT Physics Mock 2026',
          questions: tQuestions,
          durationMinutes: 30,
          assessmentMode: AssessmentMode.examSimulationMode,
        );

        await cubit.submitQuiz();
        expect(cubit.state.status, equals(QuizSessionStatus.completed));

        // Attempting another submission on completed state is guarded
        await cubit.submitQuiz();

        verify(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
            attemptId: any(named: 'attemptId'),
          ),
        ).called(1);

        await cubit.close();
      });
    });

    group('4. Crash Recovery & Session Rehydration', () {
      test('Active exam session state is persisted to local storage on answer selection and flagging', () async {
        final cubit = QuizSessionCubit(
          generateQuizUseCase: mockGenerateUseCase,
          submitQuizUseCase: mockSubmitUseCase,
          decksRepository: mockDecksRepository,
          cardSyncQueue: mockCardSyncQueue,
          localStorageService: inMemoryStorage,
        )..startQuizFromPastQuestions(
          title: 'JAMB CBT Physics Mock 2026',
          questions: tQuestions,
          durationMinutes: 40,
          assessmentMode: AssessmentMode.examSimulationMode,
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        cubit
          ..selectOption('Luminous Intensity')
          ..toggleFlagQuestion('q-jamb-physics-02');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final savedJson = inMemoryStorage.getPreference(
          key: QuizSessionCubit.activeCbtSessionStorageKey,
        );
        expect(savedJson, isNotNull);

        final decoded = jsonDecode(savedJson!) as Map<String, dynamic>;
        expect(decoded['quizTitle'], equals('JAMB CBT Physics Mock 2026'));
        expect(decoded['durationMinutes'], equals(40));
        expect(decoded['flaggedQuestionIds'], contains('q-jamb-physics-02'));

        final savedQuestions = (decoded['questions'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        expect(savedQuestions[0]['user_selected_answer'], equals('Luminous Intensity'));
        expect(savedQuestions[0]['is_answered'], isTrue);

        await cubit.close();
      });

      test('Crash Recovery: restoreActiveSession reconstructs in-flight exam and timer continues countdown', () async {
        late QuizSessionCubit restoredCubit;
        fakeAsync((async) {
          var fakeClock = DateTime(2026, 10, 16, 9, 10);
          final startedAt = DateTime(2026, 10, 16, 9); // 10 minutes ago
          final deadline = startedAt.add(const Duration(minutes: 30)); // 20 minutes remaining

          // Populate storage as if app crashed at 9:10 AM
          final storedPayload = jsonEncode({
            'attemptId': 'cbt-crash-attempt-uuid',
            'quizTitle': 'JAMB CBT Physics Mock 2026',
            'currentIndex': 1,
            'startedAt': startedAt.toIso8601String(),
            'deadline': deadline.toIso8601String(),
            'durationMinutes': 30,
            'assessmentMode': AssessmentMode.examSimulationMode.name,
            'flaggedQuestionIds': ['q-jamb-physics-01'],
            'questions': [
              {
                'id': 'q-jamb-physics-01',
                'prompt': 'Which of the following is a fundamental SI quantity?',
                'type': 'multipleChoice',
                'options': ['Luminous Intensity', 'Velocity', 'Force', 'Electric Charge'],
                'correct_answer': 'Luminous Intensity',
                'explanation': 'Luminous intensity is base SI.',
                'sub_topic': 'Physics',
                'user_selected_answer': 'Luminous Intensity',
                'is_answered': true,
              },
              {
                'id': 'q-jamb-physics-02',
                'prompt': 'Calculate distance...',
                'type': 'multipleChoice',
                'options': ['25 m', '10 m'],
                'correct_answer': '25 m',
                'explanation': '25 m.',
                'sub_topic': 'Physics',
                'user_selected_answer': null,
                'is_answered': false,
              },
            ],
          });

          unawaited(
            inMemoryStorage.savePreference(
              key: QuizSessionCubit.activeCbtSessionStorageKey,
              data: storedPayload,
            ),
          );

          // New cubit instance created after relaunch
          restoredCubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          );

          var restoredSuccess = false;
          unawaited(
            restoredCubit.restoreActiveSession().then((val) => restoredSuccess = val),
          );
          async.flushMicrotasks();

          expect(restoredSuccess, isTrue);
          expect(restoredCubit.state.status, equals(QuizSessionStatus.inProgress));
          expect(restoredCubit.state.attemptId, equals('cbt-crash-attempt-uuid'));
          expect(restoredCubit.state.currentIndex, equals(1));
          expect(restoredCubit.state.elapsedSeconds, equals(600)); // 10 minutes elapsed
          expect(restoredCubit.state.getRemainingSeconds(fakeClock), equals(1200)); // 20 minutes remaining
          expect(restoredCubit.state.flaggedQuestionIds, contains('q-jamb-physics-01'));

          // Verify timer resumed and ticks smoothly from recovered state
          for (var i = 0; i < 30; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }

          expect(restoredCubit.state.elapsedSeconds, equals(630));
          expect(restoredCubit.state.getRemainingSeconds(fakeClock), equals(1170));
        });
        await restoredCubit.close();
      });

      test('Crash Recovery with Expired Deadline: auto-submits and clears local cache', () async {
        late QuizSessionCubit restoredCubit;
        fakeAsync((async) {
          // Exam started 45 minutes ago with 30 minute duration (expired 15 mins ago)
          final fakeClock = DateTime(2026, 10, 16, 9, 45);
          final startedAt = DateTime(2026, 10, 16, 9);
          final deadline = startedAt.add(const Duration(minutes: 30));

          final storedPayload = jsonEncode({
            'attemptId': 'expired-attempt-uuid',
            'quizTitle': 'JAMB CBT Physics Mock 2026',
            'currentIndex': 0,
            'startedAt': startedAt.toIso8601String(),
            'deadline': deadline.toIso8601String(),
            'durationMinutes': 30,
            'assessmentMode': AssessmentMode.examSimulationMode.name,
            'questions': [
              {
                'id': 'q-jamb-physics-01',
                'prompt': 'Fundamental SI quantity?',
                'type': 'multipleChoice',
                'options': ['Luminous Intensity', 'Velocity'],
                'correct_answer': 'Luminous Intensity',
                'user_selected_answer': 'Luminous Intensity',
                'is_answered': true,
              },
            ],
          });

          unawaited(
            inMemoryStorage.savePreference(
              key: QuizSessionCubit.activeCbtSessionStorageKey,
              data: storedPayload,
            ),
          );

          restoredCubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          );

          var restoredSuccess = true;
          unawaited(
            restoredCubit.restoreActiveSession().then((val) => restoredSuccess = val),
          );
          async.flushMicrotasks();

          expect(restoredSuccess, isFalse, reason: 'Must return false because exam expired and auto-submitted');
          verify(
            () => mockSubmitUseCase(
              quizTitle: 'JAMB CBT Physics Mock 2026',
              questions: any(named: 'questions'),
              durationSeconds: 1800, // 30 minutes duration
              attemptId: 'expired-attempt-uuid',
            ),
          ).called(1);

          expect(
            inMemoryStorage.getPreference(key: QuizSessionCubit.activeCbtSessionStorageKey),
            isNull,
            reason: 'Active session cache must be cleared after submission',
          );
        });
        await restoredCubit.close();
      });
    });

    group('5. Network Failure & Navigation Interruption Resilience', () {
      test('Timer expiration during network failure transitions state to error without crashing', () async {
        late QuizSessionCubit cubit;
        fakeAsync((async) {
          when(
            () => mockSubmitUseCase(
              quizTitle: any(named: 'quizTitle'),
              questions: any(named: 'questions'),
              durationSeconds: any(named: 'durationSeconds'),
              attemptId: any(named: 'attemptId'),
            ),
          ).thenAnswer((_) async => const Left(ServerFailure(message: 'Remote connection timeout')));

          var fakeClock = DateTime(2026, 10, 16, 9);
          cubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          )..startQuizFromPastQuestions(
            title: 'JAMB CBT Physics Mock 2026',
            questions: tQuestions,
            durationMinutes: 5,
            assessmentMode: AssessmentMode.examSimulationMode,
          );

          // Advance past 5 minutes (301 seconds)
          for (var i = 0; i < 301; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }
          async.flushMicrotasks();

          expect(cubit.state.status, equals(QuizSessionStatus.error));
          expect(cubit.state.errorMessage, equals('Remote connection timeout'));
        });
        await cubit.close();
      });

      test('Fast question navigation does not corrupt monotonic elapsed time or deadline', () async {
        late QuizSessionCubit cubit;
        fakeAsync((async) {
          var fakeClock = DateTime(2026, 10, 16, 9);
          cubit = QuizSessionCubit(
            generateQuizUseCase: mockGenerateUseCase,
            submitQuizUseCase: mockSubmitUseCase,
            decksRepository: mockDecksRepository,
            cardSyncQueue: mockCardSyncQueue,
            localStorageService: inMemoryStorage,
            nowProvider: () => fakeClock,
          )..startQuizFromPastQuestions(
            title: 'JAMB CBT Physics Mock 2026',
            questions: tQuestions,
            durationMinutes: 15,
            assessmentMode: AssessmentMode.examSimulationMode,
          );

          final initialDeadline = cubit.state.deadline;

          // Candidate jumps through all questions rapidly
          cubit
            ..jumpToQuestion(1)
            ..jumpToQuestion(2)
            ..previousQuestion()
            ..jumpToQuestion(0);

          // Advance 10 seconds
          for (var i = 0; i < 10; i++) {
            fakeClock = fakeClock.add(const Duration(seconds: 1));
            async.elapse(const Duration(seconds: 1));
          }

          expect(cubit.state.currentIndex, equals(0));
          expect(cubit.state.elapsedSeconds, equals(10));
          expect(cubit.state.deadline, equals(initialDeadline));
          expect(cubit.state.getRemainingSeconds(fakeClock), equals(890));
        });
        await cubit.close();
      });
    });
  });
}
