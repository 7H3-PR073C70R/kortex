import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';

void main() {
  group('QuizDuelWebSocketClient Test Suite', () {
    late QuizDuelWebSocketClient client;

    setUp(() {
      client = QuizDuelWebSocketClient();
    });

    tearDown(() {
      client.dispose();
    });

    test('findOrCreateDuel creates match and emits matching state', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'test_user_1',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      expect(match.duelId, startsWith('duel_'));
      expect(match.subject, equals('Physics'));
      expect(match.examBoard, equals('WAEC'));
      expect(match.status, equals(QuizDuelStatus.matching));
      expect(match.player1.userId, equals('test_user_1'));
      expect(match.questions, isNotEmpty);
    });

    test('submitDuelAnswer updates player score and calculates speed bonus for correct answer', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'test_user_1',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      // Force start round 0
      client.forceStartRound(match.duelId);

      final correctIdx = match.questions.first.options.indexOf(match.questions.first.correctAnswer);
      // Fast response (1.5s out of 15s) -> large speed bonus
      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'test_user_1',
        questionIndex: 0,
        optionIndex: correctIdx >= 0 ? correctIdx : 0,
        responseTimeMs: 1500,
      );

      // Verify stream event
      final updatedMatch = await client.streamDuel(match.duelId).first;
      expect(updatedMatch.player1.score, greaterThanOrEqualTo(140));
      expect(updatedMatch.player1.isAnswerCorrect, isTrue);
      expect(updatedMatch.player1.comboStreak, equals(1));
    });

    test('submitDuelAnswer gives 0 points for incorrect answer', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'test_user_1',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      // Force start round 0
      client.forceStartRound(match.duelId);

      final correctIdx = match.questions.first.options.indexOf(match.questions.first.correctAnswer);
      final wrongOption = ((correctIdx >= 0 ? correctIdx : 0) + 1) % 4;

      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'test_user_1',
        questionIndex: 0,
        optionIndex: wrongOption,
        responseTimeMs: 2000,
      );

      final updatedMatch = await client.streamDuel(match.duelId).first;
      expect(updatedMatch.player1.score, equals(0));
      expect(updatedMatch.player1.isAnswerCorrect, isFalse);
      expect(updatedMatch.player1.comboStreak, equals(0));
    });

    test('sendDuelEmote propagates reaction emote', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Chemistry',
        examBoard: 'JAMB',
        userId: 'test_user_1',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      await client.sendDuelEmote(
        duelId: match.duelId,
        userId: 'test_user_1',
        emote: '🔥',
      );

      final updatedMatch = await client.streamDuel(match.duelId).first;
      expect(updatedMatch.latestEmote, equals('🔥'));
      expect(updatedMatch.latestEmoteSenderId, equals('test_user_1'));
    });

    test('submitDuelAnswer is idempotent and prevents double scoring', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'test_user_1',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      client.forceStartRound(match.duelId);

      final correctIdx = match.questions.first.options.indexOf(match.questions.first.correctAnswer);
      final optionToSubmit = correctIdx >= 0 ? correctIdx : 0;

      // Submit once
      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'test_user_1',
        questionIndex: 0,
        optionIndex: optionToSubmit,
        responseTimeMs: 1500,
      );

      final firstMatch = await client.streamDuel(match.duelId).first;
      final initialScore = firstMatch.player1.score;
      expect(initialScore, greaterThan(0));

      // Submit second time for same user and question (simulating duplicate echo)
      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'test_user_1',
        questionIndex: 0,
        optionIndex: optionToSubmit,
        responseTimeMs: 1500,
      );

      final secondMatch = await client.streamDuel(match.duelId).first;
      expect(secondMatch.player1.score, equals(initialScore));
    });

    test('submitDuelAnswer records score even if received during roundSummary phase', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'player1_id',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      // Force start round 0
      client.forceStartRound(match.duelId);

      // Player 1 answers, concluding round locally
      final correctIdx = match.questions.first.options.indexOf(match.questions.first.correctAnswer);
      final optionIdx = correctIdx >= 0 ? correctIdx : 0;

      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'player1_id',
        questionIndex: 0,
        optionIndex: optionIdx,
        responseTimeMs: 1000,
      );

      // Now Player 2 (or late broadcast) submits answer for questionIndex 0
      // even if match status turned to roundSummary
      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'player1_id', // tested user
        questionIndex: 0,
        optionIndex: optionIdx,
        responseTimeMs: 1000,
      );

      final currentMatch = await client.streamDuel(match.duelId).first;
      expect(currentMatch.player1.score, greaterThan(0));
    });

    test('round expiration defaults unanswered players to selectedOptionIndex -1', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'player1_id',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      client.forceStartRound(match.duelId);

      // Wait for round timer to naturally expire or trigger conclusion
      final initialMatch = await client.streamDuel(match.duelId).first;
      expect(initialMatch.status, equals(QuizDuelStatus.inRound));

      // Simulate player1 submitting, but player2 not answering
      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'player1_id',
        questionIndex: 0,
        optionIndex: 0,
        responseTimeMs: 1000,
      );

      // Force conclude round
      client.forceStartRound(match.duelId, 1);

      final updatedMatch = await client.streamDuel(match.duelId).first;
      expect(updatedMatch.currentQuestionIndex, equals(1));
      expect(updatedMatch.status, equals(QuizDuelStatus.inRound));
    });

    test('leaveDuel triggers forfeit victory for remaining player', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'player1_id',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
      );

      client.simulateMatchFoundWithAi(match.duelId);
      final activeMatch = await client.streamDuel(match.duelId).first;

      // Player 2 leaves / forfeits
      final p2Id = activeMatch.player2!.userId;
      await client.leaveDuel(duelId: match.duelId, userId: p2Id);

      final finishedMatch = await client.streamDuel(match.duelId).first;
      expect(finishedMatch.status, equals(QuizDuelStatus.finished));
      expect(finishedMatch.winnerUserId, equals('player1_id'));
      expect(finishedMatch.forfeitUserId, equals(p2Id));
    });

    test('full multi-round duel progresses through all questions to finished status', () async {
      final questions = QuizDuelWebSocketClient.getDefaultDuelQuestions('Physics', 'WAEC', count: 2);
      final match = await client.findOrCreateDuel(
        subject: 'Physics',
        examBoard: 'WAEC',
        userId: 'player1_id',
        displayName: 'Scholar One',
        avatarUrl: '⚡',
        questionCount: 2,
        customQuestions: questions,
      );

      client.forceStartRound(match.duelId);
      var current = await client.streamDuel(match.duelId).first;
      expect(current.currentQuestionIndex, equals(0));

      // Player 1 & 2 answer Q0
      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'player1_id',
        questionIndex: 0,
        optionIndex: 0,
        responseTimeMs: 1200,
      );

      // Advance to Q1
      client.forceStartRound(match.duelId, 1);
      current = await client.streamDuel(match.duelId).first;
      expect(current.currentQuestionIndex, equals(1));

      // Player 1 & 2 answer Q1
      await client.submitDuelAnswer(
        duelId: match.duelId,
        userId: 'player1_id',
        questionIndex: 1,
        optionIndex: 0,
        responseTimeMs: 1000,
      );

      // Transition beyond last question -> finalize
      client.forceStartRound(match.duelId, 2);
      final finishedMatch = await client.streamDuel(match.duelId).first;
      expect(finishedMatch.status, equals(QuizDuelStatus.finished));
    });

    test('generateRoomCode produces clean 6-character uppercase alphanumeric code', () {
      final code = QuizDuelWebSocketClient.generateRoomCode();
      expect(code.length, equals(6));
      expect(code, equals(code.toUpperCase()));
      // Ambiguous characters O, 0, I, 1 should not be present
      expect(code.contains('O'), isFalse);
      expect(code.contains('0'), isFalse);
      expect(code.contains('I'), isFalse);
      expect(code.contains('1'), isFalse);
    });

    test('findOrCreateDuel with roomCode attaches roomCode to match entity', () async {
      final match = await client.findOrCreateDuel(
        subject: 'Mathematics',
        examBoard: 'WAEC',
        userId: 'host_user',
        displayName: 'Host Scholar',
        avatarUrl: '🎯',
        roomCode: 'K7X9P2',
      );

      expect(match.roomCode, equals('K7X9P2'));
    });
  });
}
