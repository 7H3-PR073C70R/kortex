import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/domain/services/content_safety_moderation_service.dart';
import 'package:kortex/src/features/deck_marketplace/domain/services/deck_version_tracker.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

void main() {
  group('ContentSafetyModerationService Tests', () {
    const moderationService = ContentSafetyModerationService();

    test('approves clean deck and strips personal notes and thought parking lots', () {
      final cards = [
        {
          'id': 'card_1',
          'front': "What is Newton's First Law?",
          'back': 'An object stays at rest unless acted upon by a force.',
          'personal_notes': 'Remember to ask Prof Smith about vector notation',
          'thought_parking_lot': 'Check lecture 4 recordings',
        },
      ];

      final result = moderationService.moderateAndSanitize(
        title: 'Physics Mechanics 101',
        description: 'Comprehensive JAMB Physics notes',
        cardsJson: cards,
      );

      expect(result.isApproved, isTrue);
      expect(result.personalNotesStrippedCount, equals(2));
      expect(result.sanitizedCards.first.containsKey('personal_notes'), isFalse);
      expect(result.sanitizedCards.first.containsKey('thought_parking_lot'), isFalse);
      expect(result.sanitizedCards.first['front'], equals("What is Newton's First Law?"));
    });

    test('flags deck title containing restricted exploit key phrases', () {
      final result = moderationService.moderateAndSanitize(
        title: 'Free Malware Distribution Deck',
        description: 'Physics notes',
        cardsJson: [],
      );

      expect(result.isApproved, isFalse);
      expect(result.flaggedReason, contains('restricted key phrases'));
    });
  });

  group('DeckVersionTracker Tests', () {
    const tracker = DeckVersionTracker();

    test('detects when upstream deck has more cards than local cloned copy', () {
      const localDeck = DeckEntity(
        id: 'cloned_deck_123',
        title: 'Anatomy 101',
        subject: 'Medicine',
        totalCards: 20,
        dueCards: 5,
        masteryRate: 0.8,
        category: 'Medicine',
      );

      const upstreamDeck = SharedDeckEntity(
        id: 'deck_123',
        ownerId: 'user_99',
        ownerName: 'Dr. Jane',
        title: 'Anatomy 101 (Updated Edition)',
        subject: 'Medicine',
        totalCards: 35,
        rating: 4.9,
      );

      final updateInfo = tracker.checkForUpdate(
        localDeck: localDeck,
        upstreamDeck: upstreamDeck,
      );

      expect(updateInfo.hasUpdateAvailable, isTrue);
      expect(updateInfo.upstreamTotalCards, equals(35));
    });

    test('returns no update available when local deck matches upstream card count', () {
      const localDeck = DeckEntity(
        id: 'cloned_deck_123',
        title: 'Anatomy 101',
        subject: 'Medicine',
        totalCards: 20,
        dueCards: 5,
        masteryRate: 0.8,
        category: 'Medicine',
      );

      const upstreamDeck = SharedDeckEntity(
        id: 'deck_123',
        ownerId: 'user_99',
        ownerName: 'Dr. Jane',
        title: 'Anatomy 101',
        subject: 'Medicine',
        totalCards: 20,
      );

      final updateInfo = tracker.checkForUpdate(
        localDeck: localDeck,
        upstreamDeck: upstreamDeck,
      );

      expect(updateInfo.hasUpdateAvailable, isFalse);
    });
  });
}
