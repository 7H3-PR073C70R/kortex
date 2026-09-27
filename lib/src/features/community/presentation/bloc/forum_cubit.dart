import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/forum_state.dart';

class ForumCubit extends Cubit<ForumState> {
  ForumCubit({
    required CommunityRepository repository,
  })  : _repository = repository,
        super(const ForumState());

  final CommunityRepository _repository;

  Future<void> loadPosts({String? track}) async {
    final effectiveTrack = (track ?? state.selectedTrack) == 'All' ? null : (track ?? state.selectedTrack);
    emit(state.copyWith(status: ForumStatus.loading, selectedTrack: track ?? state.selectedTrack));

    final postsRes = await _repository.fetchForumPosts(
      track: effectiveTrack,
      questionsOnly: state.questionsOnly,
      sortFilter: state.selectedSortFilter,
      searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
    );
    final bookmarkedRes = await _repository.getBookmarkedForumPostIds();
    final followedRes = await _repository.getFollowedTopics();

    final posts = postsRes.fold((_) => state.posts, (p) => p);
    final bookmarkedIds = bookmarkedRes.fold((_) => state.bookmarkedPostIds, (ids) => ids);
    final followedTopics = followedRes.fold((_) => state.followedTopics, (topics) => topics);

    emit(
      state.copyWith(
        status: ForumStatus.loaded,
        posts: posts,
        bookmarkedPostIds: bookmarkedIds,
        followedTopics: followedTopics,
        hasMorePosts: posts.length >= 15,
      ),
    );
  }

  Future<void> changeTrackFilter(String track) async {
    emit(state.copyWith(selectedTrack: track));
    await loadPosts(track: track);
  }

  Future<void> changeSortFilter(String sortFilter) async {
    emit(state.copyWith(selectedSortFilter: sortFilter));
    await loadPosts();
  }

  Future<void> toggleQuestionsOnly({required bool questionsOnly}) async {
    emit(state.copyWith(questionsOnly: questionsOnly));
    await loadPosts();
  }

  Future<void> searchPosts(String query) async {
    emit(state.copyWith(searchQuery: query));
    await loadPosts();
  }

  Future<void> toggleBookmark(String postId) async {
    final updated = Set<String>.from(state.bookmarkedPostIds);
    if (updated.contains(postId)) {
      updated.remove(postId);
    } else {
      updated.add(postId);
    }
    emit(state.copyWith(bookmarkedPostIds: updated));
    await _repository.toggleBookmarkForumPost(postId);
  }

  Future<void> toggleFollowTopic(String topic) async {
    final res = await _repository.toggleFollowTopic(topic);
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (followedTopics) => emit(state.copyWith(followedTopics: followedTopics)),
    );
  }

  Future<void> votePost({required String postId, required int value}) async {
    final updatedPosts = state.posts.map((post) {
      if (post.id == postId) {
        final currentVote = post.userVote;
        final newVote = currentVote == value ? 0 : value;
        final voteDelta = newVote - currentVote;
        return post.copyWith(
          userVote: newVote,
          upvotes: post.upvotes + voteDelta,
        );
      }
      return post;
    }).toList();

    emit(state.copyWith(posts: updatedPosts));
    await _repository.voteForumPost(postId: postId, voteDirection: value);
  }

  Future<void> compileThreadToFlashcardsWithSyllabot(String postId) async {
    emit(state.copyWith(isCompilingDeck: true));
    try {
      final post = state.posts.firstWhere((p) => p.id == postId);
      final title = 'Deck: ${post.title}';
      final res = await _repository.publishDeckToMarketplace(
        title: title,
        subject: post.track,
        description: 'Auto-compiled from verified forum solution "${post.title}" via Syllabot AI.',
        category: 'Forum Synthesis',
        syllabusTag: post.track,
        totalCards: 5,
        cardsJson: [
          {
            'front': 'Key Concept from ${post.title}',
            'back': post.content,
          },
          {
            'front': 'Verified Solution Context',
            'back': 'Extracted high-yield insights from verified community resolution.',
          },
        ],
      );

      res.fold(
        (failure) => emit(state.copyWith(
          isCompilingDeck: false,
          errorMessage: 'Syllabot Compilation Failed: ${failure.message}',
        )),
        (sharedDeck) {
          emit(state.copyWith(
            isCompilingDeck: false,
            compiledDeckId: sharedDeck.id,
          ));
        },
      );
    } on Object catch (e) {
      emit(state.copyWith(
        isCompilingDeck: false,
        errorMessage: 'Failed to compile thread: $e',
      ));
    }
  }
}
