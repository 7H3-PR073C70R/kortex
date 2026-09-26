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
    this.fsrsStability = 0.0,
    this.fsrsDifficulty = 0.0,
    this.fsrsState = 0,
    this.fsrsLapses = 0,
    this.fsrsReviewTimestampMicros = 0,
  });

  final String cardId;
  final String front;
  final String back;
  final String? frontLatex;
  final String? backLatex;
  final String authorId;
  final int timestampMicros;
  final bool isDeleted;

  // FSRS memory state parameters for CRDT sync reconciliation
  final double fsrsStability;
  final double fsrsDifficulty;
  final int fsrsState;
  final int fsrsLapses;
  final int fsrsReviewTimestampMicros;

  FlashcardEntity toEntity(String deckId) {
    return FlashcardEntity(
      id: cardId,
      deckId: deckId,
      front: front,
      back: back,
      frontLatex: frontLatex,
      backLatex: backLatex,
      fsrsStability: fsrsStability,
      fsrsDifficulty: fsrsDifficulty,
      fsrsState: fsrsState,
      fsrsLapses: fsrsLapses,
      lastReviewed: fsrsReviewTimestampMicros > 0
          ? DateTime.fromMicrosecondsSinceEpoch(fsrsReviewTimestampMicros)
          : null,
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
        fsrsStability,
        fsrsDifficulty,
        fsrsState,
        fsrsLapses,
        fsrsReviewTimestampMicros,
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

    if (existing == null) {
      updatedCards[newRecord.cardId] = newRecord;
    } else {
      updatedCards[newRecord.cardId] = _mergeRecords(existing, newRecord);
    }

    return currentState.copyWith(cards: updatedCards);
  }

  /// Merges two divergent deck states into a deterministic converged state,
  /// preserving both the latest content edits and the latest FSRS review states.
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
        mergedCards[cardId] = _mergeRecords(local, remote);
      }
    }

    return CrdtDeckState(
      deckId: localState.deckId,
      cards: mergedCards,
    );
  }

  /// Merges two card records by picking the newest content payload and
  /// the newest FSRS review memory state independently.
  CrdtCardRecord _mergeRecords(CrdtCardRecord recA, CrdtCardRecord recB) {
    final contentRecord = _isContentNewer(recB, recA) ? recB : recA;
    final fsrsRecord = _isFsrsNewer(recB, recA) ? recB : recA;

    return CrdtCardRecord(
      cardId: contentRecord.cardId,
      front: contentRecord.front,
      back: contentRecord.back,
      frontLatex: contentRecord.frontLatex,
      backLatex: contentRecord.backLatex,
      authorId: contentRecord.authorId,
      timestampMicros: contentRecord.timestampMicros,
      isDeleted: (recA.isDeleted || recB.isDeleted) && _isTombstoneNewer(recA, recB),
      fsrsStability: fsrsRecord.fsrsStability,
      fsrsDifficulty: fsrsRecord.fsrsDifficulty,
      fsrsState: fsrsRecord.fsrsState,
      fsrsLapses: fsrsRecord.fsrsLapses,
      fsrsReviewTimestampMicros: fsrsRecord.fsrsReviewTimestampMicros,
    );
  }

  bool _isContentNewer(CrdtCardRecord candidate, CrdtCardRecord current) {
    if (candidate.timestampMicros != current.timestampMicros) {
      return candidate.timestampMicros > current.timestampMicros;
    }
    return candidate.authorId.compareTo(current.authorId) > 0;
  }

  bool _isFsrsNewer(CrdtCardRecord candidate, CrdtCardRecord current) {
    if (candidate.fsrsReviewTimestampMicros != current.fsrsReviewTimestampMicros) {
      return candidate.fsrsReviewTimestampMicros > current.fsrsReviewTimestampMicros;
    }
    return _isContentNewer(candidate, current);
  }

  bool _isTombstoneNewer(CrdtCardRecord recA, CrdtCardRecord recB) {
    if (recA.isDeleted && !recB.isDeleted) return recA.timestampMicros >= recB.timestampMicros;
    if (!recA.isDeleted && recB.isDeleted) return recB.timestampMicros >= recA.timestampMicros;
    return recA.isDeleted || recB.isDeleted;
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
}
