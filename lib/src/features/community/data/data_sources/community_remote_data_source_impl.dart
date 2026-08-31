import 'dart:async';
import 'package:kortex/src/features/community/data/client/supabase_community_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/data/models/leaderboard_entry_model.dart';
import 'package:kortex/src/features/community/data/models/shared_deck_model.dart';
import 'package:kortex/src/features/community/data/models/study_room_model.dart';
import 'package:kortex/src/services/user_storage_service.dart';

class CommunityRemoteDataSourceImpl implements CommunityRemoteDataSource {
  CommunityRemoteDataSourceImpl(this._client, this._userStorage);

  final SupabaseCommunityClient _client;
  final UserStorageService _userStorage;

  @override
  Future<List<StudyRoomModel>> fetchStudyRooms({String? category}) async {
    final token = _userStorage.getToken() ?? '';
    final list = await _client.fetchStudyRooms(
      authToken: token,
      category: category,
    );
    return list.map(StudyRoomModel.fromJson).toList();
  }

  @override
  Future<StudyRoomModel> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
  }) async {
    final token = _userStorage.getToken() ?? '';
    final map = await _client.createStudyRoom(
      title: title,
      subject: subject,
      category: category,
      pomodoroMinutes: pomodoroMinutes,
      authToken: token,
    );
    return StudyRoomModel.fromJson(map);
  }

  @override
  Stream<StudyRoomModel> watchStudyRoom(String roomId) {
    // Realtime polling / broadcast simulation with synchronized Pomodoro ticks
    return Stream.periodic(const Duration(seconds: 1), (tick) {
      final elapsed = tick % 1500;
      final isFocus = elapsed < 1200;
      return StudyRoomModel(
        id: roomId,
        title: 'STEM Deep Work & Socratic Pod',
        subject: 'Calculus & Quantum Mechanics',
        category: 'STEM',
        pomodoroState: isFocus ? 'focusing' : 'break',
        pomodoroStartedAt: DateTime.now().subtract(Duration(seconds: elapsed)),
        activeParticipantsCount: 8 + (tick % 5),
      );
    });
  }

  @override
  Future<List<ForumPostModel>> fetchForumPosts({String? track}) async {
    final token = _userStorage.getToken() ?? '';
    final list = await _client.fetchForumPosts(
      authToken: token,
      track: track,
    );
    return list.map(ForumPostModel.fromJson).toList();
  }

  @override
  Future<ForumPostModel> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  }) async {
    final token = _userStorage.getToken() ?? '';
    final map = await _client.createForumPost(
      title: title,
      content: content,
      track: track,
      authorName: 'You',
      authToken: token,
      latexContent: latexContent,
    );
    return ForumPostModel.fromJson(map);
  }

  @override
  Future<ForumReplyModel> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  }) async {
    final token = _userStorage.getToken() ?? '';
    final map = await _client.replyToForumPost(
      postId: postId,
      content: content,
      authorName: 'You',
      authToken: token,
      latexContent: latexContent,
    );
    return ForumReplyModel.fromJson(map);
  }

  @override
  Future<List<SharedDeckModel>> fetchSharedDecks({String? subject}) async {
    final token = _userStorage.getToken() ?? '';
    final list = await _client.fetchSharedDecks(
      authToken: token,
      subject: subject,
    );
    return list.map(SharedDeckModel.fromJson).toList();
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
    final token = _userStorage.getToken() ?? '';
    final map = await _client.publishDeck(
      title: title,
      subject: subject,
      description: description,
      category: category,
      totalCards: totalCards,
      cardsJson: cardsJson,
      ownerName: 'You',
      authToken: token,
    );
    return SharedDeckModel.fromJson(map);
  }

  @override
  Future<Map<String, dynamic>> cloneSharedDeck(String sharedDeckId) async {
    final token = _userStorage.getToken() ?? '';
    return _client.cloneSharedDeck(
      sharedDeckId: sharedDeckId,
      authToken: token,
    );
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
    final token = _userStorage.getToken() ?? '';
    final list = await _client.fetchLeaderboards(
      authToken: token,
      track: track,
    );
    if (list.isEmpty) {
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
    return list.map(LeaderboardEntryModel.fromJson).toList();
  }
}
