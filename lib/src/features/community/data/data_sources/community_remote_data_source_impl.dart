import 'dart:async';
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
  }) : _userStorage = userStorage;

  final CommunityApiClient _client;
  final UserStorageService? _userStorage;

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
  Stream<StudyRoomModel> watchStudyRoom(String roomId) async* {
    while (true) {
      try {
        final res = await _client.fetchStudyRooms({
          'id': 'eq.$roomId',
          'select': '*',
          'limit': '1',
        });
        final rawList = res.data is List ? (res.data as List) : <dynamic>[];
        if (rawList.isNotEmpty) {
          yield StudyRoomModel.fromJson(rawList.first as Map<String, dynamic>);
        }
      } on Object catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 4));
    }
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
  Stream<List<LeaderboardEntryModel>> streamLeaderboards({String? track}) async* {
    while (true) {
      try {
        final list = await fetchLeaderboards(track: track);
        yield list;
      } on Object catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 8));
    }
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
