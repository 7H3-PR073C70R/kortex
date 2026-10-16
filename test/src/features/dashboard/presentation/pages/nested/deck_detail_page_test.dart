import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/presentation/pages/nested/deck_detail_page.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/deck_detail/deck_detail_states.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/deck_detail/flashcard_surface.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/deck_detail/fsrs_rating_button.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../helpers/pump_app.dart';

class MockDecksBloc extends MockBloc<DecksEvent, DecksState>
    implements DecksBloc {}

void main() {
  group('DeckDetailPage Widget Tests', () {
    late MockDecksBloc mockDecksBloc;

    const testCards = [
      FlashcardEntity(
        id: 'card_1',
        deckId: 'deck_1',
        front: 'What is Newton second law?',
        back: 'Force equals mass times acceleration',
      ),
      FlashcardEntity(
        id: 'card_2',
        deckId: 'deck_1',
        front: 'What is kinetic energy formula?',
        back: 'E = half m v squared',
      ),
    ];

    const testDeck = DeckEntity(
      id: 'deck_1',
      title: 'Physics Mechanics',
      subject: 'Physics',
      totalCards: 2,
      dueCards: 2,
      masteryRate: 80,
      category: 'Science',
      cards: testCards,
    );

    setUp(() {
      mockDecksBloc = MockDecksBloc();
    });

    testWidgets('renders flashcard surface and card progress when deck has cards', (tester) async {
      when(() => mockDecksBloc.state).thenReturn(
        const DecksState(
          allDecks: [testDeck],
          status: DecksStatus.loaded,
        ),
      );

      await tester.pumpApp(
        DeckDetailPage(
          deckId: 'deck_1',
          decksBloc: mockDecksBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Physics Mechanics'), findsOneWidget);
      expect(find.byType(FlashcardSurface), findsOneWidget);
      expect(find.text('What is Newton second law?'), findsOneWidget);
      expect(find.text('ACTIVE REVIEW QUEUE'), findsOneWidget);
    });

    testWidgets('flipping card reveals back face and FSRS rating buttons', (tester) async {
      when(() => mockDecksBloc.state).thenReturn(
        const DecksState(
          allDecks: [testDeck],
          status: DecksStatus.loaded,
        ),
      );

      await tester.pumpApp(
        DeckDetailPage(
          deckId: 'deck_1',
          decksBloc: mockDecksBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Tap flashcard surface to flip
      await tester.tap(find.byType(FlashcardSurface));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Force equals mass times acceleration', findRichText: true), findsOneWidget);
      expect(find.byType(FsrsRatingButton), findsNWidgets(3));
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
    });

    testWidgets('renders empty state when deck contains no cards', (tester) async {
      final emptyDeck = testDeck.copyWith(cards: [], totalCards: 0);

      when(() => mockDecksBloc.state).thenReturn(
        DecksState(
          allDecks: [emptyDeck],
          status: DecksStatus.loaded,
        ),
      );

      await tester.pumpApp(
        DeckDetailPage(
          deckId: 'deck_1',
          decksBloc: mockDecksBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DeckDetailEmptyState), findsOneWidget);
      expect(find.text('No Flashcards Found'), findsOneWidget);
    });
  });
}
