import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/streak_shield_indicator.dart';
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
  group('StreakShieldIndicator Widget Test Suite', () {
    testWidgets('renders active streak days and shield button when unequipped',
        (tester) async {
      var purchaseTapped = false;

      await tester.pumpWidget(
        createTestApp(
          StreakShieldIndicator(
            streakDays: 7,
            hasStreakFreeze: false,
            userXp: 450,
            onPurchaseFreeze: () {
              purchaseTapped = true;
            },
          ),
        ),
      );

      expect(find.text('7 Days Streak'), findsOneWidget);
      expect(find.text('Equip Streak Shield (200 XP)'), findsOneWidget);

      await tester.tap(find.text('Equip Streak Shield (200 XP)'));
      await tester.pump();
      expect(purchaseTapped, isTrue);
    });

    testWidgets('renders active shield banner when equipped', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const StreakShieldIndicator(
            streakDays: 12,
            hasStreakFreeze: true,
            userXp: 300,
          ),
        ),
      );

      expect(find.text('12 Days Streak'), findsOneWidget);
      expect(find.text('SHIELD ACTIVE'), findsOneWidget);
      expect(
        find.text('Your daily streak is protected against 1 missed day.'),
        findsOneWidget,
      );
      expect(find.text('Equip Streak Shield (200 XP)'), findsNothing);
    });
  });
}
