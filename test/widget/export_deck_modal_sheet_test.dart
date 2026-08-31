import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/export/presentation/widgets/export_deck_modal_sheet.dart';

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
  group('ExportDeckModalSheet Widget Test Suite', () {
    const tDeck = DeckEntity(
      id: 'deck-chem-1',
      title: 'General Chemistry 101',
      subject: 'Chemistry',
      category: 'STEM',
      totalCards: 1,
      dueCards: 0,
      masteryRate: 1,
      cards: [
        FlashcardEntity(
          id: 'c1',
          deckId: 'deck-chem-1',
          front: 'What is Avogadro number?',
          back: r'6.022 \times 10^{23} \text{ mol}^{-1}',
        ),
      ],
    );

    testWidgets('renders all 3 export options (Anki, PDF, Notion)',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ExportDeckModalSheet(deck: tDeck),
        ),
      );

      expect(find.text('Export Flashcard Deck'), findsOneWidget);
      expect(find.text('Anki Package (.apkg / .csv)'), findsOneWidget);
      expect(find.text('Printable Double-Sided Sheet (PDF)'), findsOneWidget);
      expect(find.text('Notion Database (CSV)'), findsOneWidget);

      expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);
      expect(find.byIcon(Icons.view_headline_rounded), findsOneWidget);
    });
  });
}
