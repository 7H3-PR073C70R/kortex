import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_dashboard_feed_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/quick_start_mock_exam_use_case.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:mocktail/mocktail.dart';

class MockGetDashboardFeedUseCase extends Mock
    implements GetDashboardFeedUseCase {}

class MockQuickStartMockExamUseCase extends Mock
    implements QuickStartMockExamUseCase {}

void main() {
  group('DashboardBloc Feed Mutation Test Suite', () {
    late MockGetDashboardFeedUseCase mockGetDashboardFeedUseCase;
    late MockQuickStartMockExamUseCase mockQuickStartMockExamUseCase;

    const tFeedHighSchool = DashboardFeedEntity(
      calibrationProfile: CalibrationProfile(
        focus: AcademicFocus.highSchool,
        highSchoolExam: 'WAEC',
        isCalibrated: true,
      ),
      analyticsSummary: AnalyticsSummaryEntity(
        currentStreakDays: 4,
        longestStreakDays: 10,
        weeklyMinutesStudied: 180,
        overallRetentionRate: 0.89,
        totalCardsMastered: 95,
        heatMapData: [],
        xpPoints: 600,
        academicRank: 'Neural Scholar II',
      ),
      dueStudyDecks: [],
      curatedCourses: [],
    );

    setUp(() {
      mockGetDashboardFeedUseCase = MockGetDashboardFeedUseCase();
      mockQuickStartMockExamUseCase = MockQuickStartMockExamUseCase();
    });

    DashboardBloc buildBloc() => DashboardBloc(
      getDashboardFeedUseCase: mockGetDashboardFeedUseCase,
      quickStartMockExamUseCase: mockQuickStartMockExamUseCase,
    );

    test('initial state is initial status with null feed', () async {
      final bloc = buildBloc();
      expect(bloc.state.status, equals(DashboardStatus.initial));
      expect(bloc.state.feed, isNull);
      await bloc.close();
    });

    blocTest<DashboardBloc, DashboardState>(
      'DashboardStarted emits loaded status with HighSchool calibration feed',
      build: () {
        when(
          () => mockGetDashboardFeedUseCase(const NoParams()),
        ).thenAnswer((_) async => const Right(tFeedHighSchool));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const DashboardStarted()),
      expect: () => [
        const DashboardState(status: DashboardStatus.loading),
        const DashboardState(
          status: DashboardStatus.loaded,
          feed: tFeedHighSchool,
        ),
      ],
      verify: (bloc) {
        expect(bloc.state.feed?.isHighSchoolCandidate, isTrue);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'DashboardStarted emits error status on failure',
      build: () {
        when(() => mockGetDashboardFeedUseCase(const NoParams())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Server error')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const DashboardStarted()),
      expect: () => [
        const DashboardState(status: DashboardStatus.loading),
        const DashboardState(
          status: DashboardStatus.error,
          errorMessage: 'Server error',
        ),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'DashboardRefreshed updates feed without changing to loading state',
      build: () {
        when(
          () => mockGetDashboardFeedUseCase(const NoParams()),
        ).thenAnswer((_) async => const Right(tFeedHighSchool));
        return buildBloc();
      },
      seed: () => const DashboardState(
        status: DashboardStatus.loaded,
      ),
      act: (bloc) => bloc.add(const DashboardRefreshed()),
      expect: () => [
        const DashboardState(
          status: DashboardStatus.loaded,
          feed: tFeedHighSchool,
        ),
      ],
    );
  });
}
