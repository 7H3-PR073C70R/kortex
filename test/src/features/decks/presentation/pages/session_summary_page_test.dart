import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/presentation/pages/session_summary_page.dart';
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
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSummary(
    WidgetTester tester, {
    required int cardsReviewed,
    required double retentionScore,
    int nextReviewInDays = 0,
    bool disableAnimations = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: SessionSummaryPage(
              deckId: 'deck_summary',
              cardsReviewed: cardsReviewed,
              durationSeconds: 240,
              retentionScore: retentionScore,
              nextReviewInDays: nextReviewInDays,
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // While confetti plays, the package re-arms its animation every
      // frame — a full settle would never finish. Step past the entrance.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('Session summary proportional celebration', () {
    testWidgets('stays calm below the effort threshold — no confetti', (
      tester,
    ) async {
      await pumpSummary(
        tester,
        cardsReviewed: 3,
        retentionScore: 0.6,
      );

      expect(find.byType(ConfettiWidget), findsNothing);
    });

    testWidgets('confetti is earned once enough cards are reviewed', (
      tester,
    ) async {
      await pumpSummary(
        tester,
        cardsReviewed: 12,
        retentionScore: 0.5,
        settle: false,
      );

      expect(find.byType(ConfettiWidget), findsOneWidget);

      // Unmount so the playing confetti controller releases its ticker.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('high retention alone also earns the celebration', (
      tester,
    ) async {
      await pumpSummary(
        tester,
        cardsReviewed: 4,
        retentionScore: 0.95,
        settle: false,
      );

      expect(find.byType(ConfettiWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('reduced motion suppresses confetti even past the threshold', (
      tester,
    ) async {
      await pumpSummary(
        tester,
        cardsReviewed: 20,
        retentionScore: 0.98,
        disableAnimations: true,
      );

      expect(find.byType(ConfettiWidget), findsNothing);
    });

    testWidgets('forward-looking line appears only when the data exists', (
      tester,
    ) async {
      await pumpSummary(
        tester,
        cardsReviewed: 2,
        retentionScore: 0.5,
        nextReviewInDays: 3,
      );
      expect(
        find.text('Next review batch in about 3 days'),
        findsOneWidget,
      );

      await pumpSummary(tester, cardsReviewed: 2, retentionScore: 0.5);
      expect(
        find.textContaining('Next review batch'),
        findsNothing,
      );
    });
  });
}
