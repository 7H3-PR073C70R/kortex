import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
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

class FakeGetDashboardFeedParams extends Fake
    implements GetDashboardFeedParams {}

const _tCalibrationProfile = CalibrationProfile(isCalibrated: true);

const _tAnalytics = AnalyticsSummaryEntity(
  currentStreakDays: 5,
  longestStreakDays: 10,
  weeklyMinutesStudied: 120,
  overallRetentionRate: 0.85,
  totalCardsMastered: 200,
  heatMapData: [],
  xpPoints: 500,
  academicRank: 'Neural Scholar II',
);

const _tFeed = DashboardFeedEntity(
  calibrationProfile: _tCalibrationProfile,
  analyticsSummary: _tAnalytics,
  dueStudyDecks: [],
  curatedCourses: [],
);

DashboardFeedEntity _makeFeedWithDecks() => DashboardFeedEntity(
  calibrationProfile: _tCalibrationProfile,
  analyticsSummary: _tAnalytics,
  dueStudyDecks: [
    StudyDeckEntity(
      id: 'deck_1',
      title: 'Biology',
      subject: 'Biology',
      totalCards: 50,
      dueCards: 10,
      retentionRate: 0.78,
      lastReviewed: DateTime(2026, 9, 28),
      category: 'STEM',
    ),
    StudyDeckEntity(
      id: 'deck_2',
      title: 'Chemistry',
      subject: 'Chemistry',
      totalCards: 40,
      dueCards: 5,
      retentionRate: 0.82,
      lastReviewed: DateTime(2026, 9, 28),
      category: 'STEM',
    ),
  ],
  curatedCourses: const [],
);

