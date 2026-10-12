import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/pages/deck_marketplace_detail_page.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_card_preview_section.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_detail_coordinator.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_detail_layouts.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_info_panel.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_inline_clone_button.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_rating_and_delete_section.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_stats_row.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';

import '../helpers/pump_app.dart';

void main() {
  group('DeckMarketplaceDetailPage Widget Tests', () {
    const testDeck = SharedDeckEntity(
      id: 'shared_deck_1',
      title: 'Neurobiology Essentials',
      subject: 'Biology',
      ownerId: 'owner_42',
      ownerName: 'Dr. Jane Doe',
      totalCards: 25,
      downloadsCount: 150,
      category: 'Science',
      syllabusTag: 'Medical',
      description: 'High-yield flashcards covering neuron anatomy and synapses.',
      cards: [
        FlashcardEntity(
          id: 'card_1',
          deckId: 'shared_deck_1',
          front: 'What is the action potential threshold?',
          back: '-55 mV typically',
        ),
        FlashcardEntity(
          id: 'card_2',
          deckId: 'shared_deck_1',
          front: 'Which ion causes depolarization?',
          back: 'Sodium (Na+)',
        ),
      ],
    );

    testWidgets('renders compact detail layout with deck info and stats',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final coordinator = DeckMarketplaceDetailCoordinator();

      await tester.pumpApp(
        DeckMarketplaceDetailPage(
          deck: testDeck,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckMarketplaceCompactDetailLayout), findsOneWidget);
      expect(find.byType(DeckMarketplaceInfoPanel), findsOneWidget);
      expect(find.byType(DeckMarketplaceStatsRow), findsOneWidget);
      expect(find.byType(DeckMarketplaceRatingSection), findsOneWidget);
      expect(find.byType(DeckMarketplaceCardPreviewSection), findsOneWidget);
      expect(find.text('Neurobiology Essentials'), findsWidgets);
      expect(find.text('Cards'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('renders wide detail layout on desktop/tablet breakpoint',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final coordinator = DeckMarketplaceDetailCoordinator();

      await tester.pumpApp(
        DeckMarketplaceDetailPage(
          deck: testDeck,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckMarketplaceWideDetailLayout), findsOneWidget);
      expect(find.byType(DeckMarketplaceInlineCloneButton), findsOneWidget);
      expect(find.text('Clone to My Decks'), findsWidgets);
    });

    testWidgets('displays Deck in Library when deck is already cloned',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final userDecks = <DeckEntity>[
        const DeckEntity(
          id: 'cloned_shared_deck_1',
          title: 'Neurobiology Essentials',
          subject: 'Biology',
          totalCards: 25,
          dueCards: 0,
          masteryRate: 0,
          category: 'Science',
        ),
      ];

      final coordinator = _MockCoordinatorWithDecks(userDecks);

      await tester.pumpApp(
        DeckMarketplaceDetailPage(
          deck: testDeck,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deck in Library'), findsWidgets);
    });
  });
}

class _MockCoordinatorWithDecks extends DeckMarketplaceDetailCoordinator {
  _MockCoordinatorWithDecks(this._userDecks);

  final List<DeckEntity> _userDecks;

  @override
  List<DeckEntity> getUserDecks([List<DeckEntity>? fallback]) => _userDecks;

  @override
  bool isAlreadyCloned(SharedDeckEntity deck, {List<DeckEntity>? userDecks}) =>
      true;
}
