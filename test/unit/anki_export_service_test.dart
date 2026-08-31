import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/shared/export/services/anki_export_service.dart';

void main() {
  group('AnkiExportService Test Suite', () {
    const service = AnkiExportService();

    const tDeck = DeckEntity(
      id: 'deck-thermo',
      title: 'Thermodynamics Master',
      subject: 'Physics',
      category: 'STEM',
      totalCards: 2,
      dueCards: 1,
      masteryRate: 0.85,
      cards: [
        FlashcardEntity(
          id: 'c1',
          deckId: 'deck-thermo',
          front: r'What is $\Delta G$ at equilibrium?',
          back: r'$$\Delta G = 0$$',
        ),
        FlashcardEntity(
          id: 'c2',
          deckId: 'deck-thermo',
          front: 'What is 1st Law of Thermodynamics?',
          back: r'$\Delta U = Q - W$',
        ),
      ],
    );

    test('generates valid Anki tab-delimited text with math tags', () {
      final ankiText = service.generateAnkiCsv(tDeck);

      expect(ankiText, contains('#separator:tab'));
      expect(ankiText, contains('#html:true'));
      expect(ankiText, contains('#deck:Thermodynamics Master'));

      // Check inline LaTeX conversion
      expect(ankiText, contains(r'[$]\Delta G[/$]'));
      // Check display LaTeX conversion
      expect(ankiText, contains(r'[$$]\Delta G = 0[/$$]'));
      expect(ankiText, contains(r'[$]\Delta U = Q - W[/$]'));
    });

    test('generateAnkiExportBytes returns non-empty byte list', () {
      final bytes = service.generateAnkiExportBytes(tDeck);
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
