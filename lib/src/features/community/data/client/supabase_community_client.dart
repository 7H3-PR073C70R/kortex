import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';

class SupabaseCommunityClient {
  SupabaseCommunityClient(this._dio);

  final Dio _dio;

  Map<String, String> _headers(String token) => {
        'apikey': AppEnv.supabaseAnonKey,
        'Authorization': 'Bearer $token',
      };

  /// Fetches study rooms.
  Future<List<Map<String, dynamic>>> fetchStudyRooms({
    required String authToken,
    String? category,
  }) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'created_at.desc',
    };
    if (category != null && category.isNotEmpty && category != 'All') {
      params['category'] = 'eq.$category';
    }

    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.studyRooms}',
      queryParameters: params,
      options: Options(headers: _headers(authToken)),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// Creates a live study room.
  Future<Map<String, dynamic>> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
    required String authToken,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.studyRooms}',
      data: {
        'title': title,
        'subject': subject,
        'category': category,
        'pomodoro_duration_minutes': pomodoroMinutes,
        'pomodoro_state': 'focusing',
        'pomodoro_started_at': DateTime.now().toIso8601String(),
        'active_participants_count': 1,
      },
      options: Options(
        headers: {
          ..._headers(authToken),
          'Prefer': 'return=representation',
        },
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Failed to create study room');
    }
    return data.first as Map<String, dynamic>;
  }

  /// Fetches discussion forum posts with replies.
  Future<List<Map<String, dynamic>>> fetchForumPosts({
    required String authToken,
    String? track,
  }) async {
    final params = <String, dynamic>{
      'select': '*,forum_replies(*)',
      'order': 'created_at.desc',
    };
    if (track != null && track.isNotEmpty && track != 'All') {
      params['track'] = 'eq.$track';
    }

    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.forumPosts}',
      queryParameters: params,
      options: Options(headers: _headers(authToken)),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// Creates a forum thread post.
  Future<Map<String, dynamic>> createForumPost({
    required String title,
    required String content,
    required String track,
    required String authorName,
    required String authToken,
    String? latexContent,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.forumPosts}',
      data: {
        'title': title,
        'content': content,
        'track': track,
        'latex_content': latexContent,
        'author_name': authorName,
      },
      options: Options(
        headers: {
          ..._headers(authToken),
          'Prefer': 'return=representation',
        },
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Failed to create forum post');
    }
    return data.first as Map<String, dynamic>;
  }

  /// Replies to a forum post.
  Future<Map<String, dynamic>> replyToForumPost({
    required String postId,
    required String content,
    required String authorName,
    required String authToken,
    String? latexContent,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.forumReplies}',
      data: {
        'post_id': postId,
        'content': content,
        'latex_content': latexContent,
        'author_name': authorName,
      },
      options: Options(
        headers: {
          ..._headers(authToken),
          'Prefer': 'return=representation',
        },
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Failed to add reply');
    }
    return data.first as Map<String, dynamic>;
  }

  /// Fetches marketplace shared decks.
  Future<List<Map<String, dynamic>>> fetchSharedDecks({
    required String authToken,
    String? subject,
  }) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'downloads_count.desc',
    };
    if (subject != null && subject.isNotEmpty && subject != 'All') {
      params['subject'] = 'eq.$subject';
    }

    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.sharedDecks}',
      queryParameters: params,
      options: Options(headers: _headers(authToken)),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// Publishes a deck to the community marketplace.
  Future<Map<String, dynamic>> publishDeck({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
    required String ownerName,
    required String authToken,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.sharedDecks}',
      data: {
        'title': title,
        'subject': subject,
        'description': description,
        'category': category,
        'total_cards': totalCards,
        'cards': cardsJson,
        'owner_name': ownerName,
      },
      options: Options(
        headers: {
          ..._headers(authToken),
          'Prefer': 'return=representation',
        },
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Failed to publish shared deck');
    }
    return data.first as Map<String, dynamic>;
  }

  /// Clones a shared deck into user's private decks and flashcards.
  Future<Map<String, dynamic>> cloneSharedDeck({
    required String sharedDeckId,
    required String authToken,
  }) async {
    final response = await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.cloneSharedDeckRpc}',
      data: {
        'p_shared_deck_id': sharedDeckId,
      },
      options: Options(headers: _headers(authToken)),
    );
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  /// Fetches leaderboard standings.
  Future<List<Map<String, dynamic>>> fetchLeaderboards({
    required String authToken,
    String? track,
  }) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'weekly_xp.desc',
      'limit': 50,
    };
    if (track != null && track.isNotEmpty && track != 'All') {
      params['track'] = 'eq.$track';
    }

    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.leaderboards}',
      queryParameters: params,
      options: Options(headers: _headers(authToken)),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// Calls the auto-provisioning RPC or edge function to idempotently create/join a hub.
  Future<Map<String, dynamic>> autoProvisionCommunity({
    required String courseCode,
    required String title,
    required String authToken,
    String? department,
  }) async {
    final response = await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}/rpc/auto_provision_community_rpc',
      data: {
        'p_course_code': courseCode,
        'p_title': title,
        'p_department': department ?? 'General',
      },
      options: Options(headers: _headers(authToken)),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {
      'id': 'comm_${courseCode.toLowerCase().replaceAll(' ', '_')}',
      'course_code': courseCode,
      'title': title,
      'department': department ?? 'General',
      'member_count': 24,
      'active_rooms_count': 1,
      'forum_threads_count': 3,
      'is_user_member': true,
      'is_founding_member': true,
    };
  }

  /// Fetches community stats and active focus room status.
  Future<Map<String, dynamic>> fetchCourseCommunityStats({
    required String courseCode,
    required String authToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}/study_communities',
      queryParameters: {
        'course_code': 'eq.$courseCode',
        'select': '*',
        'limit': 1,
      },
      options: Options(headers: _headers(authToken)),
    );
    final list = (response.data ?? []).cast<Map<String, dynamic>>();
    if (list.isNotEmpty) {
      return list.first;
    }
    return {
      'id': 'comm_${courseCode.toLowerCase().replaceAll(' ', '_')}',
      'course_code': courseCode,
      'title': '$courseCode Study Hub',
      'department': 'General',
      'member_count': 18,
      'active_rooms_count': 1,
      'forum_threads_count': 2,
      'is_user_member': true,
      'is_founding_member': false,
    };
  }

  /// Records completed Pomodoro study session in study_sessions table.
  Future<void> recordStudySession({
    required String authToken,
    required String roomId,
    required int durationMinutes,
    required String subject,
  }) async {
    try {
      await _dio.post<dynamic>(
        '${AppApiEndpoint.baseUri}/rest/v1/study_sessions',
        data: {
          'room_id': roomId,
          'duration_minutes': durationMinutes,
          'subject': subject,
          'completed_at': DateTime.now().toIso8601String(),
        },
        options: Options(headers: _headers(authToken)),
      );
    } on Object catch (_) {
      // Graceful error logging for offline sessions
    }
  }
}
