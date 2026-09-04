import 'dart:async';
import 'package:kortex/src/core/networking/realtime/realtime_client.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/data/models/leaderboard_entry_model.dart';
import 'package:kortex/src/features/community/data/models/shared_deck_model.dart';
import 'package:kortex/src/features/community/data/models/study_community_model.dart';
import 'package:kortex/src/features/community/data/models/study_room_model.dart';

class CommunityRemoteDataSourceImpl implements CommunityRemoteDataSource {
  CommunityRemoteDataSourceImpl(
    this._client, {
    UserStorageService? userStorage,
    RealtimeClient? realtimeClient,
  })  : _userStorage = userStorage,
        _realtime = realtimeClient ?? RealtimeClient.instance;

  final CommunityApiClient _client;
  final UserStorageService? _userStorage;
  final RealtimeClient _realtime;

  // In-memory cache of replies per post, rebuilt from DB snapshots + WS events
  final Map<String, List<ForumReplyModel>> _replyCache = {};

  @override
  Future<List<StudyRoomModel>> fetchStudyRooms({String? category}) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'created_at.desc',
    };
    if (category != null && category.isNotEmpty && category != 'All') {
      params['category'] = 'eq.$category';
    }

    final res = await _client.fetchStudyRooms(params);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    return rawList
        .map((e) => StudyRoomModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StudyRoomModel> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
  }) async {
    final userId = _userStorage?.getUserId();
    final res = await _client.createStudyRoom(
      {
        'title': title,
        'subject': subject,
        'category': category,
        'pomodoro_duration_minutes': pomodoroMinutes,
        'pomodoro_state': 'focusing',
        'pomodoro_started_at': DateTime.now().toIso8601String(),
        'active_participants_count': 1,
        'created_by': ?userId,
      },
    );
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to create study room');
    }
    return StudyRoomModel.fromJson(rawList.first as Map<String, dynamic>);
  }

  @override
  Stream<StudyRoomModel> watchStudyRoom(String roomId) {
    // Subscribe to real-time DB changes for this specific room
    return _realtime
        .watchTable('study_rooms', filter: 'id=eq.$roomId')
        .where((e) => e.type != RealtimeEventType.delete)
        .map((e) => StudyRoomModel.fromJson(e.record));
  }

  @override
  Future<List<ForumPostModel>> fetchForumPosts({String? track}) async {
    final params = <String, dynamic>{
      'select': '*,forum_replies(*)',
      'order': 'created_at.desc',
    };
    if (track != null && track.isNotEmpty && track != 'All') {
      params['track'] = 'eq.$track';
    }

    final res = await _client.fetchForumPosts(params);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    return rawList
        .map((e) => ForumPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ForumPostModel> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  }) async {
    final userId = _userStorage?.getUserId();
    final authorName = _userStorage?.getUserDisplayName() ?? 'Scholar';
    final authorAvatar = _userStorage?.getUserAvatarUrl();

    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'track': track,
      'latex_content': latexContent,
      'author_name': authorName,
      'author_id': ?userId,
      'author_avatar': ?authorAvatar,
    };

    final res = await _client.createForumPost(payload);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to create forum post');
    }
    return ForumPostModel.fromJson(rawList.first as Map<String, dynamic>);
  }

  @override
  Future<ForumReplyModel> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  }) async {
    final userId = _userStorage?.getUserId();
    final authorName = _userStorage?.getUserDisplayName() ?? 'Scholar';
    final authorAvatar = _userStorage?.getUserAvatarUrl();

    final payload = <String, dynamic>{
      'post_id': postId,
      'content': content,
      'latex_content': latexContent,
      'author_name': authorName,
      'author_id': ?userId,
      'author_avatar': ?authorAvatar,
    };

    final res = await _client.replyToForumPost(payload);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to add reply');
    }
    return ForumReplyModel.fromJson(rawList.first as Map<String, dynamic>);
  }

  @override
  Stream<List<ForumReplyModel>> watchForumReplies(String postId) {
    // Seed the cache with an initial REST fetch, then stream incremental inserts
    final streamController = StreamController<List<ForumReplyModel>>.broadcast();

    // Initial fetch to seed cache
    _client
        .fetchForumPosts({
          'select': 'forum_replies(*)',
          'id': 'eq.$postId',
          'limit': '1',
        })
        .then((res) {
          try {
            final rawList = res.data is List ? (res.data as List) : <dynamic>[];
            if (rawList.isNotEmpty) {
              final postJson = rawList.first as Map<String, dynamic>;
              final repliesRaw = postJson['forum_replies'] as List<dynamic>? ?? [];
              _replyCache[postId] = repliesRaw
                  .map((r) => ForumReplyModel.fromJson(r as Map<String, dynamic>))
                  .toList();
              if (!streamController.isClosed) {
                streamController.add(List.unmodifiable(_replyCache[postId]!));
              }
            }
          } on Exception catch (_) {}
        })
        .ignore();

    // Listen for new inserts via WebSocket
    final wsSub = _realtime
        .watchTable('forum_replies', filter: 'post_id=eq.$postId')
        .listen((event) {
          if (event.type == RealtimeEventType.insert) {
            try {
              final reply = ForumReplyModel.fromJson(event.record);
              _replyCache.putIfAbsent(postId, () => []).add(reply);
              if (!streamController.isClosed) {
                streamController.add(List.unmodifiable(_replyCache[postId]!));
              }
            } on Exception catch (_) {}
          }
        });

    streamController.onCancel = () => wsSub.cancel().ignore();

    return streamController.stream;
  }

  @override
  Future<List<SharedDeckModel>> fetchSharedDecks({String? subject}) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'downloads_count.desc',
    };
    if (subject != null && subject.isNotEmpty && subject != 'All') {
      params['subject'] = 'eq.$subject';
    }

    final res = await _client.fetchSharedDecks(params);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    return rawList
        .map((e) => SharedDeckModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SharedDeckModel> publishDeck({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
  }) async {
    final userId = _userStorage?.getUserId();
    final ownerName = _userStorage?.getUserDisplayName() ?? 'Scholar';

    final payload = <String, dynamic>{
      'title': title,
      'subject': subject,
      'description': description,
      'category': category,
      'total_cards': totalCards,
      'cards': cardsJson,
      'owner_name': ownerName,
      'owner_id': ?userId,
    };

    final res = await _client.publishDeck(payload);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to publish shared deck');
    }
    return SharedDeckModel.fromJson(rawList.first as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> cloneSharedDeck(String sharedDeckId) async {
    final res = await _client.cloneSharedDeck(
      {'p_shared_deck_id': sharedDeckId},
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return {};
  }

  @override
  Stream<List<LeaderboardEntryModel>> streamLeaderboards({String? track}) {
    // Accumulate leaderboard snapshot, then push updates for any change via WebSocket
    final streamController = StreamController<List<LeaderboardEntryModel>>.broadcast();
    final cache = <String, LeaderboardEntryModel>{};

    // Initial fetch to seed the cache
    fetchLeaderboards(track: track)
        .then((entries) {
          for (final e in entries) {
            cache[e.userId] = e;
          }
          if (!streamController.isClosed) {
            streamController.add(_sortedLeaderboard(cache));
          }
        })
        .ignore();

    // Stream any row changes in the leaderboards table
    final wsSub = _realtime.watchTable('leaderboards').listen((event) {
      try {
        if (event.type == RealtimeEventType.delete) {
          final id = event.oldRecord?['user_id'] as String?;
          if (id != null) cache.remove(id);
        } else {
          final entry = LeaderboardEntryModel.fromJson(event.record);
          // Only include if track filter matches
          if (track == null || track.isEmpty || track == 'All' ||
              (event.record['track'] as String? ?? '') == track) {
            cache[entry.userId] = entry;
          }
        }
        if (!streamController.isClosed) {
          streamController.add(_sortedLeaderboard(cache));
        }
      } on Exception catch (_) {}
    });

    streamController.onCancel = () => wsSub.cancel().ignore();
    return streamController.stream;
  }

  List<LeaderboardEntryModel> _sortedLeaderboard(Map<String, LeaderboardEntryModel> cache) {
    final list = cache.values.toList()
      ..sort((a, b) => (b.weeklyXp).compareTo(a.weeklyXp));
    return list;
  }

  @override
  Future<List<LeaderboardEntryModel>> fetchLeaderboards({String? track}) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'weekly_xp.desc',
      'limit': '50',
    };
    if (track != null && track.isNotEmpty && track != 'All') {
      params['track'] = 'eq.$track';
    }

    final res = await _client.fetchLeaderboards(params);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    return rawList
        .map((e) => LeaderboardEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StudyCommunityModel> autoProvisionCommunity({
    required String courseCode,
    required String title,
    String? department,
  }) async {
    final res = await _client.autoProvisionCommunity(
      {
        'p_course_code': courseCode,
        'p_title': title,
        'p_department': department ?? 'General',
      },
    );
    if (res.data is Map<String, dynamic>) {
      return StudyCommunityModel.fromJson(res.data as Map<String, dynamic>);
    }
    throw Exception('Failed to auto-provision community');
  }

  @override
  Future<StudyCommunityModel> fetchCourseCommunityStats(
    String courseCode,
  ) async {
    final normalized = courseCode.trim().toUpperCase();
    final res = await _client.fetchCourseCommunityStats(
      {
        'course_code': 'eq.$normalized',
        'select': '*',
        'limit': '1',
      },
    );
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isNotEmpty) {
      return StudyCommunityModel.fromJson(
        rawList.first as Map<String, dynamic>,
      );
    }
    return autoProvisionCommunity(
      courseCode: normalized,
      title: '$normalized Study Hub',
    );
  }
}
