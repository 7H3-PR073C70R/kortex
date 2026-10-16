import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness/day_one_diagnostic_banner.dart';
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

  group('DayOneDiagnosticBanner Widget Tests', () {
    testWidgets('renders Day-One banner with track, badges and CTA', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const DayOneDiagnosticBanner(
            targetTrack: 'JAMB',
            registeredSubjectNames: ['English', 'Mathematics', 'Physics', 'Chemistry'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DAY-ONE DIAGNOSTIC'), findsOneWidget);
      expect(find.text('Calibrate Your JAMB Readiness'), findsOneWidget);
      expect(find.text('10 Mins'), findsOneWidget);
      expect(find.text('15 Questions'), findsOneWidget);
      expect(find.text('Instant Projected Score'), findsOneWidget);
      expect(find.text('Start 10-Minute Diagnostic'), findsOneWidget);
    });

    testWidgets('invokes onStartDiagnostic when CTA is tapped', (tester) async {
      var started = false;

      await tester.pumpWidget(
        createTestApp(
          DayOneDiagnosticBanner(
            targetTrack: 'WAEC',
            onStartDiagnostic: () async {
              started = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.text('Start 10-Minute Diagnostic');
      expect(ctaFinder, findsOneWidget);

      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(started, isTrue);
    });

    testWidgets('invokes onDismiss when close button is tapped', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        createTestApp(
          DayOneDiagnosticBanner(
            targetTrack: 'JAMB',
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final closeBtnFinder = find.byIcon(Icons.close_rounded);
      expect(closeBtnFinder, findsOneWidget);

      await tester.tap(closeBtnFinder);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('formats fallback title when track is null', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const DayOneDiagnosticBanner(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calibrate Your CBT Track Readiness'), findsOneWidget);
    });
  });
}
