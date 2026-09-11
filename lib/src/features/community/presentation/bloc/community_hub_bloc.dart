import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';

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
    on<VerifyForumReplyEvent>(_onVerifyForumReply);
    on<LoadStudyCirclesEvent>(_onLoadStudyCircles);
    on<CreateStudyCircleEvent>(_onCreateStudyCircle);
    on<JoinStudyCircleEvent>(_onJoinStudyCircle);
    on<CloneDeckEvent>(_onCloneDeck);
    on<PublishDeckEvent>(_onPublishDeck);
    on<LeaderboardUpdatedEvent>(_onLeaderboardUpdated);
  }

  final CommunityRepository _repository;
  StreamSubscription<dynamic>? _leaderboardSubscription;

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
    final forumPosts =
        forumRes.fold((_) => state.forumPosts, (posts) => posts);
    final studyCircles =
        circlesRes.fold((_) => state.studyCircles, (c) => c);
    final sharedDecks =
        decksRes.fold((_) => state.sharedDecks, (decks) => decks);
    final leaderboardEntries = leaderboardRes.fold(
      (_) => state.leaderboardEntries,
      (entries) => entries,
    );

    final hasAnyData = rooms.isNotEmpty ||
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
    final effectiveTrack =
        state.selectedTrack == 'All' ? null : state.selectedTrack;
    final res = await _repository.fetchForumPosts(
      track: effectiveTrack,
      questionsOnly: event.questionsOnly,
    );
    res.fold(
      (_) {},
      (posts) => emit(state.copyWith(forumPosts: posts)),
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
