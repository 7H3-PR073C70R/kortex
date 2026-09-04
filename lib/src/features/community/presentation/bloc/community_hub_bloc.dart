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
    on<CreateRoomEvent>(_onCreateRoom);
    on<CreateForumPostEvent>(_onCreateForumPost);
    on<ReplyToPostEvent>(_onReplyToPost);
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
    );
    final decksRes = await _repository.fetchSharedDecks();
    final leaderboardRes = await _repository.fetchLeaderboards(
      track: effectiveTrack,
    );

    roomsRes.fold(
      (failure) => emit(
        state.copyWith(
          status: CommunityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (rooms) {
        emit(
          state.copyWith(
            status: CommunityStatus.loaded,
            studyRooms: rooms,
            forumPosts: forumRes.fold((_) => [], (posts) => posts),
            sharedDecks: decksRes.fold((_) => [], (decks) => decks),
            leaderboardEntries: leaderboardRes.fold(
              (_) => [],
              (entries) => entries,
            ),
          ),
        );
      },
    );

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

  Future<void> _onCreateRoom(
    CreateRoomEvent event,
    Emitter<CommunityState> emit,
  ) async {
    final res = await _repository.createStudyRoom(
      title: event.title,
      subject: event.subject,
      category: event.category,
      pomodoroMinutes: event.pomodoroMinutes,
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
