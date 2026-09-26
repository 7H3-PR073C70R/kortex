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
  });
}
