import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/study_activity_tracker.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/generate_quiz_from_deck_use_case.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/submit_quiz_answers_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockStudyActivityTracker extends Mock implements StudyActivityTracker {}

class MockCommunityRepository extends Mock implements CommunityRepository {}

class MockGenerateQuizFromDeckUseCase extends Mock
    implements GenerateQuizFromDeckUseCase {}

class MockSubmitQuizAnswersUseCase extends Mock
    implements SubmitQuizAnswersUseCase {}

class MockQuizDuelRepository extends Mock implements QuizDuelRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

QuizQuestionEntity _fakeQuestion({String id = 'q1'}) => QuizQuestionEntity(
  id: id,
  prompt: 'What is 2+2?',
  type: QuizQuestionType.multipleChoice,
  options: const ['2', '3', '4', '5'],
  correctAnswer: '4',
  explanation: 'Basic arithmetic.',
  subTopic: 'Math',
);

QuizResultEntity _fakeResult({int durationSeconds = 180}) => QuizResultEntity(
  id: 'result-1',
  quizTitle: 'Math Quiz',
  totalQuestions: 5,
  correctAnswers: 4,
  durationSeconds: durationSeconds,
  weaknesses: const [],
);

QuizDuelMatch _fakeMatch({
  String? winnerUserId,
  QuizDuelStatus status = QuizDuelStatus.finished,
  int questionCount = 5,
  int durationPerQuestion = 30,
}) {
  const player1 = QuizDuelParticipant(userId: 'player1', displayName: 'Alice', avatarUrl: '');
  const player2 = QuizDuelParticipant(userId: 'player2', displayName: 'Bob', avatarUrl: '');
  return QuizDuelMatch(
    duelId: 'duel-1',
    subject: 'Biology',
    examBoard: 'WAEC',
    questions: List.generate(questionCount, (i) => _fakeQuestion(id: 'dq$i')),
    player1: player1,
    player2: player2,
    durationPerQuestionSeconds: durationPerQuestion,
    status: status,
    winnerUserId: winnerUserId,
  );
}

// ---------------------------------------------------------------------------
// QuizSessionCubit → StudyActivityTracker
// ---------------------------------------------------------------------------

