import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/shared/export/services/notion_csv_formatter.dart';

void main() {
  group('NotionCsvFormatter Test Suite', () {
    const formatter = NotionCsvFormatter();

    const tDeck = DeckEntity(
      id: 'deck-chem',
      title: 'Organic Chemistry, Part 1',
      subject: 'Chemistry',
      category: 'STEM',
      totalCards: 1,
      dueCards: 0,
      masteryRate: 0.9,
      cards: [
        FlashcardEntity(
          id: 'c1',
          deckId: 'deck-chem',
          front: 'What is SN2 reaction mechanism?',
          back: 'Bimolecular nucleophilic substitution with inversion.',
        ),
      ],
    );

    test(
        'generates valid Notion CSV format with quotes for fields with commas',
        () {
      final csv = formatter.generateNotionCsv(tDeck);

      expect(csv, contains('Name,Front,Back,Subject,Deck,Category'));
      expect(csv, contains('"Organic Chemistry, Part 1 - Card 1"'));
      expect(csv, contains('What is SN2 reaction mechanism?'));
      expect(
        csv,
        contains('Bimolecular nucleophilic substitution with inversion.'),
      );
      expect(csv, contains('"Organic Chemistry, Part 1"'));
    });
  });
}
