import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';

class CrdtCardRecord extends Equatable {
  const CrdtCardRecord({
    required this.cardId,
    required this.front,
    required this.back,
    required this.authorId,
    required this.timestampMicros,
    this.frontLatex,
    this.backLatex,
    this.isDeleted = false,
  });

  final String cardId;
  final String front;
  final String back;
  final String? frontLatex;
  final String? backLatex;
  final String authorId;
  final int timestampMicros;
  final bool isDeleted;

  FlashcardEntity toEntity(String deckId) {
    return FlashcardEntity(
      id: cardId,
      deckId: deckId,
      front: front,
      back: back,
      frontLatex: frontLatex,
      backLatex: backLatex,
    );
  }

  @override
  List<Object?> get props => [
        cardId,
        front,
        back,
        frontLatex,
        backLatex,
        authorId,
        timestampMicros,
        isDeleted,
      ];
}

class CrdtDeckState extends Equatable {
  const CrdtDeckState({
    required this.deckId,
    required this.cards,
  });

  final String deckId;
  final Map<String, CrdtCardRecord> cards;

  CrdtDeckState copyWith({
    String? deckId,
    Map<String, CrdtCardRecord>? cards,
  }) {
    return CrdtDeckState(
      deckId: deckId ?? this.deckId,
      cards: cards ?? this.cards,
    );
  }

  @override
  List<Object?> get props => [deckId, cards];
}

class CrdtDeckMerger {
  const CrdtDeckMerger();

  /// Applies a new card insertion or update operation with LWW semantics.
  CrdtDeckState applyOperation(
    CrdtDeckState currentState,
    CrdtCardRecord newRecord,
  ) {
    final updatedCards = Map<String, CrdtCardRecord>.from(currentState.cards);
    final existing = updatedCards[newRecord.cardId];

    if (existing == null || _isNewer(newRecord, existing)) {
      updatedCards[newRecord.cardId] = newRecord;
    }

    return currentState.copyWith(cards: updatedCards);
  }

  /// Merges two divergent deck states into a deterministic converged state.
  CrdtDeckState merge(
    CrdtDeckState localState,
    CrdtDeckState remoteState,
  ) {
    final mergedCards = <String, CrdtCardRecord>{};
    final allCardIds = {
      ...localState.cards.keys,
      ...remoteState.cards.keys,
    };

    for (final cardId in allCardIds) {
      final local = localState.cards[cardId];
      final remote = remoteState.cards[cardId];

      if (local == null && remote != null) {
        mergedCards[cardId] = remote;
      } else if (local != null && remote == null) {
        mergedCards[cardId] = local;
      } else if (local != null && remote != null) {
        // Last-Write-Wins comparison
        mergedCards[cardId] = _isNewer(remote, local) ? remote : local;
      }
    }

    return CrdtDeckState(
      deckId: localState.deckId,
      cards: mergedCards,
    );
  }

  /// Converts CRDT state to DeckEntity, filtering out deleted tombstones.
  DeckEntity toDeckEntity(
    CrdtDeckState state, {
    required String title,
    required String subject,
    required String category,
    String? description,
  }) {
    final activeCards = state.cards.values
        .where((c) => !c.isDeleted)
        .map((c) => c.toEntity(state.deckId))
        .toList();

    return DeckEntity(
      id: state.deckId,
      title: title,
      subject: subject,
      category: category,
      description: description,
      totalCards: activeCards.length,
      dueCards: activeCards.where((c) => c.isDueToday).length,
      masteryRate: 0,
      cards: activeCards,
    );
  }

  bool _isNewer(CrdtCardRecord candidate, CrdtCardRecord current) {
    if (candidate.timestampMicros != current.timestampMicros) {
      return candidate.timestampMicros > current.timestampMicros;
    }
    // Deterministic tie-breaker: authorId lexicographical comparison
    return candidate.authorId.compareTo(current.authorId) > 0;
  }
}
