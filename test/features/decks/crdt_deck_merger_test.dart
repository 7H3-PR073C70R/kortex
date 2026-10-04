import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/logic/crdt_deck_merger.dart';

void main() {
  group('CrdtDeckMerger FSRS & Content Synchronization Suite', () {
    const merger = CrdtDeckMerger();

    test('reconciles content edits from local and FSRS review state from remote independently', () {
      const localState = CrdtDeckState(
        deckId: 'deck_1',
        cards: {
          'card_101': CrdtCardRecord(
            cardId: 'card_101',
            front: 'Updated Front Text on Mobile',
            back: 'Updated Back Text on Mobile',
            authorId: 'user_mobile',
            timestampMicros: 2000000, // Newer content timestamp
            fsrsStability: 1,
            fsrsDifficulty: 5,
            fsrsReviewTimestampMicros: 1000000,
          ),
        },
      );

      const remoteState = CrdtDeckState(
        deckId: 'deck_1',
        cards: {
          'card_101': CrdtCardRecord(
            cardId: 'card_101',
            front: 'Old Front Text',
            back: 'Old Back Text',
            authorId: 'user_desktop',
            timestampMicros: 1000000, // Older content timestamp
            fsrsStability: 12.5, // Newer FSRS review state
            fsrsDifficulty: 3.2,
            fsrsState: 2,
            fsrsReviewTimestampMicros: 3000000, // Newer review timestamp
          ),
        },
      );

      final merged = merger.merge(localState, remoteState);

      final mergedCard = merged.cards['card_101']!;
      // Content must take newer content edit (from mobile at t=2000000)
      expect(mergedCard.front, equals('Updated Front Text on Mobile'));
      expect(mergedCard.back, equals('Updated Back Text on Mobile'));

      // FSRS state must take newer review parameters (from remote at t=3000000)
      expect(mergedCard.fsrsStability, equals(12.5));
      expect(mergedCard.fsrsDifficulty, equals(3.2));
      expect(mergedCard.fsrsState, equals(2));
      expect(mergedCard.fsrsReviewTimestampMicros, equals(3000000));
    });

    test('preserves tombstone deletion when tombstone timestamp is newer', () {
      const localState = CrdtDeckState(
        deckId: 'deck_1',
        cards: {
          'card_101': CrdtCardRecord(
            cardId: 'card_101',
            front: 'Card Front',
            back: 'Card Back',
            authorId: 'user_1',
            timestampMicros: 3000000,
            isDeleted: true,
          ),
        },
      );

      const remoteState = CrdtDeckState(
        deckId: 'deck_1',
        cards: {
          'card_101': CrdtCardRecord(
            cardId: 'card_101',
            front: 'Card Front',
            back: 'Card Back',
            authorId: 'user_2',
            timestampMicros: 2000000,
          ),
        },
      );

      final merged = merger.merge(localState, remoteState);
      expect(merged.cards['card_101']!.isDeleted, isTrue);

      final entity = merger.toDeckEntity(
        merged,
        title: 'Test Deck',
        subject: 'Bio',
        category: 'Science',
      );
      expect(entity.totalCards, equals(0));
    });
  });
}
