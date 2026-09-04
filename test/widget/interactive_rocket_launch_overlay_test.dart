import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/interactive_rocket_launch_overlay.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  group('InteractiveRocketLaunchOverlay Widget Test Suite', () {
    Widget createTestApp(Widget child) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders telemetry HUD, handles tap turbo boost and skip', (
      tester,
    ) async {
      var completed = false;

      await tester.pumpWidget(
        createTestApp(
          InteractiveRocketLaunchOverlay(
            onLaunchComplete: () {
              completed = true;
            },
          ),
        ),
      );

      await tester.pump();

      // Telemetry HUD items exist
      expect(find.textContaining('Mach'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap screen to trigger turbo boost
      await tester.tap(find.byType(InteractiveRocketLaunchOverlay));
      await tester.pump();

      // Pan/drag to steer
      await tester.drag(
        find.byType(InteractiveRocketLaunchOverlay),
        const Offset(-40, -60),
      );
      await tester.pump();

      // Tapping Skip completes the sequence immediately
      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(completed, isTrue);
    });
  });
}
