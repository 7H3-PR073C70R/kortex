import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/pages/all_curated_courses_page.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/all_curated_courses/course_detailed_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/all_curated_courses/curated_courses_metrics_banner.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/pump_app.dart';

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class MockDecksBloc extends MockBloc<DecksEvent, DecksState>
    implements DecksBloc {}

void main() {
  group('AllCuratedCoursesPage Widget Tests', () {
    late MockDashboardBloc mockDashboardBloc;
    late MockDecksBloc mockDecksBloc;

    const testCourses = [
      CuratedCourseEntity(
        id: 'course_1',
        courseCode: 'MTH 301',
        title: 'Abstract Algebra',
        department: 'Mathematics',
        totalMaterials: 5,
        hasActivePastPapers: true,
        iconName: 'calculate',
        colorHex: '#6366F1',
      ),
      CuratedCourseEntity(
        id: 'course_2',
        courseCode: 'PHY 201',
        title: 'Classical Mechanics',
        department: 'Physics',
        totalMaterials: 8,
        hasActivePastPapers: false,
        iconName: 'science',
        colorHex: '#10B981',
      ),
    ];

    final testDecks = <DeckEntity>[
      const DeckEntity(
        id: 'deck_1',
        title: 'Algebra Flashcards',
        subject: 'Abstract Algebra',
        courseId: 'course_1',
        courseCode: 'MTH 301',
        totalCards: 20,
        dueCards: 5,
        masteryRate: 0.75,
        category: 'Mathematics',
      ),
    ];

    setUp(() {
      mockDashboardBloc = MockDashboardBloc();
      mockDecksBloc = MockDecksBloc();

      when(() => mockDashboardBloc.state).thenReturn(
        const DashboardState(
          status: DashboardStatus.loaded,
          feed: DashboardFeedEntity(
            calibrationProfile: CalibrationProfile(),
            analyticsSummary: AnalyticsSummaryEntity(
              currentStreakDays: 5,
              longestStreakDays: 10,
              totalCardsMastered: 150,
              weeklyMinutesStudied: 180,
              overallRetentionRate: 0.88,
              academicRank: 'Scholar',
              xpPoints: 1200,
              heatMapData: [],
            ),
            dueStudyDecks: [],
            curatedCourses: testCourses,
          ),
        ),
      );

      when(() => mockDecksBloc.state).thenReturn(
        DecksState(
          allDecks: testDecks,
        ),
      );
    });

    testWidgets('renders header, metrics banner, and course detailed cards',
        (tester) async {
      await tester.pumpApp(
        AllCuratedCoursesPage(
          dashboardBloc: mockDashboardBloc,
          decksBloc: mockDecksBloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enrolled Curated Courses'), findsOneWidget);
      expect(find.byType(CuratedCoursesMetricsBanner), findsOneWidget);
      expect(find.text('2'), findsWidgets); // 2 active courses
      expect(find.text('1'), findsWidgets); // 1 deck
      expect(find.byType(CourseDetailedCard), findsNWidgets(2));
      expect(find.text('MTH 301'), findsOneWidget);
      expect(find.text('PHY 201'), findsOneWidget);
    });

    testWidgets('filters courses when search query matches code or title',
        (tester) async {
      await tester.pumpApp(
        AllCuratedCoursesPage(
          dashboardBloc: mockDashboardBloc,
          decksBloc: mockDecksBloc,
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Algebra');
      await tester.pumpAndSettle();

      expect(find.text('MTH 301'), findsOneWidget);
      expect(find.text('PHY 201'), findsNothing);
    });

    testWidgets('displays empty state when no courses match filter',
        (tester) async {
      await tester.pumpApp(
        AllCuratedCoursesPage(
          dashboardBloc: mockDashboardBloc,
          decksBloc: mockDecksBloc,
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Nonexistent Course');
      await tester.pumpAndSettle();

      expect(find.text('No courses match your filter'), findsOneWidget);
      expect(find.byType(CourseDetailedCard), findsNothing);
    });
  });
}
