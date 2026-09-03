import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

void main() {
  late MockCommunityRepository mockRepository;
  late CommunityHubBloc bloc;

  const testRoom = StudyRoomEntity(
    id: 'room_1',
    title: 'Calculus Deep Focus',
    subject: 'Mathematics',
    category: 'STEM',
    activeParticipantsCount: 5,
  );

  final testPost = ForumPostEntity(
    id: 'post_1',
    authorId: 'user_1',
    authorName: 'Adeola',
    track: 'JAMB',
    title: 'How to integrate by parts?',
    content: 'Can someone explain the formula?',
    createdAt: DateTime(2026, 8, 31),
  );

  const testDeck = SharedDeckEntity(
    id: 'deck_1',
    ownerId: 'user_1',
    ownerName: 'Adeola',
    title: 'JAMB Physics Mastery',
    subject: 'Physics',
    totalCards: 20,
    downloadsCount: 15,
    rating: 4.9,
  );

  const testLeaderboardEntry = LeaderboardEntryEntity(
    id: 'lb_1',
    userId: 'user_1',
    userName: 'Adeola Vance',
    track: 'JAMB',
    dailyXp: 320,
    weeklyXp: 2450,
    streakDays: 14,
  );

  setUp(() {
    mockRepository = MockCommunityRepository();
    when(
      () => mockRepository.streamLeaderboards(track: any(named: 'track')),
    ).thenAnswer((_) => Stream.value([testLeaderboardEntry]));
    bloc = CommunityHubBloc(repository: mockRepository);
  });

  tearDown(() async {
    await bloc.close();
  });

  group('CommunityHubBloc', () {
    test('initial state is initial with tab 0', () {
      expect(bloc.state.status, CommunityStatus.initial);
      expect(bloc.state.selectedTabIndex, 0);
      expect(bloc.state.studyRooms, isEmpty);
    });

    blocTest<CommunityHubBloc, CommunityState>(
      'loads community hub successfully',
      build: () {
        when(
          () => mockRepository.fetchStudyRooms(
            category: any(named: 'category'),
          ),
        ).thenAnswer((_) async => const Right([testRoom]));

        when(
          () => mockRepository.fetchForumPosts(
            track: any(named: 'track'),
          ),
        ).thenAnswer((_) async => Right([testPost]));

        when(
          () => mockRepository.fetchSharedDecks(
            subject: any(named: 'subject'),
          ),
        ).thenAnswer((_) async => const Right([testDeck]));

        when(
          () => mockRepository.fetchLeaderboards(
            track: any(named: 'track'),
          ),
        ).thenAnswer((_) async => const Right([testLeaderboardEntry]));

        return bloc;
      },
      act: (bloc) => bloc.add(const LoadCommunityHubEvent()),
      expect: () => [
        const CommunityState(status: CommunityStatus.loading),
        CommunityState(
          status: CommunityStatus.loaded,
          studyRooms: const [testRoom],
          forumPosts: [testPost],
          sharedDecks: const [testDeck],
          leaderboardEntries: const [testLeaderboardEntry],
        ),
      ],
    );

    blocTest<CommunityHubBloc, CommunityState>(
      'switches tab index',
      build: () => bloc,
      act: (bloc) => bloc.add(const SwitchCommunityTabEvent(2)),
      expect: () => [
        const CommunityState(selectedTabIndex: 2),
      ],
    );

    blocTest<CommunityHubBloc, CommunityState>(
      'clones shared deck and updates lastClonedDeckId',
      build: () {
        const clonedDeck = DeckEntity(
          id: 'new_cloned_deck_1',
          title: 'JAMB Physics',
          subject: 'Physics',
          totalCards: 20,
          dueCards: 20,
          masteryRate: 0,
          category: 'STEM',
        );
        when(
          () => mockRepository.cloneSharedDeck('deck_1'),
        ).thenAnswer((_) async => const Right(clonedDeck));
        return bloc;
      },
      act: (bloc) => bloc.add(const CloneDeckEvent('deck_1')),
      expect: () => [
        const CommunityState(lastClonedDeckId: 'new_cloned_deck_1'),
      ],
    );
  });
}
