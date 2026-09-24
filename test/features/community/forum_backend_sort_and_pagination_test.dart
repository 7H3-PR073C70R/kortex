import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

void main() {
  late MockCommunityRepository repository;
  late CommunityHubBloc bloc;

  final samplePost = ForumPostEntity(
    id: 'post-1',
    authorId: 'user-1',
    authorName: 'ScholarOne',
    track: 'WAEC',
    title: 'Cell division question',
    content: 'What is mitosis?',
    repliesCount: 4,
    upvotes: 12,
    createdAt: DateTime.now(),
  );

  setUp(() {
    repository = MockCommunityRepository();
    when(() => repository.streamLeaderboards(track: any(named: 'track')))
        .thenAnswer((_) => const Stream<List<LeaderboardEntryEntity>>.empty());
    when(() => repository.fetchStudyRooms(category: any(named: 'category')))
        .thenAnswer((_) async => const Right<Failure, List<StudyRoomEntity>>([]));
    when(() => repository.fetchStudyCircles(track: any(named: 'track')))
        .thenAnswer((_) async => const Right<Failure, List<StudyCircleEntity>>([]));
    when(() => repository.fetchSharedDecks(subject: any(named: 'subject')))
        .thenAnswer((_) async => const Right<Failure, List<SharedDeckEntity>>([]));
    when(() => repository.fetchLeaderboards(track: any(named: 'track')))
        .thenAnswer((_) async => const Right<Failure, List<LeaderboardEntryEntity>>([]));
    when(
      () => repository.fetchForumPosts(
        track: any(named: 'track'),
        questionsOnly: any(named: 'questionsOnly'),
        sortFilter: any(named: 'sortFilter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => Right([samplePost]));

    bloc = CommunityHubBloc(repository: repository);
  });

  tearDown(() async {
    await bloc.close();
  });

  test('ChangeForumSortFilterEvent triggers backend query with proper sortFilter', () async {
    bloc.add(const ChangeForumSortFilterEvent('topToday'));
    await pumpEventQueue();

    expect(bloc.state.selectedForumFilter, 'topToday');
    expect(bloc.state.forumPosts, [samplePost]);

    verify(
      () => repository.fetchForumPosts(
        track: any(named: 'track'),
        questionsOnly: any(named: 'questionsOnly'),
        sortFilter: 'topToday',
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(1);
  });

  test('FetchMoreForumPostsEvent passes currentOffset and selectedForumFilter', () async {
    bloc.emit(bloc.state.copyWith(forumPosts: [samplePost], selectedForumFilter: 'latest'));

    final samplePost2 = ForumPostEntity(
      id: 'post-2',
      authorId: 'user-2',
      authorName: 'ScholarTwo',
      track: 'WAEC',
      title: 'Photosynthesis equation',
      content: 'Can someone verify my reaction steps?',
      repliesCount: 2,
      upvotes: 5,
      createdAt: DateTime.now(),
    );

    when(
      () => repository.fetchForumPosts(
        track: any(named: 'track'),
        questionsOnly: any(named: 'questionsOnly'),
        sortFilter: 'latest',
        offset: 1,
      ),
    ).thenAnswer((_) async => Right([samplePost2]));

    bloc.add(const FetchMoreForumPostsEvent());
    await pumpEventQueue();

    expect(bloc.state.forumPosts.length, 2);
    expect(bloc.state.forumPosts.last.id, 'post-2');
  });

  test('SearchForumPostsEvent triggers backend search and updates state', () async {
    when(
      () => repository.fetchForumPosts(
        track: any(named: 'track'),
        questionsOnly: any(named: 'questionsOnly'),
        sortFilter: any(named: 'sortFilter'),
        searchQuery: 'mitosis',
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => Right([samplePost]));

    bloc.add(const SearchForumPostsEvent('mitosis'));
    await pumpEventQueue();

    expect(bloc.state.forumSearchQuery, 'mitosis');
    expect(bloc.state.forumPosts, [samplePost]);

    verify(
      () => repository.fetchForumPosts(
        track: any(named: 'track'),
        questionsOnly: any(named: 'questionsOnly'),
        sortFilter: any(named: 'sortFilter'),
        searchQuery: 'mitosis',
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(1);
  });

  test('DeleteForumPostEvent removes post from local state', () async {
    bloc.emit(bloc.state.copyWith(forumPosts: [samplePost]));

    when(() => repository.deleteForumPost('post-1'))
        .thenAnswer((_) async => const Right(true));

    bloc.add(const DeleteForumPostEvent('post-1'));
    await pumpEventQueue();

    expect(bloc.state.forumPosts, isEmpty);
    verify(() => repository.deleteForumPost('post-1')).called(1);
  });

  test('CreateForumPostEvent creates post with tags', () async {
    final createdPost = ForumPostEntity(
      id: 'post-3',
      authorId: 'user-1',
      authorName: 'ScholarOne',
      track: 'WAEC',
      title: 'Vector spaces',
      content: 'How do you prove basis?',
      tags: const ['linear-algebra', 'math'],
      createdAt: DateTime.now(),
    );

    when(
      () => repository.createForumPost(
        title: 'Vector spaces',
        content: 'How do you prove basis?',
        track: 'WAEC',
        latexContent: any(named: 'latexContent'),
        isQuestion: any(named: 'isQuestion'),
        syllabusTag: any(named: 'syllabusTag'),
        tags: ['linear-algebra', 'math'],
        isAnonymous: any(named: 'isAnonymous'),
        mediaUrls: any(named: 'mediaUrls'),
        voiceNoteUrl: any(named: 'voiceNoteUrl'),
        voiceNoteDurationSeconds: any(named: 'voiceNoteDurationSeconds'),
      ),
    ).thenAnswer((_) async => Right(createdPost));

    bloc.add(
      const CreateForumPostEvent(
        title: 'Vector spaces',
        content: 'How do you prove basis?',
        track: 'WAEC',
        tags: ['linear-algebra', 'math'],
      ),
    );
    await pumpEventQueue();

    expect(bloc.state.forumPosts.first.id, 'post-3');
    expect(bloc.state.forumPosts.first.tags, ['linear-algebra', 'math']);
  });

  test('RefreshForumPostsEvent fetches latest forum posts and completes completer', () async {
    when(
      () => repository.fetchForumPosts(
        track: any(named: 'track'),
        questionsOnly: any(named: 'questionsOnly'),
        sortFilter: any(named: 'sortFilter'),
        searchQuery: any(named: 'searchQuery'),
      ),
    ).thenAnswer((_) async => Right([samplePost]));

    final completer = Completer<void>();
    bloc.add(RefreshForumPostsEvent(completer: completer));
    await completer.future;

    expect(bloc.state.forumPosts, [samplePost]);
    verify(
      () => repository.fetchForumPosts(
        track: any(named: 'track'),
        questionsOnly: any(named: 'questionsOnly'),
        sortFilter: any(named: 'sortFilter'),
      ),
    ).called(1);
  });
}
