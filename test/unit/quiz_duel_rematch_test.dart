import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:mocktail/mocktail.dart';

class MockQuizDuelRepository extends Mock implements QuizDuelRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  QuizQuestionEntity fakeQuestion(String id) {
    return QuizQuestionEntity(
      id: id,
      prompt: 'What is the velocity of light in vacuum?',
      type: QuizQuestionType.multipleChoice,
      options: const ['3x10^8 m/s', '2x10^8 m/s', '1.5x10^8 m/s', '4x10^8 m/s'],
      correctAnswer: '3x10^8 m/s',
      explanation: 'Fundamental physical constant c.',
      subTopic: 'Physics',
    );
  }

  QuizDuelMatch fakeDuelMatch({
    String duelId = 'duel-100',
    QuizDuelStatus status = QuizDuelStatus.finished,
    bool isAiOpponent = false,
    String? rematchRequestedBy,
    bool rematchAccepted = false,
    String? nextDuelId,
    DateTime? createdAt,
  }) {
    return QuizDuelMatch(
      duelId: duelId,
      subject: 'Physics',
      examBoard: 'WAEC',
      questions: [fakeQuestion('q1'), fakeQuestion('q2')],
      player1: const QuizDuelParticipant(
        userId: 'user-1',
        displayName: 'Alice',
        avatarUrl: '⚡',
        score: 450,
      ),
      player2: QuizDuelParticipant(
        userId: isAiOpponent ? 'ai_bot_99' : 'user-2',
        displayName: isAiOpponent ? 'Amina' : 'Bob',
        avatarUrl: '🧠',
        score: 300,
        isAiOpponent: isAiOpponent,
      ),
      status: status,
      createdAt: createdAt ?? DateTime.utc(2026, 10),
      rematchRequestedBy: rematchRequestedBy,
      rematchAccepted: rematchAccepted,
      nextDuelId: nextDuelId,
    );
  }

  group('QuizDuelMatch Entity Rematch Tests', () {
    test('toJson and fromJson preserves all rematch fields', () {
      final original = fakeDuelMatch(
        rematchRequestedBy: 'user-1',
        rematchAccepted: true,
        nextDuelId: 'duel-101',
      );

      final json = original.toJson();
      expect(json['rematchRequestedBy'], equals('user-1'));
      expect(json['rematchAccepted'], isTrue);
      expect(json['nextDuelId'], equals('duel-101'));

      final restored = QuizDuelMatch.fromJson(json);
      expect(restored.rematchRequestedBy, equals('user-1'));
      expect(restored.rematchAccepted, isTrue);
      expect(restored.nextDuelId, equals('duel-101'));
      expect(restored, equals(original));
    });

    test('copyWith clearRematch resets rematch fields cleanly', () {
      final original = fakeDuelMatch(
        rematchRequestedBy: 'user-2',
        rematchAccepted: true,
        nextDuelId: 'duel-102',
      );

      final cleared = original.copyWith(clearRematch: true);
      expect(cleared.rematchRequestedBy, isNull);
      expect(cleared.rematchAccepted, isFalse);
      expect(cleared.nextDuelId, isNull);
    });
  });

  group('QuizDuelState Rematch Helpers Tests', () {
    test('didIRequestRematch and didOpponentRequestRematch evaluate correctly', () {
      const state1 = QuizDuelState(currentUserId: 'user-1');
      expect(state1.didIRequestRematch, isFalse);
      expect(state1.didOpponentRequestRematch, isFalse);
      expect(state1.hasRematchRequest, isFalse);

      final stateWithMyRequest = state1.copyWith(
        match: fakeDuelMatch(rematchRequestedBy: 'user-1'),
      );
      expect(stateWithMyRequest.hasRematchRequest, isTrue);
      expect(stateWithMyRequest.didIRequestRematch, isTrue);
      expect(stateWithMyRequest.didOpponentRequestRematch, isFalse);

      final stateWithRivalRequest = state1.copyWith(
        match: fakeDuelMatch(rematchRequestedBy: 'user-2'),
      );
      expect(stateWithRivalRequest.hasRematchRequest, isTrue);
      expect(stateWithRivalRequest.didIRequestRematch, isFalse);
      expect(stateWithRivalRequest.didOpponentRequestRematch, isTrue);
    });

    test('isOpponentAi detects AI opponent accurately', () {
      final humanState = const QuizDuelState(currentUserId: 'user-1').copyWith(
        match: fakeDuelMatch(),
      );
      expect(humanState.isOpponentAi, isFalse);

      final aiState = const QuizDuelState(currentUserId: 'user-1').copyWith(
        match: fakeDuelMatch(isAiOpponent: true),
      );
      expect(aiState.isOpponentAi, isTrue);
    });
  });

  group('QuizDuelCubit Rematch Workflow Tests', () {
    late MockQuizDuelRepository mockRepo;
    late QuizDuelCubit cubit;

    setUp(() {
      mockRepo = MockQuizDuelRepository();
      cubit = QuizDuelCubit(repository: mockRepo);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('requestRematch sets isRematchLoading and emits updated match on success', () async {
      final match = fakeDuelMatch(rematchRequestedBy: 'user-1');
      when(() => mockRepo.requestRematch(duelId: 'duel-100', userId: 'user-1'))
          .thenAnswer((_) async => Right(match));

      cubit.emit(
        cubit.state.copyWith(
          currentUserId: 'user-1',
          match: fakeDuelMatch(),
          status: QuizDuelStatus.finished,
        ),
      );

      final future = cubit.requestRematch();
      expect(cubit.state.isRematchLoading, isTrue);

      await future;
      expect(cubit.state.isRematchLoading, isFalse);
      expect(cubit.state.match?.rematchRequestedBy, equals('user-1'));
      verify(() => mockRepo.requestRematch(duelId: 'duel-100', userId: 'user-1')).called(1);
    });

    test('acceptRematch sets isRematchLoading and transitions match on success', () async {
      final rematchMatch = fakeDuelMatch(
        duelId: 'duel-200',
        status: QuizDuelStatus.countdown,
        rematchAccepted: true,
      );
      when(() => mockRepo.acceptRematch(duelId: 'duel-100', userId: 'user-1'))
          .thenAnswer((_) async => Right(rematchMatch));
      when(() => mockRepo.streamDuel('duel-200'))
          .thenAnswer((_) => Stream.value(rematchMatch));

      cubit.emit(
        cubit.state.copyWith(
          currentUserId: 'user-1',
          match: fakeDuelMatch(rematchRequestedBy: 'user-2'),
          status: QuizDuelStatus.finished,
        ),
      );

      await cubit.acceptRematch();
      expect(cubit.state.isRematchLoading, isFalse);
      expect(cubit.state.match?.duelId, equals('duel-200'));
      expect(cubit.state.status, equals(QuizDuelStatus.countdown));
      verify(() => mockRepo.acceptRematch(duelId: 'duel-100', userId: 'user-1')).called(1);
    });

    test('declineRematch clears rematch state locally and remotely', () async {
      when(() => mockRepo.declineRematch(duelId: 'duel-100', userId: 'user-1'))
          .thenAnswer((_) async => const Right(null));

      cubit.emit(
        cubit.state.copyWith(
          currentUserId: 'user-1',
          match: fakeDuelMatch(rematchRequestedBy: 'user-2'),
          status: QuizDuelStatus.finished,
        ),
      );

      await cubit.declineRematch();
      expect(cubit.state.match?.rematchRequestedBy, isNull);
      verify(() => mockRepo.declineRematch(duelId: 'duel-100', userId: 'user-1')).called(1);
    });
  });

  group('QuizDuelWebSocketClient Rematch Integration Tests', () {
    late QuizDuelWebSocketClient client;

    setUp(() {
      client = QuizDuelWebSocketClient();
    });

    tearDown(() {
      client.dispose();
    });

    test('requestRematch with AI opponent immediately launches fresh AI match without delay', () async {
      final baseMatch = fakeDuelMatch(
        duelId: 'duel-ai-1',
        isAiOpponent: true,
      );

      // Seed match in client
      client.activeMatchesForTesting['duel-ai-1'] = baseMatch;

      final result = await client.requestRematch(
        duelId: 'duel-ai-1',
        userId: 'user-1',
      );

      expect(result, isNotNull);
      expect(result!.duelId, isNot(equals('duel-ai-1')));
      expect(result.status, equals(QuizDuelStatus.countdown));
      expect(result.player2?.isAiOpponent, isTrue);
      expect(result.rematchAccepted, isTrue);
    });

    test('requestRematch with human peer marks rematchRequestedBy and broadcasts', () async {
      final humanMatch = fakeDuelMatch(
        duelId: 'duel-human-1',
      );

      client.activeMatchesForTesting['duel-human-1'] = humanMatch;

      final result = await client.requestRematch(
        duelId: 'duel-human-1',
        userId: 'user-1',
      );

      expect(result, isNotNull);
      expect(result!.rematchRequestedBy, equals('user-1'));
    });

    test('requestRematch automatically accepts if rival had already requested rematch', () async {
      final mutualMatch = fakeDuelMatch(
        duelId: 'duel-mutual-1',
        rematchRequestedBy: 'user-2', // Rival already asked!
      );

      client.activeMatchesForTesting['duel-mutual-1'] = mutualMatch;

      final result = await client.requestRematch(
        duelId: 'duel-mutual-1',
        userId: 'user-1',
      );

      expect(result, isNotNull);
      expect(result!.duelId, isNot(equals('duel-mutual-1')));
      expect(result.status, equals(QuizDuelStatus.countdown));
      expect(result.rematchAccepted, isTrue);
    });
  });
}
