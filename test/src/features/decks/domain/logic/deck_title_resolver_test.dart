import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/domain/logic/deck_title_resolver.dart';

void main() {
  group('DeckTitleResolver', () {
    test('resolves canonical WAEC Animal Husbandry deck correctly', () {
      const deckId = 'canonical_deck_waec_animalhusbandry_2024';
      final title = DeckTitleResolver.resolveTitle(
        deckId: deckId,
        currentTitle: 'Study Deck',
      );
      final subject = DeckTitleResolver.resolveSubject(
        deckId: deckId,
        currentSubject: 'General',
      );
      final category = DeckTitleResolver.resolveCategory(
        deckId: deckId,
        currentCategory: 'General',
      );

      expect(title, 'WAEC 2024 Animal Husbandry Past Questions');
      expect(subject, 'Animal Husbandry');
      expect(category, 'WAEC');
    });

    test('resolves canonical JAMB Biology deck correctly', () {
      const deckId = 'canonical_deck_jamb_biology_2023';
      final title = DeckTitleResolver.resolveTitle(
        deckId: deckId,
        currentTitle: 'Canonical Deck',
      );
      final subject = DeckTitleResolver.resolveSubject(
        deckId: deckId,
      );
      final category = DeckTitleResolver.resolveCategory(
        deckId: deckId,
      );

      expect(title, 'JAMB 2023 Biology Past Questions');
      expect(subject, 'Biology');
      expect(category, 'JAMB');
    });

    test('resolves canonical NECO General Mathematics correctly', () {
      const deckId = 'canonical_deck_neco_generalmathematics_2022';
      final title = DeckTitleResolver.resolveTitle(
        deckId: deckId,
        currentTitle: 'Study Deck',
      );
      expect(title, 'NECO 2022 General Mathematics Past Questions');
    });

    test('preserves user custom titles when non-generic', () {
      const customTitle = 'My Special Virology Flashcards';
      final title = DeckTitleResolver.resolveTitle(
        deckId: 'deck-123-uuid',
        currentTitle: customTitle,
      );
      expect(title, customTitle);
    });

    test('enriches generic DeckModel with descriptive titles and subjects', () {
      const genericDeck = DeckModel(
        id: 'canonical_deck_waec_useofenglish_2024',
        title: 'Study Deck',
        subject: 'General',
        category: 'General',
        totalCards: 25,
        dueCards: 25,
        masteryRate: 0,
      );

      final enriched = DeckTitleResolver.enrichDeckModel(genericDeck);
      expect(enriched.title, 'WAEC 2024 Use of English Past Questions');
      expect(enriched.subject, 'Use of English');
      expect(enriched.category, 'WAEC');
    });
  });
}
