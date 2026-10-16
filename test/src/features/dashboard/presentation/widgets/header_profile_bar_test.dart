import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('HeaderProfileBar Sub-widgets Test Suite', () {
    const analytics = AnalyticsSummaryEntity(
      currentStreakDays: 7,
      longestStreakDays: 14,
      totalCardsMastered: 80,
      weeklyMinutesStudied: 120,
      overallRetentionRate: 0.89,
      academicRank: 'Neural Adept',
      xpPoints: 3400,
      heatMapData: [],
    );

    testWidgets('HeaderIconButton renders icon, tooltip, and badge count',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          HeaderIconButton(
            icon: Icons.notifications_rounded,
            color: Colors.amber,
            tooltip: 'Notifications Alert',
            badgeCount: 5,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.byType(HeaderIconButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('UncalibratedProfileBanner renders prompt text and button',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const UncalibratedProfileBanner(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Calibrate Your Neural Workspace'), findsOneWidget);
      expect(find.text('Calibrate'), findsOneWidget);
    });

    testWidgets('showRankProgressSheet opens bottom sheet with level and XP',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showRankProgressSheet(
                  context,
                  analytics,
                  null,
                ),
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Neural Adept'), findsOneWidget);
      expect(find.text('LEVEL 1 SCHOLAR'), findsOneWidget);
      expect(find.text('3400 / 5000 XP'), findsOneWidget);
      expect(find.text('Next Rank: Master Scholar'), findsOneWidget);
    });
  });
}
