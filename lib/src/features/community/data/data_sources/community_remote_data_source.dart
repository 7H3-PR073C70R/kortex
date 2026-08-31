import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/data/models/leaderboard_entry_model.dart';
import 'package:kortex/src/features/community/data/models/shared_deck_model.dart';
import 'package:kortex/src/features/community/data/models/study_room_model.dart';

abstract class CommunityRemoteDataSource {
  Future<List<StudyRoomModel>> fetchStudyRooms({String? category});

  Future<StudyRoomModel> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
  });

  Stream<StudyRoomModel> watchStudyRoom(String roomId);

  Future<List<ForumPostModel>> fetchForumPosts({String? track});

  Future<ForumPostModel> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  });

  Future<ForumReplyModel> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  });

  Future<List<SharedDeckModel>> fetchSharedDecks({String? subject});

  Future<SharedDeckModel> publishDeck({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
  });

  Future<Map<String, dynamic>> cloneSharedDeck(String sharedDeckId);

  Stream<List<LeaderboardEntryModel>> streamLeaderboards({String? track});

  Future<List<LeaderboardEntryModel>> fetchLeaderboards({String? track});
}
