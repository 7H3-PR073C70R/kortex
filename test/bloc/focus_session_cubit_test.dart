import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/focus_session_config.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_state.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FsrsScheduler softCatchUpReviewQueue Suite', () {
    late FsrsScheduler scheduler;

    setUp(() {
      scheduler = FsrsScheduler();
    });

    test('returns all cards if card count is less than or equal to sprintSize', () {
      final cards = List.generate(
        5,
        (i) => FlashcardEntity(
          id: 'card_$i',
          deckId: 'deck_1',
          front: 'Q$i',
          back: 'A$i',
          easeFactor: 2,
          lastReviewed: DateTime.now().subtract(Duration(days: i + 1)),
        ),
      );

      final result = scheduler.softCatchUpReviewQueue<FlashcardEntity>(
        dueCards: cards,
        getStability: (c) => c.easeFactor,
        getLastReview: (c) => c.lastReviewed,
      );

      expect(result.length, equals(5));
      expect(result, equals(cards));
    });

    test('selects balanced 60/40 queue with no duplicate cards', () {
      final now = DateTime(2026, 1, 15);
      // Create 20 cards: card_0 reviewed recently (high retrievability), card_19 reviewed long ago (low retrievability)
      final cards = List.generate(
        20,
        (i) => FlashcardEntity(
          id: 'card_$i',
          deckId: 'deck_1',
          front: 'Q$i',
          back: 'A$i',
          easeFactor: 2,
          lastReviewed: now.subtract(Duration(days: (i + 1) * 5)),
        ),
      );

      final result = scheduler.softCatchUpReviewQueue<FlashcardEntity>(
        dueCards: cards,
        getStability: (c) => c.easeFactor,
        getLastReview: (c) => c.lastReviewed,
        now: now,
      );

      expect(result.length, equals(10));

      // First card must be the highest retrievability (easy win to overcome task paralysis)
      expect(result.first.id, equals('card_0'));

      // Ensure no duplicate cards in the returned micro-sprint
      final uniqueIds = result.map((c) => c.id).toSet();
      expect(uniqueIds.length, equals(10));
    });
  });

  group('FocusSessionCubit Test Suite', () {
    late MockLocalStorageService mockStorage;

    final tCards = List.generate(
      5,
      (i) => FlashcardEntity(
        id: 'card_$i',
        deckId: 'deck_focus',
        front: 'Front $i',
        back: 'Back $i',
        lastReviewed: DateTime.now().subtract(Duration(days: i + 1)),
      ),
    );

    setUp(() {
      mockStorage = MockLocalStorageService();
      when(() => mockStorage.getPreference(key: any(named: 'key')))
          .thenReturn(null);
      when(() => mockStorage.savePreference(
            key: any(named: 'key'),
            data: any(named: 'data'),
          )).thenAnswer((_) async {});
    });

    test('initial state is correct', () async {
      final cubit = FocusSessionCubit(localStorageService: mockStorage);
      expect(cubit.state.status, equals(FocusSessionStatus.initial));
      expect(cubit.state.cards, isEmpty);
      expect(cubit.state.streak, equals(0));
      expect(cubit.state.parkedThoughts, isEmpty);
      await cubit.close();
    });

    test('startSession initializes active sprint with preloaded cards', () async {
      final cubit = FocusSessionCubit(localStorageService: mockStorage);

      await cubit.startSession(
        deckId: 'deck_focus',
        sessionTitle: 'ADHD Sprint',
        preloadedCards: tCards,
        config: const FocusSessionConfig(
          targetCardCount: 5,
        ),
      );

      expect(cubit.state.status, equals(FocusSessionStatus.active));
      expect(cubit.state.cards.length, equals(5));
      expect(cubit.state.currentIndex, equals(0));
      expect(cubit.state.currentCard?.id, equals('card_0'));
      expect(cubit.state.isFlipped, isFalse);

      await cubit.close();
    });

    test('toggleFlip alternates isFlipped state', () async {
      final cubit = FocusSessionCubit(localStorageService: mockStorage);

      await cubit.startSession(
        deckId: 'deck_focus',
        preloadedCards: tCards,
      );

      expect(cubit.state.isFlipped, isFalse);
      cubit.toggleFlip();
      expect(cubit.state.isFlipped, isTrue);
      cubit.toggleFlip();
      expect(cubit.state.isFlipped, isFalse);

      await cubit.close();
    });

    test('rateCard advances card, updates streak, and completes session', () async {
      final cubit = FocusSessionCubit(localStorageService: mockStorage);

      final twoCards = [tCards[0], tCards[1]];
      await cubit.startSession(
        deckId: 'deck_focus',
        preloadedCards: twoCards,
      );

      // Rate first card Good (Rating 4) -> advances to next card, streak becomes 1
      await cubit.rateCard(4);
      expect(cubit.state.currentIndex, equals(1));
      expect(cubit.state.streak, equals(1));
      expect(cubit.state.status, equals(FocusSessionStatus.active));

      // Rate second (and last) card Easy -> triggers completion
      await cubit.rateCard(4);
      expect(cubit.state.status, equals(FocusSessionStatus.completed));
      expect(cubit.state.correctCount, equals(2));

      await cubit.close();
    });

    test('parking lot adds, toggles, and deletes intrusive thoughts', () async {
      final cubit = FocusSessionCubit(localStorageService: mockStorage);

      await cubit.startSession(
        deckId: 'deck_focus',
        preloadedCards: tCards,
      );

      // Park an intrusive thought
      await cubit.parkThought('Check if I locked the front door');
      expect(cubit.state.parkedThoughts.length, equals(1));
      expect(
        cubit.state.parkedThoughts.first.content,
        equals('Check if I locked the front door'),
      );
      expect(cubit.state.parkedThoughts.first.isResolved, isFalse);

      verify(() => mockStorage.savePreference(
            key: FocusSessionCubit.thoughtStorageKey,
            data: any(named: 'data'),
          )).called(1);

      // Toggle thought resolved
      final thoughtId = cubit.state.parkedThoughts.first.id;
      await cubit.toggleThoughtResolved(thoughtId);
      expect(cubit.state.parkedThoughts.first.isResolved, isTrue);

      // Delete thought
      await cubit.deleteThought(thoughtId);
      expect(cubit.state.parkedThoughts, isEmpty);

      await cubit.close();
    });

    test('pause, resume, and completeEarly behave as expected', () async {
      final cubit = FocusSessionCubit(localStorageService: mockStorage);

      await cubit.startSession(
        deckId: 'deck_focus',
        preloadedCards: tCards,
      );

      cubit.pauseSession();
      expect(cubit.state.status, equals(FocusSessionStatus.paused));

      cubit.resumeSession();
      expect(cubit.state.status, equals(FocusSessionStatus.active));

      await cubit.completeEarly();
      expect(cubit.state.status, equals(FocusSessionStatus.completed));

      await cubit.close();
    });
  });
}
