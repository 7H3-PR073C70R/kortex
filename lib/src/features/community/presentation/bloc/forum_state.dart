import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';

enum ForumStatus { initial, loading, loaded, failure }

class ForumState extends Equatable {
  const ForumState({
    this.status = ForumStatus.initial,
    this.posts = const [],
    this.selectedTrack = 'All',
    this.selectedSortFilter = 'trending',
    this.questionsOnly = false,
    this.searchQuery = '',
    this.bookmarkedPostIds = const {},
    this.followedTopics = const {},
    this.errorMessage,
    this.hasMorePosts = true,
    this.isLoadingMore = false,
    this.compiledDeckId,
    this.isCompilingDeck = false,
  });

  final ForumStatus status;
  final List<ForumPostEntity> posts;
  final String selectedTrack;
  final String selectedSortFilter;
  final bool questionsOnly;
  final String searchQuery;
  final Set<String> bookmarkedPostIds;
  final Set<String> followedTopics;
  final String? errorMessage;
  final bool hasMorePosts;
  final bool isLoadingMore;
  final String? compiledDeckId;
  final bool isCompilingDeck;

  ForumState copyWith({
    ForumStatus? status,
    List<ForumPostEntity>? posts,
    String? selectedTrack,
    String? selectedSortFilter,
    bool? questionsOnly,
    String? searchQuery,
    Set<String>? bookmarkedPostIds,
    Set<String>? followedTopics,
    String? errorMessage,
    bool? hasMorePosts,
    bool? isLoadingMore,
    String? compiledDeckId,
    bool? isCompilingDeck,
  }) {
    return ForumState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      selectedTrack: selectedTrack ?? this.selectedTrack,
      selectedSortFilter: selectedSortFilter ?? this.selectedSortFilter,
      questionsOnly: questionsOnly ?? this.questionsOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      bookmarkedPostIds: bookmarkedPostIds ?? this.bookmarkedPostIds,
      followedTopics: followedTopics ?? this.followedTopics,
      errorMessage: errorMessage,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      compiledDeckId: compiledDeckId ?? this.compiledDeckId,
      isCompilingDeck: isCompilingDeck ?? this.isCompilingDeck,
    );
  }

  @override
  List<Object?> get props => [
        status,
        posts,
        selectedTrack,
        selectedSortFilter,
        questionsOnly,
        searchQuery,
        bookmarkedPostIds,
        followedTopics,
        errorMessage,
        hasMorePosts,
        isLoadingMore,
        compiledDeckId,
        isCompilingDeck,
      ];
}
