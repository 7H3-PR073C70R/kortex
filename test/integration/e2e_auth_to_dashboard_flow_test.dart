import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_dashboard_feed_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDashboardRepository extends Mock implements DashboardRepository {}

void main() {
  group('E2E Auth to Onboarding to Dashboard Calibration Flow Test Suite', () {
    late MockAuthRepository mockAuthRepository;
    late MockDashboardRepository mockDashboardRepository;
    late RegisterWithEmailUseCase registerUseCase;
    late CompleteOnboardingUseCase completeOnboardingUseCase;
    late GetDashboardFeedUseCase getDashboardFeedUseCase;

    const tUser = UserEntity(
      id: 'usr_sat_scholar',
      email: 'scholar@satprep.edu',
    );

    const tCalibratedProfile = UserProfileEntity(
      id: 'usr_sat_scholar',
      email: 'scholar@satprep.edu',
      targetTrack: 'SAT',
      dailyCardTarget: 35,
      retentionBenchmark: 0.90,
      isOnboarded: true,
    );

    final tDashboardFeed = DashboardFeedEntity(
      calibrationProfile: CalibrationProfile(
        focus: AcademicFocus.highSchool,
        highSchoolExam: tCalibratedProfile.targetTrack,
        isCalibrated: tCalibratedProfile.isOnboarded,
      ),
      analyticsSummary: AnalyticsSummaryEntity(
        currentStreakDays: 1,
        longestStreakDays: 1,
        weeklyMinutesStudied: 45,
        overallRetentionRate: tCalibratedProfile.retentionBenchmark,
        totalCardsMastered: 0,
        heatMapData: const [],
        xpPoints: 100,
        academicRank: 'Novice Scholar',
      ),
      targetExamCountdown: ExamCountdownEntity(
        id: 'sat_2026',
        examName: 'SAT Digital Reasoning',
        targetDate: DateTime.now().add(const Duration(days: 60)),
        syllabusProgress: 0.20,
        subjectTrack: 'SAT',
        totalMockPapersAvailable: 15,
        completedMocksCount: 1,
      ),
      dueStudyDecks: const [],
      curatedCourses: const [],
    );

    setUp(() {
      mockAuthRepository = MockAuthRepository();
      mockDashboardRepository = MockDashboardRepository();
      registerUseCase = RegisterWithEmailUseCase(mockAuthRepository);
      completeOnboardingUseCase = CompleteOnboardingUseCase(mockAuthRepository);
      getDashboardFeedUseCase =
          GetDashboardFeedUseCase(mockDashboardRepository);
    });

    test(
      'Full E2E Flow: Sign Up -> Select Track -> Calibrate -> Load Feed',
      () async {
        // Step 1: User Signs Up
        when(
          () => mockAuthRepository.registerWithEmail(
            email: 'scholar@satprep.edu',
            password: 'SecurePassword123!',
            displayName: 'SAT Scholar',
          ),
        ).thenAnswer((_) async => const Right(tUser));

        final registerResult = await registerUseCase(
          const RegisterParams(
            email: 'scholar@satprep.edu',
            password: 'SecurePassword123!',
            displayName: 'SAT Scholar',
          ),
        );

        expect(registerResult.isRight, isTrue);
        final registeredUser =
            (registerResult as Right<dynamic, UserEntity>).value;
        expect(registeredUser.id, equals('usr_sat_scholar'));

        // Step 2: User completes Onboarding track & retention calibration
        when(
          () => mockAuthRepository.completeOnboarding(
            track: 'SAT',
            dailyTarget: 35,
            retentionBenchmark: 0.90,
          ),
        ).thenAnswer((_) async => const Right(tCalibratedProfile));

        final onboardingResult = await completeOnboardingUseCase(
          track: 'SAT',
          dailyTarget: 35,
          retentionBenchmark: 0.90,
        );

        expect(onboardingResult.isRight, isTrue);
        final calibrated =
            (onboardingResult as Right<dynamic, UserProfileEntity>).value;
        expect(calibrated.isOnboarded, isTrue);
        expect(calibrated.dailyCardTarget, equals(35));
        expect(calibrated.retentionBenchmark, equals(0.90));

        // Step 3: Dashboard Feed loads calibrated metrics matching user targets
        when(() => mockDashboardRepository.getDashboardFeed())
            .thenAnswer((_) async => Right(tDashboardFeed));

        final feedResult = await getDashboardFeedUseCase(const NoParams());
        expect(feedResult.isRight, isTrue);
        final feed =
            (feedResult as Right<dynamic, DashboardFeedEntity>).value;

        expect(feed.calibrationProfile.highSchoolExam, equals('SAT'));
        expect(feed.analyticsSummary.overallRetentionRate, equals(0.90));
        expect(feed.targetExamCountdown?.subjectTrack, equals('SAT'));
      },
    );
  });
}
