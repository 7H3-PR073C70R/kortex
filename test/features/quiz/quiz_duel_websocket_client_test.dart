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
      client.forceStartRound(match.duelId, 0);

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
      client.forceStartRound(match.duelId, 0);

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
  });
}
