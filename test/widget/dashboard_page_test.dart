import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/daily_recall_status_banner.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_layouts.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_quick_actions_grid.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard/dashboard_shimmer_loading.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/dashboard_header_profile_bar.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class MockCramPlannerCubit extends MockCubit<CramPlannerState>
    implements CramPlannerCubit {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  group('DashboardPage Widget Tests', () {
    late MockAuthBloc mockAuthBloc;
    late MockDashboardBloc mockDashboardBloc;
    late MockCramPlannerCubit mockCramPlannerCubit;
    late MockLocalStorageService mockLocalStorageService;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
      mockDashboardBloc = MockDashboardBloc();
      mockCramPlannerCubit = MockCramPlannerCubit();
      mockLocalStorageService = MockLocalStorageService();

      when(() => mockAuthBloc.state).thenReturn(
        const AuthState(
          status: AuthStatus.authenticated,
          userProfile: UserProfileEntity(
            id: 'user_1',
            email: 'student@example.com',
            displayName: 'Alexander The Great',
            targetTrack: 'jamb',
          ),
        ),
      );

      when(() => mockCramPlannerCubit.state).thenReturn(
        const CramPlannerState(),
      );
      when(() => mockCramPlannerCubit.loadExams()).thenAnswer((_) async {});

      when(
        () => mockLocalStorageService.getPreference(
          key: any(named: 'key'),
        ),
      ).thenReturn('false');
      when(
        () => mockLocalStorageService.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => true);
    });

    testWidgets('renders DashboardShimmerLoading on initial loading state', (
      tester,
    ) async {
      when(() => mockDashboardBloc.state).thenReturn(
        const DashboardState(status: DashboardStatus.loading),
      );

      await tester.pumpApp(
        BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: DashboardPage(
            dashboardBloc: mockDashboardBloc,
            cramPlannerCubit: mockCramPlannerCubit,
            localStorageService: mockLocalStorageService,
          ),
        ),
      );

      expect(find.byType(DashboardShimmerLoading), findsOneWidget);
    });

    testWidgets('renders error view with retry button when in error state', (
      tester,
    ) async {
      when(() => mockDashboardBloc.state).thenReturn(
        const DashboardState(
          status: DashboardStatus.error,
          errorMessage: 'Server unavailable',
        ),
      );

      await tester.pumpApp(
        BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: DashboardPage(
            dashboardBloc: mockDashboardBloc,
            cramPlannerCubit: mockCramPlannerCubit,
            localStorageService: mockLocalStorageService,
          ),
        ),
      );

      expect(find.text('Server unavailable'), findsOneWidget);
      expect(find.byType(ShrinkableButton), findsOneWidget);
    });

    testWidgets('renders compact layout and child widgets when loaded', (
      tester,
    ) async {
      const feed = DashboardFeedEntity(
        calibrationProfile: CalibrationProfile(),
        curatedCourses: [],
        dueStudyDecks: [],
        analyticsSummary: AnalyticsSummaryEntity(
          currentStreakDays: 1,
          longestStreakDays: 1,
          weeklyMinutesStudied: 10,
          overallRetentionRate: 0.85,
          totalCardsMastered: 10,
          heatMapData: [],
          xpPoints: 100,
          academicRank: 'Scholar',
        ),
      );

      when(() => mockDashboardBloc.state).thenReturn(
        const DashboardState(
          status: DashboardStatus.loaded,
          feed: feed,
        ),
      );

      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpApp(
        BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: DashboardPage(
            dashboardBloc: mockDashboardBloc,
            cramPlannerCubit: mockCramPlannerCubit,
            localStorageService: mockLocalStorageService,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(DashboardCompactLayout), findsOneWidget);
      expect(find.byType(DashboardHeaderProfileBar), findsOneWidget);
      expect(find.byType(DailyRecallStatusBanner), findsOneWidget);
      expect(find.byType(DashboardQuickActionsGrid), findsOneWidget);
    });
  });
}
