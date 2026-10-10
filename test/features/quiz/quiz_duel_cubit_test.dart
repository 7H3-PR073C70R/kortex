import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:mocktail/mocktail.dart';

class MockQuizDuelRepository extends Mock implements QuizDuelRepository {}

void main() {
  group('QuizDuelCubit Test Suite', () {
    late MockQuizDuelRepository repository;
    late QuizDuelMatch testMatch;

    setUp(() {
      repository = MockQuizDuelRepository();
      testMatch = QuizDuelMatch(
        duelId: 'test_duel_123',
        subject: 'Physics',
        examBoard: 'WAEC',
        questions: QuizDuelWebSocketClient.getDefaultDuelQuestions('Physics', 'WAEC'),
        player1: const QuizDuelParticipant(
          userId: 'user_1',
          displayName: 'Scholar One',
          avatarUrl: '⚡',
        ),
      );
    });

    test('initial state has matching status and 15s countdown', () {
      final cubit = QuizDuelCubit(repository: repository);
      expect(cubit.state.status, equals(QuizDuelStatus.matching));
      expect(cubit.state.remainingSeconds, equals(15));
      expect(cubit.state.selectedOptionIndex, isNull);
    });

    blocTest<QuizDuelCubit, QuizDuelState>(
      'startMatchmaking emits matching status and subscribes to stream',
      build: () {
        when(() => repository.findOrCreateDuel(
              subject: any(named: 'subject'),
              examBoard: any(named: 'examBoard'),
              userId: any(named: 'userId'),
              displayName: any(named: 'displayName'),
              avatarUrl: any(named: 'avatarUrl'),
            )).thenAnswer((_) async => Right(testMatch));
        when(() => repository.streamDuel(any()))
            .thenAnswer((_) => Stream.value(testMatch));
        return QuizDuelCubit(repository: repository);
      },
      act: (cubit) => cubit.startMatchmaking(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'user_1',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      ),
      expect: () => [
        const QuizDuelState(
          currentUserId: 'user_1',
        ),
        QuizDuelState(
          currentUserId: 'user_1',
          match: testMatch,
        ),
      ],
    );

    blocTest<QuizDuelCubit, QuizDuelState>(
      'startMatchmaking emits cancelled and sets failure when questions are unavailable',
      build: () {
        when(() => repository.findOrCreateDuel(
              subject: any(named: 'subject'),
              examBoard: any(named: 'examBoard'),
              userId: any(named: 'userId'),
              displayName: any(named: 'displayName'),
              avatarUrl: any(named: 'avatarUrl'),
            )).thenAnswer(
          (_) async => const Left(
            NoQuizQuestionsFailure(subject: 'Operating Systems'),
          ),
        );
        return QuizDuelCubit(repository: repository);
      },
      act: (cubit) => cubit.startMatchmaking(
        subject: 'Operating Systems',
        examBoard: 'BSC',
        userId: 'user_1',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      ),
      expect: () => [
        const QuizDuelState(
          currentUserId: 'user_1',
        ),
        predicate<QuizDuelState>((state) {
          return state.status == QuizDuelStatus.cancelled &&
              state.isQuestionsUnavailable &&
              state.missingQuestionsSubject == 'Operating Systems';
        }),
      ],
    );

    blocTest<QuizDuelCubit, QuizDuelState>(
      'submitAnswer locks selection and calls repository',
      build: () {
        when(() => repository.submitDuelAnswer(
              duelId: any(named: 'duelId'),
              userId: any(named: 'userId'),
              questionIndex: any(named: 'questionIndex'),
              optionIndex: any(named: 'optionIndex'),
              responseTimeMs: any(named: 'responseTimeMs'),
            )).thenAnswer((_) async => const Right(null));
        return QuizDuelCubit(repository: repository);
      },
      seed: () => QuizDuelState(
        status: QuizDuelStatus.inRound,
        currentUserId: 'user_1',
        match: testMatch.copyWith(status: QuizDuelStatus.inRound),
      ),
      act: (cubit) => cubit.submitAnswer(1),
      verify: (_) {
        verify(() => repository.submitDuelAnswer(
              duelId: 'test_duel_123',
              userId: 'user_1',
              questionIndex: 0,
              optionIndex: 1,
              responseTimeMs: any(named: 'responseTimeMs'),
            )).called(1);
      },
    );

    blocTest<QuizDuelCubit, QuizDuelState>(
      'forceAdvanceToNextRound calls repository.forceAdvanceToNextRound',
      build: () {
        when(() => repository.forceAdvanceToNextRound(any()))
            .thenAnswer((_) async => const Right(null));
        return QuizDuelCubit(repository: repository);
      },
      seed: () => QuizDuelState(
        status: QuizDuelStatus.roundSummary,
        currentUserId: 'user_1',
        match: testMatch.copyWith(status: QuizDuelStatus.roundSummary),
      ),
      act: (cubit) => cubit.forceAdvanceToNextRound(),
      verify: (_) {
        verify(() => repository.forceAdvanceToNextRound('test_duel_123')).called(1);
      },
    );

    test('summary safety watchdog automatically fires forceAdvanceToNextRound if roundSummary persists', () async {
      when(() => repository.forceAdvanceToNextRound(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repository.findOrCreateDuel(
            subject: any(named: 'subject'),
            examBoard: any(named: 'examBoard'),
            userId: any(named: 'userId'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
          )).thenAnswer((_) async => Right(testMatch));
      when(() => repository.streamDuel(any())).thenAnswer(
        (_) => Stream.value(
          testMatch.copyWith(status: QuizDuelStatus.roundSummary),
        ),
      );

      final cubit = QuizDuelCubit(repository: repository);
      await cubit.startMatchmaking(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'user_1',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      // Verify watchdog fires after 2.8s
      await Future<void>.delayed(const Duration(milliseconds: 2900));

      verify(() => repository.forceAdvanceToNextRound('test_duel_123')).called(1);
      await cubit.close();
    });
  });
}
