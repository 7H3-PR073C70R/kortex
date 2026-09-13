import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';

enum CommunityStatus { initial, loading, loaded, failure }

class CommunityState extends Equatable {
  const CommunityState({
    this.status = CommunityStatus.initial,
    this.selectedTabIndex = 0,
    this.selectedTrack = 'All',
    this.questionsOnly = false,
    this.studyRooms = const [],
    this.forumPosts = const [],
    this.studyCircles = const [],
    this.sharedDecks = const [],
    this.leaderboardEntries = const [],
    this.errorMessage,
    this.lastClonedDeckId,
    this.verifiedSolutionNotice,
    this.hasMoreForumPosts = true,
    this.isLoadingMoreForumPosts = false,
    this.forumPostsOffset = 0,
    this.lastCreatedAt,
    this.lastId,
    this.selectedForumFilter = 'trending',
    this.forumSearchQuery = '',
    this.bookmarkedPostIds = const {},
  });

  final CommunityStatus status;

  /// 0: Focus Rooms, 1: Track Forum / Q&A, 2: Study Circles, 3: Deck Market, 4: Leaderboard
  final int selectedTabIndex;
  final String selectedTrack;
  final bool questionsOnly;
  final String selectedForumFilter;
  final String forumSearchQuery;
  final Set<String> bookmarkedPostIds;
  final List<StudyRoomEntity> studyRooms;
  final List<ForumPostEntity> forumPosts;
  final List<StudyCircleEntity> studyCircles;
  final List<SharedDeckEntity> sharedDecks;
  final List<LeaderboardEntryEntity> leaderboardEntries;
  final String? errorMessage;
  final String? lastClonedDeckId;
  final String? verifiedSolutionNotice;
  final bool hasMoreForumPosts;
  final bool isLoadingMoreForumPosts;
  final int forumPostsOffset;
  final DateTime? lastCreatedAt;
  final String? lastId;

  CommunityState copyWith({
    CommunityStatus? status,
    int? selectedTabIndex,
    String? selectedTrack,
    bool? questionsOnly,
    String? selectedForumFilter,
    String? forumSearchQuery,
    Set<String>? bookmarkedPostIds,
    List<StudyRoomEntity>? studyRooms,
    List<ForumPostEntity>? forumPosts,
    List<StudyCircleEntity>? studyCircles,
    List<SharedDeckEntity>? sharedDecks,
    List<LeaderboardEntryEntity>? leaderboardEntries,
    String? errorMessage,
    String? lastClonedDeckId,
    String? verifiedSolutionNotice,
    bool? hasMoreForumPosts,
    bool? isLoadingMoreForumPosts,
    int? forumPostsOffset,
    DateTime? lastCreatedAt,
    String? lastId,
  }) {
    return CommunityState(
      status: status ?? this.status,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      selectedTrack: selectedTrack ?? this.selectedTrack,
      questionsOnly: questionsOnly ?? this.questionsOnly,
      selectedForumFilter: selectedForumFilter ?? this.selectedForumFilter,
      forumSearchQuery: forumSearchQuery ?? this.forumSearchQuery,
      bookmarkedPostIds: bookmarkedPostIds ?? this.bookmarkedPostIds,
      studyRooms: studyRooms ?? this.studyRooms,
      forumPosts: forumPosts ?? this.forumPosts,
      studyCircles: studyCircles ?? this.studyCircles,
      sharedDecks: sharedDecks ?? this.sharedDecks,
      leaderboardEntries: leaderboardEntries ?? this.leaderboardEntries,
      errorMessage: errorMessage,
      lastClonedDeckId: lastClonedDeckId ?? this.lastClonedDeckId,
      verifiedSolutionNotice:
          verifiedSolutionNotice ?? this.verifiedSolutionNotice,
      hasMoreForumPosts: hasMoreForumPosts ?? this.hasMoreForumPosts,
      isLoadingMoreForumPosts:
          isLoadingMoreForumPosts ?? this.isLoadingMoreForumPosts,
      forumPostsOffset: forumPostsOffset ?? this.forumPostsOffset,
      lastCreatedAt: lastCreatedAt ?? this.lastCreatedAt,
      lastId: lastId ?? this.lastId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedTabIndex,
    selectedTrack,
    questionsOnly,
    selectedForumFilter,
    forumSearchQuery,
    bookmarkedPostIds,
    studyRooms,
    forumPosts,
    studyCircles,
    sharedDecks,
    leaderboardEntries,
    errorMessage,
    lastClonedDeckId,
    verifiedSolutionNotice,
    hasMoreForumPosts,
    isLoadingMoreForumPosts,
    forumPostsOffset,
    lastCreatedAt,
    lastId,
  ];
}
