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
  });

  final CommunityStatus status;

  /// 0: Focus Rooms, 1: Track Forum / Q&A, 2: Study Circles, 3: Deck Market, 4: Leaderboard
  final int selectedTabIndex;
  final String selectedTrack;
  final bool questionsOnly;
  final List<StudyRoomEntity> studyRooms;
  final List<ForumPostEntity> forumPosts;
  final List<StudyCircleEntity> studyCircles;
  final List<SharedDeckEntity> sharedDecks;
  final List<LeaderboardEntryEntity> leaderboardEntries;
  final String? errorMessage;
  final String? lastClonedDeckId;
  final String? verifiedSolutionNotice;

  CommunityState copyWith({
    CommunityStatus? status,
    int? selectedTabIndex,
    String? selectedTrack,
    bool? questionsOnly,
    List<StudyRoomEntity>? studyRooms,
    List<ForumPostEntity>? forumPosts,
    List<StudyCircleEntity>? studyCircles,
    List<SharedDeckEntity>? sharedDecks,
    List<LeaderboardEntryEntity>? leaderboardEntries,
    String? errorMessage,
    String? lastClonedDeckId,
    String? verifiedSolutionNotice,
  }) {
    return CommunityState(
      status: status ?? this.status,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      selectedTrack: selectedTrack ?? this.selectedTrack,
      questionsOnly: questionsOnly ?? this.questionsOnly,
      studyRooms: studyRooms ?? this.studyRooms,
      forumPosts: forumPosts ?? this.forumPosts,
      studyCircles: studyCircles ?? this.studyCircles,
      sharedDecks: sharedDecks ?? this.sharedDecks,
      leaderboardEntries: leaderboardEntries ?? this.leaderboardEntries,
      errorMessage: errorMessage,
      lastClonedDeckId: lastClonedDeckId ?? this.lastClonedDeckId,
      verifiedSolutionNotice:
          verifiedSolutionNotice ?? this.verifiedSolutionNotice,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedTabIndex,
    selectedTrack,
    questionsOnly,
    studyRooms,
    forumPosts,
    studyCircles,
    sharedDecks,
    leaderboardEntries,
    errorMessage,
    lastClonedDeckId,
    verifiedSolutionNotice,
  ];
}
