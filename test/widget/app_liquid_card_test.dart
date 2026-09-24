import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/widgets/app_liquid_card.dart';

Widget createTestApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('AppLiquidCard Widget Test Suite', () {
    testWidgets('renders child content properly on Android target platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        createTestApp(
          const AppLiquidCard(
            child: Text('Card Content Android'),
          ),
        ),
      );

      expect(find.text('Card Content Android'), findsOneWidget);
      expect(find.byType(AppLiquidCard), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders child content properly on iOS target platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        createTestApp(
          const AppLiquidCard(
            child: Text('Card Content iOS'),
          ),
        ),
      );

      expect(find.text('Card Content iOS'), findsOneWidget);
      expect(find.byType(AppLiquidCard), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('observes light theme colors without errors', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        createTestApp(
          const AppLiquidCard(
            child: Text('Light Mode Card'),
          ),
          theme: AppTheme.lightTheme,
        ),
      );

      expect(find.text('Light Mode Card'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
