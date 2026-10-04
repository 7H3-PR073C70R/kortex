import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

/// Metadata detailing updates available for a cloned deck.
class DeckVersionUpdateInfo {
  const DeckVersionUpdateInfo({
    required this.clonedDeckId,
    required this.originalDeckId,
    required this.hasUpdateAvailable,
    required this.upstreamTotalCards,
    this.latestDeck,
  });

  final String clonedDeckId;
  final String originalDeckId;
  final bool hasUpdateAvailable;
  final int upstreamTotalCards;
  final SharedDeckEntity? latestDeck;
}

/// Service that checks whether a user's cloned deck has received upstream author updates.
class DeckVersionTracker {
  const DeckVersionTracker();

  /// Compares a local cloned deck with upstream community marketplace deck info
  DeckVersionUpdateInfo checkForUpdate({
    required DeckEntity localDeck,
    required SharedDeckEntity upstreamDeck,
  }) {
    final cardCountDiffers = upstreamDeck.totalCards > localDeck.totalCards;
    
    return DeckVersionUpdateInfo(
      clonedDeckId: localDeck.id,
      originalDeckId: upstreamDeck.id,
      hasUpdateAvailable: cardCountDiffers,
      upstreamTotalCards: upstreamDeck.totalCards,
      latestDeck: upstreamDeck,
    );
  }
}
