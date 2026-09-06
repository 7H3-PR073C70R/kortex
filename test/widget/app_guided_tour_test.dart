import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/widgets/app_guided_tour_overlay.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('WelcomeWalkthroughDialog & Guided Tour Tests', () {
    testWidgets(
      'WelcomeWalkthroughDialog invokes onEnterWorkspace when clicking Enter Workspace on final slide',
      (tester) async {
        var didEnterWorkspace = false;
        var didDismiss = false;

        await tester.pumpWidget(
          createTestApp(
            WelcomeWalkthroughDialog(
              onDismissed: () => didDismiss = true,
              onEnterWorkspace: () => didEnterWorkspace = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Slide 1 is visible
        expect(find.text('Next'), findsOneWidget);

        // Advance to Slide 2
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Advance to Slide 3
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Advance to Slide 4
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Final slide has Enter Workspace
        final enterButton = find.text('Enter Workspace');
        expect(enterButton, findsOneWidget);

        await tester.tap(enterButton);
        await tester.pumpAndSettle();

        expect(didEnterWorkspace, isTrue);
        expect(didDismiss, isTrue);
      },
    );

    testWidgets(
      'AppGuidedTourOverlay renders steps and handles next/previous/finish navigation',
      (tester) async {
        var tourCompleted = false;

        await tester.pumpWidget(
          createTestApp(
            AppGuidedTourOverlay(
              onTourCompleted: () => tourCompleted = true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Step 1: Dashboard
        expect(find.text('Academic Command Center'), findsOneWidget);
        expect(find.text('Next Step'), findsOneWidget);

        // Tap Next Step -> Step 2
        await tester.tap(find.text('Next Step'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Daily Review Queue'), findsOneWidget);
        expect(find.text('Back'), findsOneWidget);

        // Tap Back -> Back to Step 1
        await tester.tap(find.text('Back'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Academic Command Center'), findsOneWidget);

        // Skip Tour
        await tester.tap(find.text('Skip Tour'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(tourCompleted, isTrue);
      },
    );
  });
}
