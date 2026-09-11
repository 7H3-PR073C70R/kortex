import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/save_session_results_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGetDeckCardsUseCase extends Mock implements GetDeckCardsUseCase {}

class MockSaveSessionResultsUseCase extends Mock
    implements SaveSessionResultsUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudySessionCubit Card Flipping & Rating Test Suite', () {
    late MockGetDeckCardsUseCase mockGetDeckCardsUseCase;
    late MockSaveSessionResultsUseCase mockSaveSessionResultsUseCase;

    const tCards = [
      FlashcardEntity(
        id: 'card_1',
        deckId: 'deck_100',
        front: 'Front 1',
        back: 'Back 1',
      ),
      FlashcardEntity(
        id: 'card_2',
        deckId: 'deck_100',
        front: 'Front 2',
        back: 'Back 2',
      ),
    ];

    setUpAll(() {
      registerFallbackValue(
        const SaveSessionResultsParams(
          deckId: 'deck_100',
          cardsReviewed: 2,
          durationSeconds: 10,
          retentionScore: 1,
        ),
      );
    });

    setUp(() {
      mockGetDeckCardsUseCase = MockGetDeckCardsUseCase();
      mockSaveSessionResultsUseCase = MockSaveSessionResultsUseCase();
    });

    StudySessionCubit buildCubit() => StudySessionCubit(
      getDeckCardsUseCase: mockGetDeckCardsUseCase,
      saveSessionResultsUseCase: mockSaveSessionResultsUseCase,
    );

    test('initial state has initial status with empty cards', () async {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(StudySessionStatus.initial));
      expect(cubit.state.cards, isEmpty);
      expect(cubit.state.isFlipped, isFalse);
      await cubit.close();
    });

    blocTest<StudySessionCubit, StudySessionState>(
      'startSession loads cards and transitions to studying',
      build: () {
        when(
          () => mockGetDeckCardsUseCase('deck_100'),
        ).thenAnswer((_) async => const Right(tCards));
        return buildCubit();
      },
      act: (cubit) => cubit.startSession('deck_100'),
      expect: () => [
        const StudySessionState(
          status: StudySessionStatus.loading,
          deckId: 'deck_100',
        ),
        const StudySessionState(
          status: StudySessionStatus.studying,
          deckId: 'deck_100',
          cards: tCards,
        ),
      ],
    );

    blocTest<StudySessionCubit, StudySessionState>(
      'toggleFlip toggles card flip state',
      build: buildCubit,
      seed: () => const StudySessionState(
        status: StudySessionStatus.studying,
        cards: tCards,
      ),
      act: (cubit) => cubit.toggleFlip(),
      expect: () => [
        const StudySessionState(
          status: StudySessionStatus.studying,
          cards: tCards,
          isFlipped: true,
        ),
      ],
    );

    blocTest<StudySessionCubit, StudySessionState>(
      'rateCard advances to next card and enqueues FSRS review',
      build: buildCubit,
      seed: () => const StudySessionState(
        status: StudySessionStatus.studying,
        deckId: 'deck_100',
        cards: tCards,
        isFlipped: true,
      ),
      act: (cubit) => cubit.rateCard(4),
      expect: () => [
        isA<StudySessionState>()
            .having((s) => s.status, 'status', StudySessionStatus.studying)
            .having((s) => s.deckId, 'deckId', 'deck_100')
            .having((s) => s.currentIndex, 'currentIndex', 1)
            .having((s) => s.correctCount, 'correctCount', 1)
            .having((s) => s.goodCount, 'goodCount', 1)
            .having((s) => s.cards.first.repetitions, 'card 1 repetitions', 1)
            .having((s) => s.cards.first.lastReviewed, 'card 1 lastReviewed', isNotNull)
            .having((s) => s.cards.first.nextDueDate, 'card 1 nextDueDate', isNotNull),
      ],
      verify: (cubit) {
        expect(cubit.cardSyncQueue.getPendingCount(), equals(1));
      },
    );

    group('ADHD Micro-Sprint & Randomized Flashcard Sessions', () {
      test('startSprintSession bounds cards to batchSize to avoid infinite abyss', () {
        final cubit = buildCubit();
        final largePool = List.generate(
          50,
          (i) => FlashcardEntity(
            id: 'card_$i',
            deckId: 'deck_large',
            front: 'Q$i',
            back: 'A$i',
          ),
        );

        cubit.startSprintSession(
          cardPool: largePool,
          sessionTitle: 'Quick 12 Focus',
          batchSize: 12,
        );

        expect(cubit.state.status, equals(StudySessionStatus.studying));
        expect(cubit.state.cards.length, equals(12));
        expect(cubit.state.totalCards, equals(12));
        expect(cubit.state.currentIndex, equals(0));
        expect(cubit.state.deckId, equals('Quick 12 Focus'));
      });
    });
  });
}
