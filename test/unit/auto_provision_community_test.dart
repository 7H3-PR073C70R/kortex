import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/use_cases/auto_provision_community_use_case.dart';
import 'package:kortex/src/features/community/domain/use_cases/fetch_course_community_stats_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

void main() {
  group('Auto-Provision Community Engine Unit Test Suite', () {
    late MockCommunityRepository mockCommunityRepository;
    late AutoProvisionCommunityUseCase autoProvisionUseCase;
    late FetchCourseCommunityStatsUseCase fetchStatsUseCase;

    const tCommunity = StudyCommunityEntity(
      id: 'comm_waec_chem',
      courseCode: 'WAEC-CHEM',
      title: 'WAEC Chemistry Study Hub',
      department: 'Science',
      memberCount: 42,
      activeRoomsCount: 2,
      forumThreadsCount: 5,
      isFoundingMember: true,
      activeRoomId: 'room_focus_1',
      activeRoomTitle: '25m Reaction Kinetics Focus',
    );

    setUp(() {
      mockCommunityRepository = MockCommunityRepository();
      autoProvisionUseCase =
          AutoProvisionCommunityUseCase(mockCommunityRepository);
      fetchStatsUseCase =
          FetchCourseCommunityStatsUseCase(mockCommunityRepository);
    });

    test(
      'autoProvisionCommunity creates/joins new community and returns entity',
      () async {
        when(
          () => mockCommunityRepository.autoProvisionCommunity(
            courseCode: 'WAEC-CHEM',
            title: 'WAEC Chemistry Study Hub',
            department: 'Science',
          ),
        ).thenAnswer((_) async => const Right(tCommunity));

        final result = await autoProvisionUseCase(
          courseCode: 'WAEC-CHEM',
          title: 'WAEC Chemistry Study Hub',
          department: 'Science',
        );

        expect(result.isRight, isTrue);
        final community =
            (result as Right<dynamic, StudyCommunityEntity>).value;
        expect(community.courseCode, equals('WAEC-CHEM'));
        expect(community.isFoundingMember, isTrue);
        expect(community.memberCount, equals(42));
      },
    );

    test(
      'autoProvisionCommunity propagates failure gracefully on server error',
      () async {
        when(
          () => mockCommunityRepository.autoProvisionCommunity(
            courseCode: any(named: 'courseCode'),
            title: any(named: 'title'),
            department: any(named: 'department'),
          ),
        ).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Database error')),
        );

        final result = await autoProvisionUseCase(
          courseCode: 'CHE-301',
          title: 'Organic Synthesis',
        );

        expect(result.isLeft, isTrue);
        final failure = (result as Left<Failure, dynamic>).value;
        expect(failure.message, equals('Database error'));
      },
    );

    test('fetchCourseCommunityStats retrieves updated peer count', () async {
      when(() => mockCommunityRepository.fetchCourseCommunityStats('WAEC-CHEM'))
          .thenAnswer((_) async => const Right(tCommunity));

      final result = await fetchStatsUseCase('WAEC-CHEM');

      expect(result.isRight, isTrue);
      final community =
          (result as Right<dynamic, StudyCommunityEntity>).value;
      expect(community.activeRoomsCount, equals(2));
      expect(community.activeRoomTitle, contains('Reaction Kinetics'));
    });
  });
}
