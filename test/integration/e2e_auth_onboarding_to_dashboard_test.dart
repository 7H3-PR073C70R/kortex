import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/use_cases/auto_provision_community_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/logic/ebbinghaus_decay_calculator.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_dashboard_feed_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockCommunityRepository extends Mock implements CommunityRepository {}

class MockDashboardRepository extends Mock implements DashboardRepository {}

void main() {
  group('E2E Auth -> Calibration -> Community Hub -> Dashboard Test Suite', () {
    late MockAuthRepository mockAuthRepo;
    late MockCommunityRepository mockCommunityRepo;
    late MockDashboardRepository mockDashboardRepo;
    late RegisterWithEmailUseCase registerUseCase;
    late CompleteOnboardingUseCase completeOnboardingUseCase;
    late AutoProvisionCommunityUseCase autoCommunityUseCase;
    late GetDashboardFeedUseCase getDashboardFeedUseCase;
    const decayCalculator = EbbinghausDecayCalculator();

    const tUser = UserEntity(
      id: 'user-sat-scholar',
      email: 'scholar@satstem.edu',
    );

    const tProfile = UserProfileEntity(
      id: 'user-sat-scholar',
      email: 'scholar@satstem.edu',
      targetTrack: 'SAT',
      dailyCardTarget: 25,
      retentionBenchmark: 0.88,
      isOnboarded: true,
    );

    const tCommunity = StudyCommunityEntity(
      id: 'comm-sat-1',
      courseCode: 'SAT',
      title: 'SAT Secondary Core STEM Hub',
      department: 'Sciences',
      memberCount: 42,
      activeRoomsCount: 2,
      forumThreadsCount: 8,
    );

    final tFeed = DashboardFeedEntity(
      calibrationProfile: const CalibrationProfile(
        highSchoolExam: 'SAT',
        isCalibrated: true,
      ),
      analyticsSummary: const AnalyticsSummaryEntity(
        currentStreakDays: 1,
        longestStreakDays: 1,
        weeklyMinutesStudied: 30,
        overallRetentionRate: 0.88,
        totalCardsMastered: 10,
        heatMapData: [],
        xpPoints: 150,
        academicRank: 'Novice Scholar',
      ),
      targetExamCountdown: ExamCountdownEntity(
        id: 'sat-2026',
        examName: 'SAT STEM Prep',
        targetDate: DateTime.now().add(const Duration(days: 62)),
        syllabusProgress: 0.25,
        subjectTrack: 'SAT',
        totalMockPapersAvailable: 20,
        completedMocksCount: 2,
      ),
      dueStudyDecks: const [],
      curatedCourses: const [],
    );

    setUp(() {
      mockAuthRepo = MockAuthRepository();
      mockCommunityRepo = MockCommunityRepository();
      mockDashboardRepo = MockDashboardRepository();

      registerUseCase = RegisterWithEmailUseCase(mockAuthRepo);
      completeOnboardingUseCase = CompleteOnboardingUseCase(mockAuthRepo);
      autoCommunityUseCase = AutoProvisionCommunityUseCase(mockCommunityRepo);
      getDashboardFeedUseCase = GetDashboardFeedUseCase(mockDashboardRepo);
    });

    test(
      'Full Onboarding: Auth -> Calibration -> Community Hub -> Decay Curve',
      () async {
        // 1. User Registration
        when(
          () => mockAuthRepo.registerWithEmail(
            email: 'scholar@satstem.edu',
            password: 'Password123!',
          ),
        ).thenAnswer((_) async => const Right(tUser));

        final regResult = await registerUseCase(
          const RegisterParams(
            email: 'scholar@satstem.edu',
            password: 'Password123!',
          ),
        );
        expect(regResult.isRight, isTrue);

        // 2. Complete Onboarding Calibration
        when(
          () => mockAuthRepo.completeOnboarding(
            track: 'SAT',
            dailyTarget: 25,
            retentionBenchmark: 0.88,
          ),
        ).thenAnswer((_) async => const Right(tProfile));

        final onboardResult = await completeOnboardingUseCase(
          track: 'SAT',
          dailyTarget: 25,
          retentionBenchmark: 0.88,
        );
        expect(onboardResult.isRight, isTrue);
        onboardResult.fold(
          (l) => fail('Expected onboarding success'),
          (p) => expect(p.targetTrack, equals('SAT')),
        );

        // 3. Auto-Provision Dedicated Peer Community Hub
        when(
          () => mockCommunityRepo.autoProvisionCommunity(
            courseCode: 'SAT',
            title: 'SAT Secondary Core STEM Hub',
          ),
        ).thenAnswer((_) async => const Right(tCommunity));

        final commResult = await autoCommunityUseCase(
          courseCode: 'SAT',
          title: 'SAT Secondary Core STEM Hub',
        );
        expect(commResult.isRight, isTrue);
        commResult.fold(
          (l) => fail('Expected community success'),
          (c) => expect(c.memberCount, equals(42)),
        );

        // 4. Fetch Dashboard Feed & Compute Adaptive Decay Curve
        when(
          () => mockDashboardRepo.getDashboardFeed(),
        ).thenAnswer((_) async => Right(tFeed));

        final feedResult = await getDashboardFeedUseCase(const NoParams());
        expect(feedResult.isRight, isTrue);
        feedResult.fold(
          (l) => fail('Expected feed success'),
          (f) => expect(f.targetExamCountdown?.subjectTrack, equals('SAT')),
        );

        // 5. Calculate Adaptive Retention Curve
        final projection = decayCalculator.calculateSevenDayProjection(
          cardStabilities: [2.4, 5.8, 1.2],
        );
        expect(projection.length, equals(7));
        expect(projection.first.predictedRetention, equals(1.0));
        expect(projection.last.predictedRetention, lessThan(1.0));
      },
    );
  });
}