void main() {
  late MockGetDashboardFeedUseCase mockGetFeedUseCase;
  late MockQuickStartMockExamUseCase mockExamUseCase;

  setUpAll(() {
    registerFallbackValue(FakeGetDashboardFeedParams());
  });

  setUp(() {
    mockGetFeedUseCase = MockGetDashboardFeedUseCase();
    mockExamUseCase = MockQuickStartMockExamUseCase();
  });

  DashboardBloc buildBloc() => DashboardBloc(
        getDashboardFeedUseCase: mockGetFeedUseCase,
        quickStartMockExamUseCase: mockExamUseCase,
      );

  group('DashboardBloc — cold-start (no existing feed)', () {
    blocTest<DashboardBloc, DashboardState>(
      'emits [loading, fullyLoaded] on successful cold start',
      build: () {
        when(() => mockGetFeedUseCase(any()))
            .thenAnswer((_) async => const Right(_tFeed));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const DashboardStarted()),
      expect: () => [
        const DashboardState(status: DashboardStatus.loading),
        const DashboardState(
          status: DashboardStatus.loaded,
          sectionStatus: DashboardSectionStatus.fullyLoaded,
          feed: _tFeed,
        ),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits [loading, error] when feed use-case fails',
      build: () {
        when(() => mockGetFeedUseCase(any())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Network error')),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const DashboardStarted()),
      expect: () => [
        const DashboardState(status: DashboardStatus.loading),
        const DashboardState(
          status: DashboardStatus.error,
          sectionStatus: DashboardSectionStatus.error,
          errorMessage: 'Network error',
        ),
      ],
    );
  });

  group('DashboardBloc — stale-while-revalidate (existing feed present)', () {
    blocTest<DashboardBloc, DashboardState>(
      'emits [revalidating, fullyLoaded] without showing loading shimmer',
      build: () {
        when(() => mockGetFeedUseCase(any()))
            .thenAnswer((_) async => const Right(_tFeed));
        return buildBloc();
      },
      seed: () => const DashboardState(
        status: DashboardStatus.loaded,
        sectionStatus: DashboardSectionStatus.fullyLoaded,
        feed: _tFeed,
      ),
      act: (bloc) => bloc.add(const DashboardStarted()),
      verify: (bloc) {
        // Must NOT have shown loading shimmer on revisit.
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.sectionStatus,
            equals(DashboardSectionStatus.fullyLoaded));
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'when revalidation fails, keeps fullyLoaded (no error screen)',
      build: () {
        when(() => mockGetFeedUseCase(any())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Timeout')),
        );
        return buildBloc();
      },
      seed: () => const DashboardState(
        status: DashboardStatus.loaded,
        sectionStatus: DashboardSectionStatus.fullyLoaded,
        feed: _tFeed,
      ),
      act: (bloc) => bloc.add(const DashboardStarted()),
      verify: (bloc) {
        // Feed still present, no error screen shown.
        expect(bloc.state.displayFeed, equals(_tFeed));
        expect(bloc.state.isError, isFalse);
      },
    );
  });

  group('DashboardBloc — DashboardRefreshed', () {
    blocTest<DashboardBloc, DashboardState>(
      'emits [revalidating, fullyLoaded] on successful refresh',
      build: () {
        when(() => mockGetFeedUseCase(any()))
            .thenAnswer((_) async => const Right(_tFeed));
        return buildBloc();
      },
      seed: () => const DashboardState(
        status: DashboardStatus.loaded,
        sectionStatus: DashboardSectionStatus.fullyLoaded,
        feed: _tFeed,
      ),
      act: (bloc) => bloc.add(const DashboardRefreshed()),
      expect: () => [
        const DashboardState(
          status: DashboardStatus.loaded,
          sectionStatus: DashboardSectionStatus.revalidating,
          feed: _tFeed,
          previousFeed: _tFeed,
        ),
        const DashboardState(
          status: DashboardStatus.loaded,
          sectionStatus: DashboardSectionStatus.fullyLoaded,
          feed: _tFeed,
        ),
      ],
    );
  });

  group('DashboardBloc — DashboardDeckDeleted', () {
    blocTest<DashboardBloc, DashboardState>(
      'removes deck from feed without a network call',
      build: buildBloc,
      seed: () => DashboardState(
        status: DashboardStatus.loaded,
        sectionStatus: DashboardSectionStatus.fullyLoaded,
        feed: _makeFeedWithDecks(),
      ),
      act: (bloc) => bloc.add(const DashboardDeckDeleted('deck_1')),
      verify: (_) {
        verifyNever(() => mockGetFeedUseCase(any()));
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'does nothing if feed is null',
      build: buildBloc,
      act: (bloc) => bloc.add(const DashboardDeckDeleted('deck_1')),
      expect: () => <DashboardState>[],
    );
  });

  group('DashboardState — computed getters', () {
    test('hasDisplayableFeed: true with live feed', () {
      expect(
          const DashboardState(feed: _tFeed).hasDisplayableFeed, isTrue);
    });
    test('hasDisplayableFeed: true with only previousFeed', () {
      expect(
          const DashboardState(previousFeed: _tFeed).hasDisplayableFeed,
          isTrue);
    });
    test('hasDisplayableFeed: false when both null', () {
      expect(const DashboardState().hasDisplayableFeed, isFalse);
    });
    test('displayFeed prefers live feed', () {
      final s = DashboardState(feed: _tFeed, previousFeed: _makeFeedWithDecks());
      expect(s.displayFeed, equals(_tFeed));
    });
    test('displayFeed falls back to previousFeed', () {
      final feedWithDecks = _makeFeedWithDecks();
      final s = DashboardState(previousFeed: feedWithDecks);
      expect(s.displayFeed, equals(feedWithDecks));
    });
    test('isAnalyticsReady is true only on fullyLoaded', () {
      expect(
        const DashboardState(
                sectionStatus: DashboardSectionStatus.fullyLoaded)
            .isAnalyticsReady,
        isTrue,
      );
      expect(
        const DashboardState(
                sectionStatus: DashboardSectionStatus.revalidating)
            .isAnalyticsReady,
        isFalse,
      );
    });
  });
}
