import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_dashboard_feed_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/quick_start_mock_exam_use_case.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';

class MockDashboardRepository implements DashboardRepository {
  bool shouldFail = false;

  @override
  Future<Either<Failure, DashboardFeedEntity>> getDashboardFeed() async {
    if (shouldFail) {
      return const Left(ServerFailure(message: 'Network Timeout'));
    }

    final dummyFeed = DashboardFeedEntity(
      analyticsSummary: const AnalyticsSummaryEntity(
        currentStreakDays: 7,
        longestStreakDays: 14,
        totalCardsMastered: 80,
        weeklyMinutesStudied: 120,
        overallRetentionRate: 0.90,
        academicRank: 'Neural Scholar',
        xpPoints: 1250,
        heatMapData: [],
      ),
      dueStudyDecks: [
        StudyDeckEntity(
          id: 'deck_1',
          title: 'Laplace Transforms',
          subject: 'Engineering Math',
          totalCards: 20,
          dueCards: 5,
          retentionRate: 0.88,
          lastReviewed: DateTime.now(),
          category: 'STEM',
        ),
      ],
      curatedCourses: const [],
      calibrationProfile: const CalibrationProfile(),
      unreadNotificationCount: 1,
      syllabotDailyInsight: 'Great progress in Calculus!',
    );

    return Right(dummyFeed);
  }

  @override
  Future<Either<Failure, List<StudyDeckEntity>>> getSm2ReviewQueue() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, String>> quickStartMockExam({
    required String examId,
    required String subject,
  }) async {
    if (shouldFail) {
      return const Left(ServerFailure(message: 'Exam start failed'));
    }
    return const Right('mock_session_123');
  }

  @override
  Future<Either<Failure, List<CuratedCourseEntity>>> getCatalogCourses() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, void>> syncUserCourses(
    List<Map<String, dynamic>> courses,
  ) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> autoCurateExamCourses({
    required String examName,
    required List<String> subjects,
  }) async {
    return const Right(null);
  }
}

void main() {
  group('DashboardBloc Test Suite', () {
    late MockDashboardRepository mockRepository;
    late GetDashboardFeedUseCase getDashboardFeedUseCase;
    late QuickStartMockExamUseCase quickStartMockExamUseCase;
    late DashboardBloc bloc;

    setUp(() {
      mockRepository = MockDashboardRepository();
      getDashboardFeedUseCase = GetDashboardFeedUseCase(mockRepository);
      quickStartMockExamUseCase = QuickStartMockExamUseCase(mockRepository);
      bloc = DashboardBloc(
        getDashboardFeedUseCase: getDashboardFeedUseCase,
        quickStartMockExamUseCase: quickStartMockExamUseCase,
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state has status initial', () {
      expect(bloc.state.status, DashboardStatus.initial);
      expect(bloc.state.feed, isNull);
    });

    test('DashboardStarted emits loading then loaded on success', () async {
      final expectedStates = [
        const DashboardState(status: DashboardStatus.loading),
        isA<DashboardState>()
            .having((s) => s.status, 'status', DashboardStatus.loaded)
            .having((s) => s.feed?.dueStudyDecks.length, 'dueStudyDecks', 1),
      ];

      unawaited(expectLater(bloc.stream, emitsInOrder(expectedStates)));
      bloc.add(const DashboardStarted());
    });

    test('DashboardStarted emits loading then error on failure', () async {
      mockRepository.shouldFail = true;

      final expectedStates = [
        const DashboardState(status: DashboardStatus.loading),
        const DashboardState(
          status: DashboardStatus.error,
          errorMessage: 'Network Timeout',
        ),
      ];

      unawaited(expectLater(bloc.stream, emitsInOrder(expectedStates)));
      bloc.add(const DashboardStarted());
    });

    test('DashboardExamStarted triggers mock exam simulation', () async {
      final expectedStates = [
        const DashboardState(isExamLaunching: true),
        const DashboardState(
          launchedExamSessionId: 'mock_session_123',
        ),
      ];

      unawaited(expectLater(bloc.stream, emitsInOrder(expectedStates)));
      bloc.add(
        const DashboardExamStarted(
          examId: 'utme_2024',
          subject: 'Physics',
        ),
      );
    });
  });
}
