import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/presentation/widgets/sprint_milestone_banner.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SprintMilestoneBanner', () {
    testWidgets('renders inline and never blocks widgets behind it', (
      tester,
    ) async {
      var backgroundTaps = 0;

      await tester.pumpWidget(
        _buildTestApp(
          Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton(
                    onPressed: () => backgroundTaps++,
                    child: const Text('Reveal answer'),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: SprintMilestoneBanner(
                  cardsCrushed: 10,
                  onFinishSprint: () {},
                  onDismiss: () {},
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('10 cards down — keep rolling'), findsOneWidget);

      // No dialog route pushed: the study surface below stays interactive.
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.text('Reveal answer'));
      await tester.pump();
      expect(backgroundTaps, 1);

      // Let the banner auto-complete, then unmount to release the flame
      // pulse ticker before the test ends.
      await tester.pump(const Duration(milliseconds: 4200));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('finish action fires and dismissal is time-driven, not modal', (
      tester,
    ) async {
      var finishTaps = 0;
      var dismissals = 0;

      await tester.pumpWidget(
        _buildTestApp(
          Padding(
            padding: const EdgeInsets.all(8),
            child: SprintMilestoneBanner(
              cardsCrushed: 20,
              onFinishSprint: () => finishTaps++,
              onDismiss: () => dismissals++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Finish sprint'));
      await tester.pump();
      expect(finishTaps, 1);
      expect(dismissals, 0);

      // It fades itself away after its lifetime and reports back so the
      // parent can remove it — no user action required.
      await tester.pump(const Duration(milliseconds: 4200));
      expect(dismissals, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('a newer milestone restarts the strip without remounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          Padding(
            padding: const EdgeInsets.all(8),
            child: SprintMilestoneBanner(
              cardsCrushed: 10,
              onFinishSprint: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pumpWidget(
        _buildTestApp(
          Padding(
            padding: const EdgeInsets.all(8),
            child: SprintMilestoneBanner(
              cardsCrushed: 20,
              onFinishSprint: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('10 cards down — keep rolling'), findsNothing);
      expect(find.text('20 cards down — keep rolling'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 4200));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
