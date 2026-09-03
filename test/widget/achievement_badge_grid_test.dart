import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/achievement_badge_grid.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('AchievementBadgeGrid Widget Test Suite', () {
    testWidgets('renders all achievement badges with title and status', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const AchievementBadgeGrid(),
        ),
      );

      expect(find.text('Earned Badges & Milestones'), findsOneWidget);

      // Verify badges
      expect(find.text('Night Owl'), findsOneWidget);
      expect(find.text('Century Club'), findsOneWidget);
      expect(find.text('Streak Master'), findsOneWidget);
      expect(find.text('Master Scholar'), findsOneWidget);

      // Verify unlocked and progress indicators
      expect(find.text('COMPLETED'), findsNWidgets(2));
      expect(find.text('9 / 14'), findsOneWidget); // Streak Master
      expect(find.text('32 / 50'), findsOneWidget); // Master Scholar
    });
  });
}
