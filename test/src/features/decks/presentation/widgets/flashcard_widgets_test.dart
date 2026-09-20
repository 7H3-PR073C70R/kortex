import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_list_tile_card.dart';
import 'package:kortex/src/features/decks/presentation/widgets/fsrs_rating_action_bar.dart';
import 'package:kortex/src/features/decks/presentation/widgets/latex_card_content_viewer.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_progress_top_bar.dart';
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Decks Presentation Widgets', () {
    testWidgets('LatexCardContentViewer renders primary text', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const LatexCardContentViewer(
            text: 'What is differential form of Faraday Law?',
          ),
        ),
      );

      expect(
        find.text('What is differential form of Faraday Law?'),
        findsOneWidget,
      );
    });

    testWidgets('LatexCardContentViewer parses and renders options distinctly', (
      tester,
    ) async {
      const cardText = '''
The part labelled III is the

Options:
• A. hook
• B. genital pore
• C. mouth
• D. sucker
''';

      await tester.pumpWidget(
        _buildTestApp(
          const LatexCardContentViewer(
            text: cardText,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Question prompt should be present
      expect(find.text('The part labelled III is the'), findsOneWidget);
      // Options header badge should be rendered
      expect(find.text('OPTIONS'), findsOneWidget);
      // Option badges should be rendered
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      // Option contents should be rendered
      expect(find.text('hook'), findsOneWidget);
      expect(find.text('genital pore'), findsOneWidget);
      expect(find.text('mouth'), findsOneWidget);
      expect(find.text('sucker'), findsOneWidget);
    });

    testWidgets('LatexCardContentViewer renders LaTeX formula before options', (
      tester,
    ) async {
      const cardText = '''
Find the derivative of the expression:

**Options:**
• A. 2x
• B. x^2
• C. 1
• D. 0
''';

      await tester.pumpWidget(
        _buildTestApp(
          const LatexCardContentViewer(
            text: cardText,
            latexFormula: 'f(x) = x^2 + 5',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Find the derivative of the expression:'),
        findsOneWidget,
      );
      expect(find.text('OPTIONS'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
    });

    testWidgets(r'LatexCardContentViewer cleans $$ delimiters from formula and renders successfully', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const LatexCardContentViewer(
            text: 'Formula Test',
            latexFormula: r'$$\text{RR} = \frac{\text{Potential Reward}}{\text{Potential Risk}}$$',
            isBackFace: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Formula container is rendered and no raw $$ delimiter is leaked
      expect(find.text('Formula Test'), findsOneWidget);
      expect(find.textContaining(r'$$'), findsNothing);
    });

    testWidgets(r'LatexCardContentViewer gracefully renders truncated or unclosed LaTeX without raw $$', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const LatexCardContentViewer(
            text: 'Truncated Formula Test',
            latexFormula: r'$$\text{RR} = \frac{\text{Potential Reward}}{\text{Pote',
            isBackFace: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Truncated Formula Test'), findsOneWidget);
      expect(find.textContaining(r'$$'), findsNothing);
    });

    testWidgets('LatexCardContentViewer breaks run-on checklist (1)-(8) into multi-line items', (
      tester,
    ) async {
      const checklistText =
          'Verify: (1) price is above or below the 50/200 EMA in the intended direction; '
          '(2) clear supporting structure exists; '
          '(3) the setup is continuation-based; '
          '(4) the M15 high or low is ideally inside an imbalance or is a session extreme; '
          '(5) price swept the level and closed with weakness; '
          '(6) the rectangle is drawn from the trigger candle’s close to its high or low; '
          '(7) the stop loss is beyond the relevant extreme; and '
          '(8) take profit targets at least 3:1 reward-to-risk or the next strong M15 key level.';

      await tester.pumpWidget(
        _buildTestApp(
          const LatexCardContentViewer(
            text: checklistText,
            isBackFace: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that items are broken into distinct RichText elements
      final richTexts = tester.widgetList<RichText>(find.byType(RichText)).toList();
      expect(richTexts.length, greaterThanOrEqualTo(8));
      expect(find.textContaining('(1)'), findsOneWidget);
      expect(find.textContaining('(8)'), findsOneWidget);
    });

    testWidgets('StudyProgressTopBar renders card progress and timer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          StudyProgressTopBar(
            currentIndex: 1,
            totalCards: 5,
            elapsedTimeFormatted: '01:45',
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('01:45'), findsOneWidget);
    });

    testWidgets('FsrsRatingActionBar invokes correct rating callback', (
      tester,
    ) async {
      FsrsRating? ratedRating;

      await tester.pumpWidget(
        _buildTestApp(
          FsrsRatingActionBar(
            onRateRating: (rating) {
              ratedRating = rating;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap "Good" button (FsrsRating.good)
      final goodFinder = find.byKey(const ValueKey('fsrs_rating_good'));
      expect(goodFinder, findsOneWidget);

      await tester.tap(goodFinder);
      expect(ratedRating, FsrsRating.good);
    });

    testWidgets('DeckListTileCard displays deck title and subject', (
      tester,
    ) async {
      const deck = DeckEntity(
        id: 'd1',
        title: 'Maxwell Equations',
        subject: 'Electromagnetism',
        totalCards: 15,
        dueCards: 6,
        masteryRate: 0.8,
        category: 'Physics',
      );

      await tester.pumpWidget(
        _buildTestApp(
          const DeckListTileCard(deck: deck),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maxwell Equations'), findsOneWidget);
      expect(find.text('ELECTROMAGNETISM'), findsOneWidget);
    });

    testWidgets(
      'DeckListTileCard enriches canonical deck with descriptive title and subject',
      (tester) async {
        const canonicalDeck = DeckEntity(
          id: 'canonical_deck_waec_animalhusbandry_2024',
          title: 'Canonical Deck',
          subject: 'General',
          totalCards: 21,
          dueCards: 21,
          masteryRate: 0,
          category: 'GENERAL',
        );

        await tester.pumpWidget(
          _buildTestApp(
            const DeckListTileCard(deck: canonicalDeck),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('WAEC 2024 Animal Husbandry Past Questions'),
          findsOneWidget,
        );
        expect(find.text('ANIMAL HUSBANDRY'), findsOneWidget);
      },
    );
  });
}
