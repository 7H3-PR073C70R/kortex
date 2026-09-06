import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_list_tile_card.dart';
import 'package:kortex/src/features/decks/presentation/widgets/latex_card_content_viewer.dart';
import 'package:kortex/src/features/decks/presentation/widgets/sm2_rating_action_bar.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_progress_top_bar.dart';
import 'package:kortex/src/features/flashcards/domain/logic/fsrs_scheduler.dart';
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
  });
}
