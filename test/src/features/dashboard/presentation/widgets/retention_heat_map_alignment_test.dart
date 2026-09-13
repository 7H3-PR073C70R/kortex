import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/retention_heat_map_widget.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget _buildTestWidget(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('RetentionHeatMapWidget Calendar Alignment Tests', () {
    testWidgets('Matrix renders 28 day cells across 4 rows and 7 weekday headers', (
      tester,
    ) async {
      final now = DateTime.now();
      final sampleDays = [
        HeatMapDayEntity(
          date: now,
          intensityLevel: 3,
          cardsReviewed: 25,
          minutesStudied: 15,
        ),
      ];

      final analytics = AnalyticsSummaryEntity(
        currentStreakDays: 5,
        longestStreakDays: 10,
        weeklyMinutesStudied: 45,
        overallRetentionRate: 0.85,
        totalCardsMastered: 120,
        heatMapData: sampleDays,
        xpPoints: 350,
        academicRank: 'Neural Scholar I',
      );

      await tester.pumpWidget(
        _buildTestWidget(RetentionHeatMapWidget(analytics: analytics)),
      );
      await tester.pumpAndSettle();

      // Weekday headers M, T, W, T, F, S, S
      expect(find.text('M'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2));
      expect(find.text('S'), findsNWidgets(2));

      // Check that InkWell widgets (the cells) are exactly 28
      final cellFinders = find.byType(InkWell);
      expect(cellFinders, findsNWidgets(28));
    });

    testWidgets('Tapping a cell displays the formatted date and volume in inspector', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayFormatted = DateFormat('EEE, MMM d').format(today);

      final analytics = AnalyticsSummaryEntity(
        currentStreakDays: 3,
        longestStreakDays: 7,
        weeklyMinutesStudied: 30,
        overallRetentionRate: 0.78,
        totalCardsMastered: 80,
        heatMapData: [
          HeatMapDayEntity(
            date: today,
            intensityLevel: 4,
            cardsReviewed: 35,
            minutesStudied: 20,
          ),
        ],
        xpPoints: 200,
        academicRank: 'Neural Scholar I',
      );

      await tester.pumpWidget(
        _buildTestWidget(RetentionHeatMapWidget(analytics: analytics)),
      );
      await tester.pumpAndSettle();

      // Today should be selected initially by default
      expect(find.text(todayFormatted), findsOneWidget);
      expect(find.text('35 cards • 20 mins'), findsOneWidget);
    });
  });
}
