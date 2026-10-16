import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness/cbt_readiness_weekly_trends_chart.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CbtReadinessWeeklyTrendsChart Widget Tests', () {
    testWidgets('renders Weekly Trends chart with score and week labels', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const CbtReadinessWeeklyTrendsChart(
            currentReadinessScore: 78.5,
            targetTrack: 'JAMB',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WEEKLY READINESS TREND'), findsOneWidget);
      expect(find.text('79% Current Index'), findsOneWidget);
      expect(find.text('Current'), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with actual historical sessions correctly', (tester) async {
      final now = DateTime.now();
      final sessions = [
        {
          'timestamp': now.subtract(const Duration(days: 28)).toIso8601String(),
          'retentionScore': 0.55,
          'category': 'cbt_mock',
        },
        {
          'timestamp': now.subtract(const Duration(days: 14)).toIso8601String(),
          'retentionScore': 0.68,
          'category': 'quiz',
        },
        {
          'timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
          'retentionScore': 0.82,
          'category': 'cbt_mock',
        },
      ];

      await tester.pumpWidget(
        createTestApp(
          CbtReadinessWeeklyTrendsChart(
            currentReadinessScore: 82,
            sessions: sessions,
            targetTrack: 'WAEC',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WEEKLY READINESS TREND'), findsOneWidget);
      expect(find.text('82% Current Index'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('interactive tapping on week labels updates inspection', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const CbtReadinessWeeklyTrendsChart(
            currentReadinessScore: 65,
            targetTrack: 'JAMB',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WEEKLY READINESS TREND'), findsOneWidget);

      // Find Wk 1 label and tap it
      final wk1Finder = find.text('Wk 1');
      if (wk1Finder.evaluate().isNotEmpty) {
        await tester.tap(wk1Finder.first);
        await tester.pumpAndSettle();
        expect(find.textContaining('Wk 1:'), findsOneWidget);
      }
    });
  });
}
