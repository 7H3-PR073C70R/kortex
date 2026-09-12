import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';

/// Implementation of [QuizDuelRepository] wrapping [QuizDuelWebSocketClient].
class QuizDuelRepositoryImpl implements QuizDuelRepository {
  const QuizDuelRepositoryImpl({
    required QuizDuelWebSocketClient client,
  }) : _client = client;

  final QuizDuelWebSocketClient _client;

  @override
  Future<Either<Failure, QuizDuelMatch>> findOrCreateDuel({
    required String subject,
    required String examBoard,
    required String userId,
    required String displayName,
    required String avatarUrl,
  }) async {
    try {
      final match = await _client.findOrCreateDuel(
        subject: subject,
        examBoard: examBoard,
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      return Right(match);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<QuizDuelMatch> streamDuel(String duelId) {
    return _client.streamDuel(duelId);
  }

  @override
  Future<Either<Failure, void>> submitDuelAnswer({
    required String duelId,
    required String userId,
    required int questionIndex,
    required int optionIndex,
    required int responseTimeMs,
  }) async {
    try {
      await _client.submitDuelAnswer(
        duelId: duelId,
        userId: userId,
        questionIndex: questionIndex,
        optionIndex: optionIndex,
        responseTimeMs: responseTimeMs,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendDuelEmote({
    required String duelId,
    required String userId,
    required String emote,
  }) async {
    try {
      await _client.sendDuelEmote(
        duelId: duelId,
        userId: userId,
        emote: emote,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> leaveDuel({
    required String duelId,
    required String userId,
  }) async {
    try {
      await _client.leaveDuel(duelId: duelId, userId: userId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
