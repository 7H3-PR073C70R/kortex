import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';

class CommunityHubBloc extends Bloc<CommunityEvent, CommunityState> {
  CommunityHubBloc({
    required CommunityRepository repository,
  }) : _repository = repository,
       super(const CommunityState()) {
    on<LoadCommunityHubEvent>(_onLoadCommunityHub);
    on<SwitchCommunityTabEvent>(_onSwitchCommunityTab);
    on<ChangeTrackFilterEvent>(_onChangeTrackFilter);
    on<ToggleQuestionsOnlyFilterEvent>(_onToggleQuestionsOnlyFilter);
    on<CreateRoomEvent>(_onCreateRoom);
    on<CreateForumPostEvent>(_onCreateForumPost);
    on<ReplyToPostEvent>(_onReplyToPost);
    on<VoteForumPostEvent>(_onVoteForumPost);
    on<VoteForumReplyEvent>(_onVoteForumReply);
    on<ForumPostRepliesIncrementedEvent>(_onForumPostRepliesIncremented);
    on<VerifyForumReplyEvent>(_onVerifyForumReply);
    on<LoadStudyCirclesEvent>(_onLoadStudyCircles);
    on<CreateStudyCircleEvent>(_onCreateStudyCircle);
    on<JoinStudyCircleEvent>(_onJoinStudyCircle);
    on<CloneDeckEvent>(_onCloneDeck);
    on<PublishDeckEvent>(_onPublishDeck);
    on<LeaderboardUpdatedEvent>(_onLeaderboardUpdated);
    on<FetchMoreForumPostsEvent>(_onFetchMoreForumPosts);
    on<ClearCommunityErrorEvent>(_onClearCommunityError);
  }

  final CommunityRepository _repository;
  StreamSubscription<dynamic>? _leaderboardSubscription;