void main() {
  // Binding must be initialized for platform channel calls (haptics, sounds)
  // that are invoked by production code via `selectOption`.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuizSessionCubit → StudyActivityTracker integration', () {
    late MockStudyActivityTracker mockTracker;
    late MockGenerateQuizFromDeckUseCase mockGenerateUseCase;
    late MockSubmitQuizAnswersUseCase mockSubmitUseCase;
    late QuizSessionCubit cubit;

    setUpAll(() {
      registerFallbackValue(<QuizQuestionEntity>[]);
      registerFallbackValue('');
    });

    setUp(() async {
      await GetIt.instance.reset();
      mockTracker = MockStudyActivityTracker();
      mockGenerateUseCase = MockGenerateQuizFromDeckUseCase();
      mockSubmitUseCase = MockSubmitQuizAnswersUseCase();

      when(
        () => mockTracker.recordActivityCompletion(
          durationSeconds: any(named: 'durationSeconds'),
          activityType: any(named: 'activityType'),
          circleId: any(named: 'circleId'),
          metadata: any(named: 'metadata'),
        ),
      ).thenAnswer((_) async => 3);

      GetIt.instance.registerSingleton<StudyActivityTracker>(mockTracker);

      cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateUseCase,
        submitQuizUseCase: mockSubmitUseCase,
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test(
      'records "quiz" activity type when quiz mode completes',
      () async {
        // Use startQuizFromPastQuestions to avoid locator deps from
        // startQuizFromDeck (DecksRepository lookup), then call submitQuiz
        // directly. This isolates just the quiz→tracker integration.
        final result = _fakeResult();

        when(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).thenAnswer((_) async => Right(result));

        cubit.startQuizFromPastQuestions(
          title: 'Math Quiz',
          questions: [_fakeQuestion()],
        );
        await cubit.submitQuiz();

        // Allow unawaited microtasks to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: any(named: 'durationSeconds'),
            activityType: 'quiz',
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        ).called(1);
      },
    );

    test(
      'records "cbt" activity type when exam simulation mode completes',
      () async {
        final result = _fakeResult(durationSeconds: 300);

        when(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).thenAnswer((_) async => Right(result));

        cubit.startQuizFromPastQuestions(
          title: 'CBT Exam',
          questions: [_fakeQuestion()],
          assessmentMode: AssessmentMode.examSimulationMode,
        );
        await cubit.submitQuiz();

        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: any(named: 'durationSeconds'),
            activityType: 'cbt',
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        ).called(1);
      },
    );

    test(
      'does NOT call tracker when StudyActivityTracker is not registered',
      () async {
        await GetIt.instance.reset(); // unregister tracker

        final result = _fakeResult();

        when(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).thenAnswer((_) async => Right(result));

        final localCubit = QuizSessionCubit(
          generateQuizUseCase: mockGenerateUseCase,
          submitQuizUseCase: mockSubmitUseCase,
        );
        addTearDown(localCubit.close);

        localCubit.startQuizFromPastQuestions(
          title: 'Math Quiz',
          questions: [_fakeQuestion()],
        );
        await localCubit.submitQuiz();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // mockTracker was never registered so it never gets invoked
        verifyNever(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: any(named: 'durationSeconds'),
            activityType: any(named: 'activityType'),
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        );
      },
    );

    test(
      'transitions to QuizSessionStatus.completed on successful submit',
      () async {
        final result = _fakeResult();

        when(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).thenAnswer((_) async => Right(result));

        cubit.startQuizFromPastQuestions(
          title: 'Math Quiz',
          questions: [_fakeQuestion()],
        );
        await cubit.submitQuiz();

        expect(cubit.state.status, QuizSessionStatus.completed);
        expect(cubit.state.result, equals(result));
      },
    );

    test(
      'does NOT record activity when submit fails',
      () async {
        when(
          () => mockSubmitUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Submit failed')),
        );

        cubit.startQuizFromPastQuestions(
          title: 'Math Quiz',
          questions: [_fakeQuestion()],
        );
        await cubit.submitQuiz();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verifyNever(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: any(named: 'durationSeconds'),
            activityType: any(named: 'activityType'),
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        );
        expect(cubit.state.status, QuizSessionStatus.error);
      },
    );
  });

  // -------------------------------------------------------------------------
  // QuizDuelCubit → StudyActivityTracker
  // -------------------------------------------------------------------------

  group('QuizDuelCubit → StudyActivityTracker integration', () {
    late MockStudyActivityTracker mockTracker;
    late MockQuizDuelRepository mockDuelRepo;
    late QuizDuelCubit cubit;

    setUpAll(() {
      registerFallbackValue(_fakeMatch());
    });

    setUp(() async {
      await GetIt.instance.reset();
      mockTracker = MockStudyActivityTracker();
      mockDuelRepo = MockQuizDuelRepository();

      when(
        () => mockTracker.recordActivityCompletion(
          durationSeconds: any(named: 'durationSeconds'),
          activityType: any(named: 'activityType'),
          circleId: any(named: 'circleId'),
          metadata: any(named: 'metadata'),
        ),
      ).thenAnswer((_) async => 2);

      GetIt.instance.registerSingleton<StudyActivityTracker>(mockTracker);
      cubit = QuizDuelCubit(repository: mockDuelRepo);
    });

    tearDown(() async {
      await cubit.close();
    });

    test(
      'records "duel" activity type when match reaches finished status',
      () async {
        // Start with non-finished match so cubit state is non-finished,
        // then stream emits finished → isJustFinished = true → tracker fires.
        final matchingMatch = _fakeMatch(
          status: QuizDuelStatus.matching,
          durationPerQuestion: 20,
        );
        final finishedMatch = _fakeMatch(
          winnerUserId: 'player1',
          durationPerQuestion: 20,
        );

        final streamController = StreamController<QuizDuelMatch>();

        when(
          () => mockDuelRepo.findOrCreateDuel(
            subject: any(named: 'subject'),
            examBoard: any(named: 'examBoard'),
            userId: any(named: 'userId'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
            questionCount: any(named: 'questionCount'),
          ),
        ).thenAnswer((_) async => Right(matchingMatch));

        when(
          () => mockDuelRepo.streamDuel(any()),
        ).thenAnswer((_) => streamController.stream);

        when(
          () => mockDuelRepo.recordDuelOutcome(any()),
        ).thenAnswer(
          (_) async =>
              const Right(<String, dynamic>{'success': true}),
        );

        await cubit.startMatchmaking(
          subject: 'Biology',
          examBoard: 'WAEC',
          userId: 'player1',
          displayName: 'Alice',
          avatarUrl: '',
        );

        // Emit a finished match → triggers isJustFinished logic
        streamController.add(finishedMatch);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: any(named: 'durationSeconds'),
            activityType: 'duel',
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        ).called(1);

        await streamController.close();
      },
    );

    test(
      'calculates duel duration as questions × durationPerQuestion',
      () async {
        // Start with matching, stream finished: 4 × 25 = 100s
        final matchingMatch = _fakeMatch(
          status: QuizDuelStatus.matching,
          questionCount: 4,
          durationPerQuestion: 25,
        );
        final finishedMatch = _fakeMatch(
          questionCount: 4,
          durationPerQuestion: 25,
        );

        final streamController = StreamController<QuizDuelMatch>();

        when(
          () => mockDuelRepo.findOrCreateDuel(
            subject: any(named: 'subject'),
            examBoard: any(named: 'examBoard'),
            userId: any(named: 'userId'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
            questionCount: any(named: 'questionCount'),
          ),
        ).thenAnswer((_) async => Right(matchingMatch));

        when(() => mockDuelRepo.streamDuel(any()))
            .thenAnswer((_) => streamController.stream);

        when(() => mockDuelRepo.recordDuelOutcome(any()))
            .thenAnswer(
          (_) async =>
              const Right(<String, dynamic>{'success': true}),
        );

        await cubit.startMatchmaking(
          subject: 'Biology',
          examBoard: 'WAEC',
          userId: 'player1',
          displayName: 'Alice',
          avatarUrl: '',
        );

        streamController.add(finishedMatch);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // 4 × 25 = 100 seconds
        verify(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: 100,
            activityType: 'duel',
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        ).called(1);

        await streamController.close();
      },
    );

    test(
      'falls back to 60s duration when computed total is 0',
      () async {
        // Start with matching, stream 0-question finished match → fallback 60s
        final matchingMatch = _fakeMatch(
          status: QuizDuelStatus.matching,
          questionCount: 0,
          durationPerQuestion: 15,
        );
        final finishedMatch = _fakeMatch(
          questionCount: 0,
          durationPerQuestion: 15,
        );

        final streamController = StreamController<QuizDuelMatch>();

        when(
          () => mockDuelRepo.findOrCreateDuel(
            subject: any(named: 'subject'),
            examBoard: any(named: 'examBoard'),
            userId: any(named: 'userId'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
            questionCount: any(named: 'questionCount'),
          ),
        ).thenAnswer((_) async => Right(matchingMatch));

        when(() => mockDuelRepo.streamDuel(any()))
            .thenAnswer((_) => streamController.stream);

        when(() => mockDuelRepo.recordDuelOutcome(any()))
            .thenAnswer(
          (_) async =>
              const Right(<String, dynamic>{'success': true}),
        );

        await cubit.startMatchmaking(
          subject: 'Biology',
          examBoard: 'WAEC',
          userId: 'player1',
          displayName: 'Alice',
          avatarUrl: '',
        );

        streamController.add(finishedMatch);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: 60, // fallback when total=0
            activityType: 'duel',
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        ).called(1);

        await streamController.close();
      },
    );

    test(
      'does NOT record activity for non-finished match updates',
      () async {
        final inProgressMatch = _fakeMatch(status: QuizDuelStatus.inRound);
        final finishedMatch = _fakeMatch(
          winnerUserId: 'player1',
        );

        final streamController = StreamController<QuizDuelMatch>();

        when(
          () => mockDuelRepo.findOrCreateDuel(
            subject: any(named: 'subject'),
            examBoard: any(named: 'examBoard'),
            userId: any(named: 'userId'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
            questionCount: any(named: 'questionCount'),
          ),
        ).thenAnswer((_) async => Right(inProgressMatch));

        when(() => mockDuelRepo.streamDuel(any()))
            .thenAnswer((_) => streamController.stream);

        when(() => mockDuelRepo.recordDuelOutcome(any()))
            .thenAnswer(
          (_) async =>
              const Right(<String, dynamic>{'success': true}),
        );

        await cubit.startMatchmaking(
          subject: 'Biology',
          examBoard: 'WAEC',
          userId: 'player1',
          displayName: 'Alice',
          avatarUrl: '',
        );

        // Emit active match update only — no finished yet
        streamController.add(inProgressMatch);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verifyNever(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: any(named: 'durationSeconds'),
            activityType: any(named: 'activityType'),
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        );

        // Now emit the finished match → should record
        streamController.add(finishedMatch);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(
          () => mockTracker.recordActivityCompletion(
            durationSeconds: any(named: 'durationSeconds'),
            activityType: 'duel',
            circleId: any(named: 'circleId'),
            metadata: any(named: 'metadata'),
          ),
        ).called(1);

        await streamController.close();
      },
    );
  });

  // -------------------------------------------------------------------------
  // StudyActivityTracker duration rounding — edge cases
  // -------------------------------------------------------------------------

  group('StudyActivityTracker → duration rounding edge cases', () {
    late MockCommunityRepository mockRepo;
    late StudyActivityTracker tracker;

    setUpAll(() {
      registerFallbackValue('');
    });

    setUp(() async {
      await GetIt.instance.reset();
      mockRepo = MockCommunityRepository();

      when(
        () => mockRepo.recordPodFocusMinutes(
          circleId: any(named: 'circleId'),
          minutes: any(named: 'minutes'),
          activityType: any(named: 'activityType'),
        ),
      ).thenAnswer(
        (_) async =>
            const Right(<String, dynamic>{'success': true}),
      );

      GetIt.instance.registerSingleton<CommunityRepository>(mockRepo);
      tracker = StudyActivityTrackerImpl(repository: mockRepo);
    });

    test('14 seconds → 0 minutes (below 15s threshold)', () async {
      final mins = await tracker.recordActivityCompletion(
        durationSeconds: 14,
        activityType: 'quiz',
      );
      expect(mins, 0);
      verifyNever(
        () => mockRepo.recordPodFocusMinutes(
          circleId: any(named: 'circleId'),
          minutes: any(named: 'minutes'),
          activityType: any(named: 'activityType'),
        ),
      );
    });

    test('15 seconds → 1 minute minimum', () async {
      final mins = await tracker.recordActivityCompletion(
        durationSeconds: 15,
        activityType: 'deck',
      );
      expect(mins, 1);
    });

    test('89 seconds → 1 minute minimum (< 90s rounding boundary)', () async {
      final mins = await tracker.recordActivityCompletion(
        durationSeconds: 89,
        activityType: 'deck',
      );
      expect(mins, 1);
    });

    test('90 seconds → 2 minutes (first full rounding boundary)', () async {
      final mins = await tracker.recordActivityCompletion(
        durationSeconds: 90,
        activityType: 'focus_session',
      );
      // (90 + 30) ~/ 60 = 2
      expect(mins, 2);
    });

    test('3600 seconds (1 hour) → 60 minutes', () async {
      final mins = await tracker.recordActivityCompletion(
        durationSeconds: 3600,
        activityType: 'live_room',
      );
      // (3600 + 30) ~/ 60 = 60
      expect(mins, 60);
    });

    test('records each activity type with correct label', () async {
      const activities = [
        'quiz',
        'cbt',
        'duel',
        'deck',
        'focus_session',
        'live_room',
      ];
      for (final activity in activities) {
        await tracker.recordActivityCompletion(
          durationSeconds: 120,
          activityType: activity,
        );
      }

      for (final activity in activities) {
        verify(
          () => mockRepo.recordPodFocusMinutes(
            circleId: '',
            minutes: 2,
            activityType: activity,
          ),
        ).called(1);
      }
    });

    test(
      'handles repository failure gracefully and still returns computed minutes',
      () async {
        when(
          () => mockRepo.recordPodFocusMinutes(
            circleId: any(named: 'circleId'),
            minutes: any(named: 'minutes'),
            activityType: any(named: 'activityType'),
          ),
        ).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Network error')),
        );

        final mins = await tracker.recordActivityCompletion(
          durationSeconds: 300,
          activityType: 'cbt',
        );

        expect(mins, 5);
      },
    );

    test(
      'handles repository exception gracefully without re-throwing',
      () async {
        when(
          () => mockRepo.recordPodFocusMinutes(
            circleId: any(named: 'circleId'),
            minutes: any(named: 'minutes'),
            activityType: any(named: 'activityType'),
          ),
        ).thenThrow(Exception('Unexpected server error'));

        final result = tracker.recordActivityCompletion(
          durationSeconds: 120,
          activityType: 'quiz',
        );

        await expectLater(result, completes);
      },
    );

    test(
      'passes circleId to repository when explicitly provided',
      () async {
        await tracker.recordActivityCompletion(
          durationSeconds: 120,
          activityType: 'quiz',
          circleId: 'circle-123',
        );

        verify(
          () => mockRepo.recordPodFocusMinutes(
            circleId: 'circle-123',
            minutes: 2,
            activityType: 'quiz',
          ),
        ).called(1);
      },
    );
  });
}
