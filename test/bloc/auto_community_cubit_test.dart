import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/use_cases/auto_provision_community_use_case.dart';
import 'package:kortex/src/features/community/domain/use_cases/fetch_course_community_stats_use_case.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAutoProvisionCommunityUseCase extends Mock
    implements AutoProvisionCommunityUseCase {}

class MockFetchCourseCommunityStatsUseCase extends Mock
    implements FetchCourseCommunityStatsUseCase {}

void main() {
  group('AutoCommunityCubit State Management Test Suite', () {
    late MockAutoProvisionCommunityUseCase mockAutoProvisionUseCase;
    late MockFetchCourseCommunityStatsUseCase mockFetchStatsUseCase;

    const tTrackCommunity = StudyCommunityEntity(
      id: 'comm_jamb_hub',
      courseCode: 'JAMB-STUDY-HUB',
      title: 'JAMB Peer Study Hub',
      department: 'JAMB',
      memberCount: 142,
      activeRoomsCount: 4,
      forumThreadsCount: 12,
    );

    const tDocCommunity = StudyCommunityEntity(
      id: 'comm_phy_201',
      courseCode: 'PHY-201',
      title: 'Classical Electrodynamics',
      department: 'Physics',
      memberCount: 24,
      activeRoomsCount: 1,
      forumThreadsCount: 3,
      isFoundingMember: true,
    );

    setUp(() {
      mockAutoProvisionUseCase = MockAutoProvisionCommunityUseCase();
      mockFetchStatsUseCase = MockFetchCourseCommunityStatsUseCase();
    });

    AutoCommunityCubit buildCubit() => AutoCommunityCubit(
      autoProvisionCommunityUseCase: mockAutoProvisionUseCase,
      fetchCourseCommunityStatsUseCase: mockFetchStatsUseCase,
    );

    test('initial state has initial status and banner not dismissed', () async {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(AutoCommunityStatus.initial));
      expect(cubit.state.community, isNull);
      expect(cubit.state.isBannerDismissed, isFalse);
      expect(cubit.state.shouldShowBanner, isFalse);
      await cubit.close();
    });

    blocTest<AutoCommunityCubit, AutoCommunityState>(
      'provisionForTrack emits provisioning then provisioned with track hub',
      build: () {
        when(
          () => mockAutoProvisionUseCase(
            courseCode: 'JAMB-STUDY-HUB',
            title: 'JAMB Peer Study Hub',
            department: 'JAMB',
          ),
        ).thenAnswer((_) async => const Right(tTrackCommunity));
        return buildCubit();
      },
      act: (cubit) => cubit.provisionForTrack('JAMB'),
      expect: () => [
        const AutoCommunityState(status: AutoCommunityStatus.provisioning),
        const AutoCommunityState(
          status: AutoCommunityStatus.provisioned,
          community: tTrackCommunity,
        ),
      ],
      verify: (cubit) {
        expect(cubit.state.shouldShowBanner, isTrue);
      },
    );

    blocTest<AutoCommunityCubit, AutoCommunityState>(
      'provisionForDocument emits provisioned with document hub',
      build: () {
        when(
          () => mockAutoProvisionUseCase(
            courseCode: 'PHY-201',
            title: 'Classical Electrodynamics',
            department: 'Physics',
          ),
        ).thenAnswer((_) async => const Right(tDocCommunity));
        return buildCubit();
      },
      act: (cubit) => cubit.provisionForDocument(
        courseCode: 'PHY-201',
        title: 'Classical Electrodynamics',
        department: 'Physics',
      ),
      expect: () => [
        const AutoCommunityState(status: AutoCommunityStatus.provisioning),
        const AutoCommunityState(
          status: AutoCommunityStatus.provisioned,
          community: tDocCommunity,
        ),
      ],
    );

    blocTest<AutoCommunityCubit, AutoCommunityState>(
      'provisionForTrack emits error when use case fails',
      build: () {
        when(
          () => mockAutoProvisionUseCase(
            courseCode: any(named: 'courseCode'),
            title: any(named: 'title'),
            department: any(named: 'department'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            ServerFailure(message: 'Failed to provision community'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.provisionForTrack('SAT'),
      expect: () => [
        const AutoCommunityState(status: AutoCommunityStatus.provisioning),
        const AutoCommunityState(
          status: AutoCommunityStatus.error,
          errorMessage: 'Failed to provision community',
        ),
      ],
    );

    blocTest<AutoCommunityCubit, AutoCommunityState>(
      'dismissBanner sets isBannerDismissed to true',
      build: buildCubit,
      seed: () => const AutoCommunityState(
        status: AutoCommunityStatus.provisioned,
        community: tTrackCommunity,
      ),
      act: (cubit) => cubit.dismissBanner(),
      expect: () => [
        const AutoCommunityState(
          status: AutoCommunityStatus.provisioned,
          community: tTrackCommunity,
          isBannerDismissed: true,
        ),
      ],
      verify: (cubit) {
        expect(cubit.state.shouldShowBanner, isFalse);
      },
    );
  });
}
