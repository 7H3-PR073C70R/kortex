import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/pages/nested/analytics_detail_page.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_shimmer_skeleton.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group('AnalyticsDetailPage Widget Tests', () {
    late MockDashboardBloc mockDashboardBloc;

    setUp(() {
      mockDashboardBloc = MockDashboardBloc();
    });

    testWidgets('renders shimmer skeleton when loading without feed', (tester) async {
      when(() => mockDashboardBloc.state).thenReturn(
        const DashboardState(status: DashboardStatus.loading, feed: null),
      );

      await tester.pumpWidget(
        createTestApp(
          AnalyticsDetailPage(
            dashboardBloc: mockDashboardBloc,
          ),
        ),
      );

      expect(find.byType(AnalyticsShimmerSkeleton), findsOneWidget);
    });

    testWidgets('renders KPI cards and retention sections when feed is loaded', (tester) async {
      const feed = DashboardFeedEntity(
        calibrationProfile: CalibrationProfile(
          focus: AcademicFocus.higherEducation,
          isCalibrated: true,
        ),
        analyticsSummary: AnalyticsSummaryEntity(
          currentStreakDays: 5,
          longestStreakDays: 12,
          weeklyMinutesStudied: 150,
          overallRetentionRate: 0.92,
          totalCardsMastered: 84,
          heatMapData: [],
          xpPoints: 750,
          academicRank: 'Neural Scholar II',
        ),
        dueStudyDecks: [],
        curatedCourses: [],
      );

      when(() => mockDashboardBloc.state).thenReturn(
        const DashboardState(
          status: DashboardStatus.loaded,
          feed: feed,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          AnalyticsDetailPage(
            dashboardBloc: mockDashboardBloc,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnalyticsShimmerSkeleton), findsNothing);
      expect(find.text('Retention Index'), findsOneWidget);
      expect(find.text('Cards Mastered'), findsOneWidget);
      expect(find.text('Study Velocity'), findsOneWidget);
      expect(find.text('Study Streak'), findsOneWidget);
    });
  });
}
