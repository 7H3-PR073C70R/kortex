import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';

/// Contract for the 1v1 Quiz Duel multiplayer repository (QZ-13).
abstract class QuizDuelRepository {
  /// Finds an active matchmaking queue or creates a new 1v1 duel room.
  Future<Either<Failure, QuizDuelMatch>> findOrCreateDuel({
    required String subject,
    required String examBoard,
    required String userId,
    required String displayName,
    required String avatarUrl,
  });

  /// Streams real-time updates for an active duel match.
  Stream<QuizDuelMatch> streamDuel(String duelId);

  /// Submits an answer for the current question in the duel.
  Future<Either<Failure, void>> submitDuelAnswer({
    required String duelId,
    required String userId,
    required int questionIndex,
    required int optionIndex,
    required int responseTimeMs,
  });

  /// Broadcasts a live reaction emote (🔥, ⚡, 🤯, 👏, 🎯).
  Future<Either<Failure, void>> sendDuelEmote({
    required String duelId,
    required String userId,
    required String emote,
  });

  /// Forfeits or leaves the current duel match.
  Future<Either<Failure, void>> leaveDuel({
    required String duelId,
    required String userId,
  });
}
