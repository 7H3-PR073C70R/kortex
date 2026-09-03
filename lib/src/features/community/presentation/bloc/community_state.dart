import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';

enum CommunityStatus { initial, loading, loaded, failure }

class CommunityState extends Equatable {
  const CommunityState({
    this.status = CommunityStatus.initial,
    this.selectedTabIndex = 0,
    this.selectedTrack = 'All',
    this.studyRooms = const [],
    this.forumPosts = const [],
    this.sharedDecks = const [],
    this.leaderboardEntries = const [],
    this.errorMessage,
    this.lastClonedDeckId,
  });

  final CommunityStatus status;

  /// 0: Live Rooms, 1: Track Forum, 2: Deck Market, 3: Leaderboard
  final int selectedTabIndex;
  final String selectedTrack;
  final List<StudyRoomEntity> studyRooms;
  final List<ForumPostEntity> forumPosts;
  final List<SharedDeckEntity> sharedDecks;
  final List<LeaderboardEntryEntity> leaderboardEntries;
  final String? errorMessage;
  final String? lastClonedDeckId;

  CommunityState copyWith({
    CommunityStatus? status,
    int? selectedTabIndex,
    String? selectedTrack,
    List<StudyRoomEntity>? studyRooms,
    List<ForumPostEntity>? forumPosts,
    List<SharedDeckEntity>? sharedDecks,
    List<LeaderboardEntryEntity>? leaderboardEntries,
    String? errorMessage,
    String? lastClonedDeckId,
  }) {
    return CommunityState(
      status: status ?? this.status,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      selectedTrack: selectedTrack ?? this.selectedTrack,
      studyRooms: studyRooms ?? this.studyRooms,
      forumPosts: forumPosts ?? this.forumPosts,
      sharedDecks: sharedDecks ?? this.sharedDecks,
      leaderboardEntries: leaderboardEntries ?? this.leaderboardEntries,
      errorMessage: errorMessage,
      lastClonedDeckId: lastClonedDeckId ?? this.lastClonedDeckId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedTabIndex,
    selectedTrack,
    studyRooms,
    forumPosts,
    sharedDecks,
    leaderboardEntries,
    errorMessage,
    lastClonedDeckId,
  ];
}
