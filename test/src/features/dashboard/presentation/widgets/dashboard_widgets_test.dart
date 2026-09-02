import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/exam_countdown_widget.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/quick_action_speed_dial.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/retention_heat_map_widget.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/sm2_review_deck_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/syllabot_quick_prompt_bar.dart';

import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('Dashboard Presentation Widgets Test Suite', () {
    testWidgets('HeaderProfileBar renders user greeting, rank, and streak', (
      tester,
    ) async {
      const analytics = AnalyticsSummaryEntity(
        currentStreakDays: 12,
        longestStreakDays: 20,
        totalCardsMastered: 150,
        weeklyMinutesStudied: 180,
        overallRetentionRate: 0.92,
        academicRank: 'Neural Scholar',
        xpPoints: 3400,
        heatMapData: [],
      );

      await tester.pumpWidget(
        createTestApp(
          const HeaderProfileBar(
            analytics: analytics,
            isProfileUncalibrated: true,
            userName: 'Alexander',
          ),
        ),
      );

      expect(find.text('Hey, Alexander 👋'), findsOneWidget);
      expect(find.text('Neural Scholar'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Calibrate Your Neural Workspace'), findsOneWidget);
    });

    testWidgets('Sm2ReviewDeckCard renders deck details and due badge', (
      tester,
    ) async {
      final deck = StudyDeckEntity(
        id: 'deck_1',
        title: 'Fourier Series & Boundary Values',
        subject: 'Engineering Math',
        totalCards: 30,
        dueCards: 8,
        retentionRate: 0.85,
        lastReviewed: DateTime.now(),
        category: 'STEM',
      );

      await tester.pumpWidget(
        createTestApp(
          Sm2ReviewDeckCard(deck: deck),
        ),
      );

      expect(find.text('ENGINEERING MATH'), findsOneWidget);
      expect(find.text('Fourier Series & Boundary Values'), findsOneWidget);
      expect(find.text('8 DUE'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
    });

    testWidgets('ExamCountdownWidget renders countdown and simulator action', (
      tester,
    ) async {
      final countdown = ExamCountdownEntity(
        id: 'utme_2025',
        examName: 'JAMB / UTME Examination',
        targetDate: DateTime.now().add(const Duration(days: 45, hours: 2)),
        syllabusProgress: 0.75,
        subjectTrack: 'Mathematics, Physics, Chemistry',
        totalMockPapersAvailable: 25,
        completedMocksCount: 10,
        badgeTitle: 'HIGH YIELD PREP',
      );

      await tester.pumpWidget(
        createTestApp(
          ExamCountdownWidget(countdown: countdown),
        ),
      );

      expect(find.text('HIGH YIELD PREP'), findsOneWidget);
      expect(find.textContaining('DAYS LEFT'), findsOneWidget);
      expect(find.text('JAMB / UTME Examination'), findsOneWidget);
      expect(find.text('75% complete'), findsOneWidget);
      expect(find.textContaining('Launch Mock Simulator'), findsOneWidget);
    });

    testWidgets('SyllabotQuickPromptBar renders prompt and daily insight', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const SyllabotQuickPromptBar(
            insightText: 'Review PDE separation of variables before mock exam!',
          ),
        ),
      );

      expect(
        find.text('Review PDE separation of variables before mock exam!'),
        findsOneWidget,
      );
      expect(
        find.byType(TextField),
        findsOneWidget,
      );
    });

    testWidgets('RetentionHeatMapWidget renders stats and streak matrix', (
      tester,
    ) async {
      const analytics = AnalyticsSummaryEntity(
        currentStreakDays: 14,
        longestStreakDays: 28,
        totalCardsMastered: 240,
        weeklyMinutesStudied: 320,
        overallRetentionRate: 0.89,
        academicRank: 'Grandmaster Scholar',
        xpPoints: 5600,
        heatMapData: [],
      );

      await tester.pumpWidget(
        createTestApp(
          const RetentionHeatMapWidget(analytics: analytics),
        ),
      );

      expect(find.text('Retention & Study Matrix'), findsOneWidget);
      expect(find.text('89%'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
      expect(find.text('320m'), findsOneWidget);
    });

    testWidgets('QuickActionSpeedDial renders all primary study actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const QuickActionSpeedDial(),
        ),
      );

      expect(find.text('Upload Notes'), findsOneWidget);
      expect(find.text('Q-Bank'), findsOneWidget);
      expect(find.text('New Deck'), findsOneWidget);
    });
  });
}
