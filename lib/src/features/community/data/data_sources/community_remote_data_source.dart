import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/data/models/study_community_model.dart';
import 'package:kortex/src/features/deck_marketplace/data/models/shared_deck_model.dart';
import 'package:kortex/src/features/leaderboard/data/models/leaderboard_entry_model.dart';
import 'package:kortex/src/features/study_rooms/data/models/study_circle_model.dart';
import 'package:kortex/src/features/study_rooms/data/models/study_room_model.dart';

abstract class CommunityRemoteDataSource {
  Future<List<StudyRoomModel>> fetchStudyRooms({String? category});

  Future<StudyRoomModel> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
    String ambientSoundTrack = 'lofi',
    String? activeGoal,
    bool isSilentFocus = true,
  });

  /// Real-time stream of a study room via WebSocket.
  Stream<StudyRoomModel> watchStudyRoom(String roomId);

  Future<List<ForumPostModel>> fetchForumPosts({
    String? track,
    bool? questionsOnly,
    String? sortFilter,
    String? searchQuery,
    int limit = 15,
    int offset = 0,
    DateTime? cursorCreatedAt,
    String? cursorId,
  });

  /// High-performance Keyset (cursor-based) pagination fetching.
  Future<List<ForumPostModel>> fetchForumPostsKeyset({
    String? track,
    DateTime? cursorCreatedAt,
    String? cursorId,
    int limit = 15,
    String sortFilter = 'latest',
    String? searchQuery,
    bool questionsOnly = false,
  });

  /// Fetches complete hierarchical thread tree (post + pre-nested replies) in 1 roundtrip.
  Future<Map<String, dynamic>?> fetchForumThreadTree({
    required String postId,
    int limit = 20,
    int subReplyLimit = 5,
  });

  /// Persists a generated Socratic hint to the server.
  Future<bool> saveForumSocraticHint({
    required String postId,
    required String hint,
  });

  Future<List<ForumReplyModel>> fetchForumReplies({
    required String postId,
    String? parentReplyId,
    bool topLevelOnly = false,
    String? sortFilter,
    int limit = 15,
    int offset = 0,
  });

  Future<ForumPostModel> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
    bool isQuestion = false,
    String syllabusTag = 'General',
    List<String>? tags,
    List<String>? mediaUrls,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
    bool isAnonymous = false,
  });

  Future<bool> deleteForumPost(String postId);

  Future<ForumReplyModel> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
    String? parentReplyId,
    List<String>? mediaUrls,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
  });

  Future<bool> voteForumPost({
    required String postId,
    required int voteDirection,
  });

  Future<bool> voteForumReply({
    required String postId,
    required String replyId,
    required int voteDirection,
  });

  Future<bool> verifyForumReply({
    required String postId,
    required String replyId,
  });

  /// Real-time stream of replies for a forum post via WebSocket.
  Stream<List<ForumReplyModel>> watchForumReplies(String postId);

  Future<List<StudyCircleModel>> fetchStudyCircles({String? track});

  Future<StudyCircleModel> createStudyCircle({
    required String name,
    required String track,
    int targetWeeklyMinutes = 600,
  });

  Future<StudyCircleModel> joinStudyCircle(String circleId);

  Future<StudyCircleModel> leaveStudyCircle(String circleId);

  Future<Map<String, dynamic>> nudgeStudyCircle(String circleId);

  Future<Map<String, dynamic>> recordPodFocusMinutes({
    required String circleId,
    required int minutes,
  });

  Future<List<SharedDeckModel>> fetchSharedDecks({String? subject});

  Future<SharedDeckModel> publishDeck({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
    String syllabusTag = 'General',
  });

  Future<Map<String, dynamic>> cloneSharedDeck(String sharedDeckId);

  /// Real-time stream of leaderboard entries via WebSocket.
  Stream<List<LeaderboardEntryModel>> streamLeaderboards({String? track});

  Future<List<LeaderboardEntryModel>> fetchLeaderboards({String? track});

  Future<StudyCommunityModel> autoProvisionCommunity({
    required String courseCode,
    required String title,
    String? department,
  });

  Future<StudyCommunityModel> fetchCourseCommunityStats(String courseCode);

  Future<String> fetchLiveKitToken({
    required String roomId,
    required String userId,
  });

  Future<bool> reportContent({
    required String contentType,
    required String contentId,
    required String reason,
    String? details,
    String? postId,
  });

  /// Toggles push notification subscription for a forum post.
  Future<bool> toggleForumPostSubscription(String postId);

  /// Checks if current user is subscribed to notifications for a forum post.
  Future<bool> isForumPostSubscribed(String postId);

  /// Toggles bookmark / save state for a forum post.
  Future<bool> toggleBookmarkForumPost(String postId);

  /// Retrieves all bookmarked forum post IDs for the current user.
  Future<Set<String>> getBookmarkedForumPostIds();

  /// Toggles follow status for an academic topic / track.
  Future<Set<String>> toggleFollowTopic(String topic);

  /// Retrieves the set of followed topics for the current user.
  Future<Set<String>> getFollowedTopics();
}
