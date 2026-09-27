import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

/// Domain service bridging personal FSRS decks with the community Deck Marketplace.
class DeckMarketplaceBridgeService {
  const DeckMarketplaceBridgeService({
    required CommunityRepository communityRepository,
  }) : _communityRepository = communityRepository;

  final CommunityRepository _communityRepository;

  /// Publishes a user's personal flashcard deck to the community marketplace.
  Future<Either<Failure, SharedDeckEntity>> publishPersonalDeck({
    required DeckEntity deck,
    required String description,
    required String category,
    required String syllabusTag,
  }) async {
    final cardsJson = deck.cards
        .map(
          (card) => {
            'id': card.id,
            'front': card.front,
            'back': card.back,
            'frontLatex': card.frontLatex,
            'backLatex': card.backLatex,
            'imageUrl': card.imageUrl,
            'topic': card.sourceTopic,
          },
        )
        .toList();

    return _communityRepository.publishDeckToMarketplace(
      title: deck.title,
      subject: deck.subject,
      description: description,
      category: category,
      totalCards: deck.cards.length,
      cardsJson: cardsJson,
      syllabusTag: syllabusTag,
    );
  }

  /// Clones a shared marketplace deck into user's local decks.
  Future<Either<Failure, DeckEntity>> cloneSharedDeck(String sharedDeckId) {
    return _communityRepository.cloneSharedDeck(sharedDeckId);
  }

  /// Fetches published community shared decks for a given subject track.
  Future<Either<Failure, List<SharedDeckEntity>>> fetchSharedDecks({
    String? subject,
  }) {
    return _communityRepository.fetchSharedDecks(subject: subject);
  }
}
