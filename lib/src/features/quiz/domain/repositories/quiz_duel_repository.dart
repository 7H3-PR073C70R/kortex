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
    int questionCount = 10,
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

  /// Immediately pairs with an AI bot opponent during active search.
  Future<Either<Failure, void>> matchWithAiImmediately({
    required String duelId,
  });

  /// Persists match outcome to remote database and updates ELO ratings via `fn_process_quiz_duel_outcome`.
  Future<Either<Failure, Map<String, dynamic>>> recordDuelOutcome(
    QuizDuelMatch match,
  );

  /// Fetches top ranked duelists sorted by ELO rating.
  Future<Either<Failure, List<Map<String, dynamic>>>> getEloLeaderboard({
    String? subject,
    int limit = 20,
  });

  /// Creates a 24-hour asynchronous duel challenge for an offline peer.
  Future<Either<Failure, QuizDuelMatch>> createAsyncChallenge({
    required String subject,
    required String examBoard,
    required String userId,
    required String targetUserId,
    required String displayName,
    required String avatarUrl,
  });

  /// Fetches pending 24-hour asynchronous challenges for a user.
  Future<Either<Failure, List<QuizDuelMatch>>> getPendingAsyncChallenges(
    String userId,
  );
}

