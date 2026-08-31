import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/logic/crdt_deck_merger.dart';

void main() {
  group('CrdtDeckMerger LWW-Element-Set Test Suite', () {
    const merger = CrdtDeckMerger();

    test('applyOperation inserts new card or updates newer version', () {
      var state = const CrdtDeckState(deckId: 'deck-101', cards: {});

      const card1 = CrdtCardRecord(
        cardId: 'card-1',
        front: 'Euler Equation',
        back: 'e^{i pi} + 1 = 0',
        authorId: 'user-adeola',
        timestampMicros: 1000,
      );

      state = merger.applyOperation(state, card1);
      expect(state.cards.length, equals(1));
      expect(state.cards['card-1']?.front, equals('Euler Equation'));

      // Older edit should be rejected by LWW
      const olderEdit = CrdtCardRecord(
        cardId: 'card-1',
        front: 'Old Euler Name',
        back: 'old back',
        authorId: 'user-chukwudi',
        timestampMicros: 500,
      );
      state = merger.applyOperation(state, olderEdit);
      expect(state.cards['card-1']?.front, equals('Euler Equation'));

      // Newer edit should win
      const newerEdit = CrdtCardRecord(
        cardId: 'card-1',
        front: 'Euler Identity',
        back: 'e^{i pi} + 1 = 0',
        authorId: 'user-chukwudi',
        timestampMicros: 2000,
      );
      state = merger.applyOperation(state, newerEdit);
      expect(state.cards['card-1']?.front, equals('Euler Identity'));
    });

    test('merge resolves divergent cards deterministically with LWW', () {
      const localState = CrdtDeckState(
        deckId: 'deck-101',
        cards: {
          'card-1': CrdtCardRecord(
            cardId: 'card-1',
            front: 'Local Front A',
            back: 'Back A',
            authorId: 'user-1',
            timestampMicros: 1500,
          ),
          'card-2': CrdtCardRecord(
            cardId: 'card-2',
            front: 'Local Only',
            back: 'Back 2',
            authorId: 'user-1',
            timestampMicros: 1000,
          ),
        },
      );

      const remoteState = CrdtDeckState(
        deckId: 'deck-101',
        cards: {
          'card-1': CrdtCardRecord(
            cardId: 'card-1',
            front: 'Remote Front A (Newer)',
            back: 'Back A',
            authorId: 'user-2',
            timestampMicros: 2500,
          ),
          'card-3': CrdtCardRecord(
            cardId: 'card-3',
            front: 'Remote Only',
            back: 'Back 3',
            authorId: 'user-2',
            timestampMicros: 1200,
          ),
        },
      );

      final merged = merger.merge(localState, remoteState);

      expect(merged.cards.length, equals(3));
      // card-1 should have remote content because 2500 > 1500
      expect(merged.cards['card-1']?.front, equals('Remote Front A (Newer)'));
      // disjoint cards retained
      expect(merged.cards['card-2']?.front, equals('Local Only'));
      expect(merged.cards['card-3']?.front, equals('Remote Only'));
    });

    test('toDeckEntity converts state and excludes deleted tombstones', () {
      const state = CrdtDeckState(
        deckId: 'deck-101',
        cards: {
          'card-1': CrdtCardRecord(
            cardId: 'card-1',
            front: 'Active Card',
            back: 'Back 1',
            authorId: 'user-1',
            timestampMicros: 1000,
          ),
          'card-2': CrdtCardRecord(
            cardId: 'card-2',
            front: 'Deleted Card',
            back: 'Back 2',
            authorId: 'user-2',
            timestampMicros: 2000,
            isDeleted: true,
          ),
        },
      );

      final entity = merger.toDeckEntity(
        state,
        title: 'Physics 101',
        subject: 'Physics',
        category: 'STEM',
      );

      expect(entity.totalCards, equals(1));
      expect(entity.cards.first.front, equals('Active Card'));
    });
  });
}