  void _onClearCommunityError(
    ClearCommunityErrorEvent event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith());
  }

  Future<void> _onLoadCommunityHub(
    LoadCommunityHubEvent event,
    Emitter<CommunityState> emit,
  ) async {
    emit(state.copyWith(status: CommunityStatus.loading));

    final effectiveTrack =
        event.track ??
        (state.selectedTrack == 'All' ? null : state.selectedTrack);
    final effectiveCategory = event.category ?? effectiveTrack;

    final roomsRes = await _repository.fetchStudyRooms(
      category: effectiveCategory,
    );
    final forumRes = await _repository.fetchForumPosts(
      track: effectiveTrack,
      questionsOnly: state.questionsOnly,
    );
    final circlesRes = await _repository.fetchStudyCircles(
      track: effectiveTrack,
    );
    final decksRes = await _repository.fetchSharedDecks();
    final leaderboardRes = await _repository.fetchLeaderboards(
      track: effectiveTrack,
    );

    final rooms = roomsRes.fold((_) => state.studyRooms, (r) => r);
    final forumPosts = forumRes.fold((_) => state.forumPosts, (posts) => posts);
    final studyCircles = circlesRes.fold((_) => state.studyCircles, (c) => c);
    final sharedDecks = decksRes.fold(
      (_) => state.sharedDecks,
      (decks) => decks,
    );
    final leaderboardEntries = leaderboardRes.fold(
      (_) => state.leaderboardEntries,
      (entries) => entries,
    );

    final hasAnyData =
        rooms.isNotEmpty ||
        forumPosts.isNotEmpty ||
        studyCircles.isNotEmpty ||
        sharedDecks.isNotEmpty ||
        leaderboardEntries.isNotEmpty;

    if (roomsRes.isLeft && !hasAnyData) {
      emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: roomsRes.fold((f) => f.message, (_) => null),
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: CommunityStatus.loaded,
          studyRooms: rooms,
          forumPosts: forumPosts,
          studyCircles: studyCircles,
          sharedDecks: sharedDecks,
          leaderboardEntries: leaderboardEntries,
          hasMoreForumPosts: forumPosts.length >= 15,
          forumPostsOffset: forumPosts.length,
          isLoadingMoreForumPosts: false,
        ),
      );
    }

    // Subscribe to live leaderboard stream
    await _leaderboardSubscription?.cancel();
    _leaderboardSubscription = _repository
        .streamLeaderboards(
          track: state.selectedTrack == 'All' ? null : state.selectedTrack,
        )
        .listen((entries) {
          if (!isClosed) {
            add(LeaderboardUpdatedEvent(entries));
          }
        });
  }

  void _onLeaderboardUpdated(
    LeaderboardUpdatedEvent event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(leaderboardEntries: event.entries));
  }

  void _onSwitchCommunityTab(
    SwitchCommunityTabEvent event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(selectedTabIndex: event.tabIndex));
  }

  Future<void> _onChangeTrackFilter(
    ChangeTrackFilterEvent event,
    Emitter<CommunityState> emit,
  ) async {
    emit(state.copyWith(selectedTrack: event.track));
    add(LoadCommunityHubEvent(track: event.track));
  }

  Future<void> _onToggleQuestionsOnlyFilter(
    ToggleQuestionsOnlyFilterEvent event,
    Emitter<CommunityState> emit,
  ) async {
    emit(state.copyWith(questionsOnly: event.questionsOnly));
    final effectiveTrack = state.selectedTrack == 'All'
        ? null
        : state.selectedTrack;
    final res = await _repository.fetchForumPosts(
      track: effectiveTrack,
      questionsOnly: event.questionsOnly,
    );
    res.fold(
      (_) {},
      (posts) => emit(
        state.copyWith(
          forumPosts: posts,
          hasMoreForumPosts: posts.length >= 15,
          forumPostsOffset: posts.length,
          isLoadingMoreForumPosts: false,
        ),
      ),
    );
  }

  Future<void> _onFetchMoreForumPosts(
    FetchMoreForumPostsEvent event,
    Emitter<CommunityState> emit,
  ) async {
    if (state.isLoadingMoreForumPosts || !state.hasMoreForumPosts) return;

    emit(state.copyWith(isLoadingMoreForumPosts: true));

    final effectiveTrack = state.selectedTrack == 'All'
        ? null
        : state.selectedTrack;

    final currentOffset = state.forumPosts.length;
    final res = await _repository.fetchForumPosts(
      track: effectiveTrack,
      questionsOnly: state.questionsOnly,
      offset: currentOffset,
    );

    res.fold(
      (failure) {
        emit(state.copyWith(isLoadingMoreForumPosts: false));
      },
      (newPosts) {
        final existingIds = state.forumPosts.map((p) => p.id).toSet();
        final uniqueNewPosts =
            newPosts.where((p) => !existingIds.contains(p.id)).toList();
        final updatedPosts = [...state.forumPosts, ...uniqueNewPosts];
        emit(
          state.copyWith(
            isLoadingMoreForumPosts: false,
            forumPosts: updatedPosts,
            forumPostsOffset: updatedPosts.length,
            hasMoreForumPosts: newPosts.length >= 15,
          ),
        );
      },
    );
  }

  Future<void> _onCreateRoom(
    CreateRoomEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.createStudyRoom(
      title: event.title,
      subject: event.subject,
      category: event.category,
      pomodoroMinutes: event.pomodoroMinutes,
      ambientSoundTrack: event.ambientSoundTrack,
      activeGoal: event.activeGoal,
      isSilentFocus: event.isSilentFocus,
    );
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (room) {
        emit(state.copyWith(studyRooms: [room, ...state.studyRooms]));
      },
    );
  }

  Future<void> _onCreateForumPost(
    CreateForumPostEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.createForumPost(
      title: event.title,
      content: event.content,
      track: event.track,
      latexContent: event.latexContent,
      isQuestion: event.isQuestion,
      syllabusTag: event.syllabusTag,
      isAnonymous: event.isAnonymous,
    );
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (post) {
        emit(state.copyWith(forumPosts: [post, ...state.forumPosts]));
      },
    );
  }

  Future<void> _onReplyToPost(
    ReplyToPostEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.replyToForumPost(
      postId: event.postId,
      content: event.content,
      latexContent: event.latexContent,
      parentReplyId: event.parentReplyId,
    );
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (reply) {
        final updatedPosts = state.forumPosts.map((p) {
          if (p.id == event.postId) {
            return p.copyWith(
              repliesCount: p.repliesCount + 1,
              replies: [...p.replies, reply],
            );
          }
          return p;
        }).toList();
        emit(state.copyWith(forumPosts: updatedPosts));
      },
    );
  }

  Future<void> _onVoteForumPost(
    VoteForumPostEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final updatedPosts = state.forumPosts.map((p) {
      if (p.id == event.postId) {
        final prevVote = p.userVote;
        final newVote = (prevVote == event.direction) ? 0 : event.direction;
        var newUpvotes = p.upvotes;
        var newDownvotes = p.downvotes;

        if (prevVote == 1) newUpvotes -= 1;
        if (prevVote == -1) newDownvotes -= 1;
        if (newVote == 1) newUpvotes += 1;
        if (newVote == -1) newDownvotes += 1;

        if (newUpvotes < 0) newUpvotes = 0;
        if (newDownvotes < 0) newDownvotes = 0;

        return p.copyWith(
          upvotes: newUpvotes,
          downvotes: newDownvotes,
          userVote: newVote,
        );
      }
      return p;
    }).toList();

    emit(state.copyWith(forumPosts: updatedPosts));
    await _repository.voteForumPost(
      postId: event.postId,
      voteDirection: event.direction,
    );
  }

  Future<void> _onVoteForumReply(
    VoteForumReplyEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final updatedPosts = state.forumPosts.map((p) {
      if (p.id == event.postId) {
        final updatedReplies = p.replies.map((r) {
          if (r.id == event.replyId) {
            final prevVote = r.userVote;
            final newVote = (prevVote == event.direction) ? 0 : event.direction;
            var newUpvotes = r.upvotes;
            var newDownvotes = r.downvotes;

            if (prevVote == 1) newUpvotes -= 1;
            if (prevVote == -1) newDownvotes -= 1;
            if (newVote == 1) newUpvotes += 1;
            if (newVote == -1) newDownvotes += 1;

            if (newUpvotes < 0) newUpvotes = 0;
            if (newDownvotes < 0) newDownvotes = 0;

            return r.copyWith(
              upvotes: newUpvotes,
              downvotes: newDownvotes,
              userVote: newVote,
            );
          }
          return r;
        }).toList();

        return p.copyWith(replies: updatedReplies);
      }
      return p;
    }).toList();

    emit(state.copyWith(forumPosts: updatedPosts));
    await _repository.voteForumReply(
      postId: event.postId,
      replyId: event.replyId,
      voteDirection: event.direction,
    );
  }

  void _onForumPostRepliesIncremented(
    ForumPostRepliesIncrementedEvent event,
    Emitter<CommunityState> emit,
  ) {
    final updatedPosts = state.forumPosts.map((p) {
      if (p.id == event.postId) {
        final exists = p.replies.any((r) => r.id == event.reply.id);
        final updatedReplies = exists ? p.replies : [...p.replies, event.reply];
        final effectiveCount = updatedReplies.length > p.repliesCount
            ? updatedReplies.length
            : (exists ? p.repliesCount : p.repliesCount + 1);
        return p.copyWith(
          repliesCount: effectiveCount,
          replies: updatedReplies,
        );
      }
      return p;
    }).toList();
    emit(state.copyWith(forumPosts: updatedPosts));
  }

  Future<void> _onVerifyForumReply(
    VerifyForumReplyEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.verifyForumReply(
      postId: event.postId,
      replyId: event.replyId,
    );
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (success) {
        if (success) {
          final updatedPosts = state.forumPosts.map((p) {
            if (p.id == event.postId) {
              final updatedReplies = p.replies.map((r) {
                return r.copyWith(isVerifiedSolution: r.id == event.replyId);
              }).toList();
              return p.copyWith(
                isVerifiedSolution: true,
                replies: updatedReplies,
              );
            }
            return p;
          }).toList();
          emit(
            state.copyWith(
              forumPosts: updatedPosts,
              verifiedSolutionNotice:
                  'Solution marked as verified! +100 Scholar XP awarded.',
            ),
          );
        }
      },
    );
  }

  Future<void> _onLoadStudyCircles(
    LoadStudyCirclesEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final effectiveTrack =
        event.track ??
        (state.selectedTrack == 'All' ? null : state.selectedTrack);
    final res = await _repository.fetchStudyCircles(track: effectiveTrack);
    res.fold(
      (_) {},
      (circles) => emit(state.copyWith(studyCircles: circles)),
    );
  }

  Future<void> _onCreateStudyCircle(
    CreateStudyCircleEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.createStudyCircle(
      name: event.name,
      track: event.track,
      targetWeeklyMinutes: event.targetWeeklyMinutes,
    );
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (circle) {
        emit(state.copyWith(studyCircles: [circle, ...state.studyCircles]));
      },
    );
  }

  Future<void> _onJoinStudyCircle(
    JoinStudyCircleEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.joinStudyCircle(event.circleId);
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (updatedCircle) {
        final updatedList = state.studyCircles.map((c) {
          return c.id == event.circleId ? updatedCircle : c;
        }).toList();
        emit(state.copyWith(studyCircles: updatedList));
      },
    );
  }

  Future<void> _onCloneDeck(
    CloneDeckEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.cloneSharedDeck(event.sharedDeckId);
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (clonedDeck) {
        if (locator.isRegistered<DecksBloc>()) {
          locator<DecksBloc>().add(const DecksRefreshed());
        }
        if (locator.isRegistered<DashboardBloc>()) {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        }
        emit(state.copyWith(lastClonedDeckId: clonedDeck.id));
      },
    );
  }

  Future<void> _onPublishDeck(
    PublishDeckEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.publishDeckToMarketplace(
      title: event.title,
      subject: event.subject,
      description: event.description,
      category: event.category,
      totalCards: event.totalCards,
      cardsJson: event.cardsJson,
      syllabusTag: event.syllabusTag,
    );
    res.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (sharedDeck) {
        emit(
          state.copyWith(
            sharedDecks: [sharedDeck, ...state.sharedDecks],
          ),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _leaderboardSubscription?.cancel();
    await super.close();
  }
}
