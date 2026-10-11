import 'package:dio/dio.dart';
import 'package:kortex/src/core/utils/app_logger.dart';

abstract class QuizDuelRemoteDataSource {
  Future<Map<String, dynamic>> recordDuelOutcome({
    required String duelId,
    required int player1Score,
    required int player2Score,
    required bool isDraw,
    required bool isForfeit,
    String? subject,
    String? examBoard,
    String? player1Id,
    String? player2Id,
    String? winnerId,
    String? forfeitUserId,
    int? timeTakenSeconds,
    String? clientVersion,
  });

  Future<List<Map<String, dynamic>>> getEloLeaderboard({
    String? subject,
    int limit = 20,
  });

  Future<void> createAsyncChallenge({
    required String duelId,
    required String subject,
    required String examBoard,
    required String player1Id,
    required String player2Id,
    required List<Map<String, dynamic>> questions,
  });

  Future<List<Map<String, dynamic>>> getPendingAsyncChallenges(String userId);
}

class QuizDuelRemoteDataSourceImpl implements QuizDuelRemoteDataSource {
  const QuizDuelRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> recordDuelOutcome({
    required String duelId,
    required int player1Score,
    required int player2Score,
    required bool isDraw,
    required bool isForfeit,
    String? subject,
    String? examBoard,
    String? player1Id,
    String? player2Id,
    String? winnerId,
    String? forfeitUserId,
    int? timeTakenSeconds,
    String? clientVersion,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/rest/v1/rpc/fn_process_quiz_duel_outcome',
        data: {
          'p_duel_id': duelId,
          'p_player1_id': player1Id,
          'p_player2_id': player2Id,
          'p_player1_score': player1Score,
          'p_player2_score': player2Score,
          'p_winner_id': winnerId,
          'p_is_draw': isDraw,
          'p_is_forfeit': isForfeit,
          'p_forfeit_user_id': forfeitUserId,
          'p_time_taken_seconds': timeTakenSeconds,
          'p_client_version': clientVersion ?? '1.0.0',
        },
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && player1Id != null) {
        try {
          await _dio.post<dynamic>(
            '/rest/v1/quiz_duels',
            data: {
              'duel_id': duelId,
              'subject': subject ?? 'General',
              'exam_board': examBoard ?? 'WAEC',
              'player1_id': player1Id,
              'player2_id': ?player2Id,
              'player1_score': player1Score,
              'player2_score': player2Score,
              'winner_user_id': ?winnerId,
              'is_draw': isDraw,
              'is_forfeit': isForfeit,
              'forfeit_user_id': ?forfeitUserId,
            },
          );
          return const <String, dynamic>{'status': 'inserted_via_fallback'};
        } on Object catch (e, st) { AppLogger.recordNonFatal(e, st); }
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getEloLeaderboard({
    String? subject,
    int limit = 20,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/rest/v1/profiles',
      queryParameters: {
        'select': 'id,display_name,photo_url,elo_rating,academic_institution,level',
        'order': 'elo_rating.desc.nullslast',
        'limit': limit,
      },
    );

    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final mapped = Map<String, dynamic>.from(item);
          mapped['avatar_url'] = item['photo_url'] ?? item['avatar_url'] ?? '';
          return mapped;
        })
        .toList();
  }

  @override
  Future<void> createAsyncChallenge({
    required String duelId,
    required String subject,
    required String examBoard,
    required String player1Id,
    required String player2Id,
    required List<Map<String, dynamic>> questions,
  }) async {
    await _dio.post<void>(
      '/rest/v1/quiz_duels',
      data: {
        'duel_id': duelId,
        'subject': subject,
        'exam_board': examBoard,
        'player1_id': player1Id,
        'player2_id': player2Id,
        'player1_score': 0,
        'player2_score': 0,
        'questions_snapshot': questions,
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingAsyncChallenges(
    String userId,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      '/rest/v1/quiz_duels',
      queryParameters: {
        'player2_id': 'eq.$userId',
        'winner_user_id': 'is.null',
        'is_draw': 'eq.false',
        'order': 'created_at.desc',
        'limit': 10,
      },
    );

    return (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }
}
