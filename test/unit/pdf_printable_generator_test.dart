import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/shared/export/services/pdf_printable_generator.dart';

void main() {
  group('PdfPrintableGenerator Test Suite', () {
    const generator = PdfPrintableGenerator();

    final tCards = List.generate(
      10,
      (i) => FlashcardEntity(
        id: 'card-$i',
        deckId: 'deck-1',
        front: 'Question $i: What is Law of Conservation of Energy?',
        back: 'Answer $i: Energy cannot be created or destroyed.',
      ),
    );

    final tDeck = DeckEntity(
      id: 'deck-physics',
      title: 'Physics Core Principles',
      subject: 'Physics',
      category: 'STEM',
      totalCards: 10,
      dueCards: 2,
      masteryRate: 0.8,
      cards: tCards,
    );

    test('generates valid printable PDF byte stream', () async {
      final pdfBytes = await generator.generatePrintableDeckPdf(tDeck);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });
}
