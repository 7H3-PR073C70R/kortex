import 'dart:async';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/data/models/leaderboard_entry_model.dart';
import 'package:kortex/src/features/community/data/models/shared_deck_model.dart';
import 'package:kortex/src/features/community/data/models/study_community_model.dart';
import 'package:kortex/src/features/community/data/models/study_room_model.dart';

class CommunityRemoteDataSourceImpl implements CommunityRemoteDataSource {
  CommunityRemoteDataSourceImpl(this._client);

  final CommunityApiClient _client;

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
    final res = await _client.createStudyRoom(
      {
        'title': title,
        'subject': subject,
        'category': category,
        'pomodoro_duration_minutes': pomodoroMinutes,
        'pomodoro_state': 'focusing',
        'pomodoro_started_at': DateTime.now().toIso8601String(),
        'active_participants_count': 1,
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
    return Stream.periodic(const Duration(seconds: 1), (tick) {
      final elapsed = tick % 1500;
      final isFocus = elapsed < 1200;
      return StudyRoomModel(
        id: roomId,
        title: 'Deep Work & Socratic Pod',
        subject: 'General Study & Concept Mastery',
        category: 'General',
        pomodoroState: isFocus ? 'focusing' : 'break',
        pomodoroStartedAt: DateTime.now().subtract(Duration(seconds: elapsed)),
        activeParticipantsCount: 8 + (tick % 5),
      );
    });
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
    final res = await _client.createForumPost(
      {
        'title': title,
        'content': content,
        'track': track,
        'latex_content': latexContent,
        'author_name': 'You',
      },
    );
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
    final res = await _client.replyToForumPost(
      {
        'post_id': postId,
        'content': content,
        'latex_content': latexContent,
        'author_name': 'You',
      },
    );
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
    final res = await _client.publishDeck(
      {
        'title': title,
        'subject': subject,
        'description': description,
        'category': category,
        'total_cards': totalCards,
        'cards': cardsJson,
        'owner_name': 'You',
      },
    );
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
    return Stream.periodic(const Duration(seconds: 5), (_) {
      return [
        const LeaderboardEntryModel(
          id: 'lb_1',
          userId: 'user_1',
          userName: 'Adeola Vance',
          track: 'JAMB',
          dailyXp: 320,
          weeklyXp: 2450,
          streakDays: 14,
        ),
        const LeaderboardEntryModel(
          id: 'lb_2',
          userId: 'user_2',
          userName: 'Chukwudi Okafor',
          track: 'WAEC',
          dailyXp: 290,
          weeklyXp: 2180,
          streakDays: 11,
          rank: 2,
        ),
        const LeaderboardEntryModel(
          id: 'lb_3',
          userId: 'user_3',
          userName: 'Elena Rostova',
          track: 'SAT',
          dailyXp: 260,
          weeklyXp: 1950,
          streakDays: 9,
          rank: 3,
        ),
        const LeaderboardEntryModel(
          id: 'lb_4',
          userId: 'user_4',
          userName: 'Tariq Mansour',
          track: 'Engineering',
          dailyXp: 210,
          weeklyXp: 1680,
          streakDays: 7,
          rank: 4,
        ),
        const LeaderboardEntryModel(
          id: 'lb_5',
          userId: 'user_5',
          userName: 'Zainab Bello',
          track: 'Medicine',
          dailyXp: 190,
          weeklyXp: 1540,
          streakDays: 6,
          rank: 5,
        ),
      ];
    });
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
    if (rawList.isEmpty) {
      return [
        const LeaderboardEntryModel(
          id: 'lb_1',
          userId: 'user_1',
          userName: 'Adeola Vance',
          track: 'JAMB',
          dailyXp: 320,
          weeklyXp: 2450,
          streakDays: 14,
        ),
        const LeaderboardEntryModel(
          id: 'lb_2',
          userId: 'user_2',
          userName: 'Chukwudi Okafor',
          track: 'WAEC',
          dailyXp: 290,
          weeklyXp: 2180,
          streakDays: 11,
          rank: 2,
        ),
        const LeaderboardEntryModel(
          id: 'lb_3',
          userId: 'user_3',
          userName: 'Elena Rostova',
          track: 'SAT',
          dailyXp: 260,
          weeklyXp: 1950,
          streakDays: 9,
          rank: 3,
        ),
      ];
    }
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
    final res = await _client.fetchCourseCommunityStats(
      {
        'course_code': 'eq.$courseCode',
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
    return StudyCommunityModel(
      id: 'comm_${courseCode.toLowerCase().replaceAll(' ', '_')}',
      courseCode: courseCode,
      title: '$courseCode Study Hub',
      department: 'General',
      memberCount: 18,
      activeRoomsCount: 1,
      forumThreadsCount: 2,
      isUserMember: true,
      isFoundingMember: false,
    );
  }
}
