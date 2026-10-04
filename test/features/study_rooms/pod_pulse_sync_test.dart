import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/study_rooms/data/models/study_circle_model.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

void main() {
  late MockCommunityRepository mockRepository;
  late CommunityHubBloc bloc;

  const testMember = StudyCircleMemberEntity(
    id: 'm_1',
    userId: 'u_1',
    userName: 'Scholar Adeola',
    role: 'creator',
    weeklyMinutesContributed: 180,
  );

  const testCircle1 = StudyCircleEntity(
    id: 'circle_1',
    name: 'JAMB Focus Sprint Pod',
    track: 'JAMB',
    memberCount: 3,
    totalMinutesCompleted: 450,
    members: [testMember],
    isLive: true,
    activeParticipantsCount: 2,
    currentFocusTopic: 'Calculus & Vectors',
  );

  const testCircle2 = StudyCircleEntity(
    id: 'circle_2',
    name: 'WAEC Physics Mastery Pod',
    track: 'WAEC',
    memberCount: 4,
    totalMinutesCompleted: 600,
    isCurrentUserMember: true,
  );

  setUp(() {
    mockRepository = MockCommunityRepository();

    when(
      () => mockRepository.streamLeaderboards(track: any(named: 'track')),
    ).thenAnswer((_) => const Stream<List<LeaderboardEntryEntity>>.empty());

    when(
      () => mockRepository.watchStudyCircles(track: any(named: 'track')),
    ).thenAnswer((_) => Stream.value([testCircle1, testCircle2]));

    when(
      () => mockRepository.getBookmarkedForumPostIds(),
    ).thenAnswer((_) async => const Right(<String>{}));

    when(
      () => mockRepository.getFollowedTopics(),
    ).thenAnswer((_) async => const Right(<String>{}));

    bloc = CommunityHubBloc(repository: mockRepository);
  });

  tearDown(() async {
    await bloc.close();
  });

  group('Pod Pulse Sync Unit Tests', () {
    test('StudyCircleEntity properties & available slots calculation', () {
      expect(testCircle1.availableSlots, equals(5));
      expect(testCircle1.effectiveMemberCount, equals(1));
      expect(testCircle1.isFull, isFalse);
      expect(testCircle1.weeklyProgressPercent, closeTo(0.75, 0.01));
      expect(testCircle1.isLive, isTrue);
      expect(testCircle1.activeParticipantsCount, equals(2));
      expect(testCircle1.currentFocusTopic, equals('Calculus & Vectors'));
    });

    test('StudyCircleModel serialization and deserialization', () {
      final jsonMap = {
        'id': 'circle_test',
        'name': 'Test Pod',
        'track': 'JAMB',
        'target_weekly_minutes': 600,
        'creator_id': 'c_1',
        'max_members': 6,
        'member_count': 3,
        'total_minutes_completed': 300,
        'is_live': true,
        'active_participants_count': 3,
        'current_focus_topic': 'Organic Chemistry',
        'study_circle_members': [
          {
            'id': 'm_1',
            'user_id': 'u_1',
            'user_name': 'Adeola',
            'role': 'creator',
            'weekly_minutes_contributed': 120,
          }
        ],
      };

      final model = StudyCircleModel.fromJson(jsonMap);
      expect(model.id, equals('circle_test'));
      expect(model.isLive, isTrue);
      expect(model.activeParticipantsCount, equals(3));
      expect(model.currentFocusTopic, equals('Organic Chemistry'));

      final entity = model.toEntity(currentUserId: 'u_1');
      expect(entity.isCurrentUserMember, isTrue);
      expect(entity.name, equals('Test Pod'));
      expect(entity.members.length, equals(1));

      final serialized = model.toJson();
      expect(serialized['id'], equals('circle_test'));
      expect(serialized['is_live'], isTrue);
    });

    test('CommunityState Pod Pulse getters', () {
      const state = CommunityState(
        studyCircles: [testCircle1, testCircle2],
      );

      expect(state.myPods.length, equals(1));
      expect(state.myPods.first.id, equals('circle_2'));
      expect(state.availablePods.length, equals(1));
      expect(state.availablePods.first.id, equals('circle_1'));
      expect(state.totalActiveScholars, equals(5)); // 1 member + 4 member count
      expect(state.totalGroupFocusMinutes, equals(1050));
    });

    blocTest<CommunityHubBloc, CommunityState>(
      'emits updated studyCircles when StudyCirclesUpdatedEvent is added',
      build: () => bloc,
      act: (b) => b.add(const StudyCirclesUpdatedEvent([testCircle1, testCircle2])),
      expect: () => [
        isA<CommunityState>().having(
          (s) => s.studyCircles,
          'studyCircles',
          equals([testCircle1, testCircle2]),
        ),
      ],
    );

    blocTest<CommunityHubBloc, CommunityState>(
      'subscribes to watchStudyCircles stream on LoadStudyCirclesEvent',
      build: () {
        when(
          () => mockRepository.fetchStudyCircles(track: any(named: 'track')),
        ).thenAnswer((_) async => const Right([testCircle1]));
        return bloc;
      },
      act: (b) => b.add(const LoadStudyCirclesEvent(track: 'JAMB')),
      expect: () => [
        isA<CommunityState>().having(
          (s) => s.studyCircles,
          'studyCircles',
          equals([testCircle1]),
        ),
        isA<CommunityState>().having(
          (s) => s.studyCircles,
          'studyCircles',
          equals([testCircle1, testCircle2]),
        ),
      ],
      verify: (_) {
        verify(() => mockRepository.watchStudyCircles(track: 'JAMB')).called(1);
      },
    );
  });
}
