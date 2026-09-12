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

      test('adaptiveShuffle blends challenging/due cards with easy momentum cards', () {
        final cubit = buildCubit();

        // 10 hard cards (repetitions == 0, easeFactor < 2.5)
        final hardCards = List.generate(
          10,
          (i) => FlashcardEntity(
            id: 'hard_$i',
            deckId: 'deck_mix',
            front: 'Hard $i',
            back: 'Ans $i',
            easeFactor: 1.8,
          ),
        );

        // 10 easy cards (repetitions >= 3, easeFactor >= 2.5, interval > 3)
        final easyCards = List.generate(
          10,
          (i) => FlashcardEntity(
            id: 'easy_$i',
            deckId: 'deck_mix',
            front: 'Easy $i',
            back: 'Ans $i',
            easeFactor: 2.7,
            repetitions: 5,
            interval: 10,
            nextDueDate: DateTime.now().add(const Duration(days: 7)),
          ),
        );

        final mixedPool = [...hardCards, ...easyCards];
        final sprintBatch = cubit.adaptiveShuffle(mixedPool, 10);

        expect(sprintBatch.length, equals(10));
        final hardSelected = sprintBatch.where((c) => c.id.startsWith('hard_')).length;
        final easySelected = sprintBatch.where((c) => c.id.startsWith('easy_')).length;

        // ~70% hard (7 cards) and ~30% easy (3 cards)
        expect(hardSelected, equals(7));
        expect(easySelected, equals(3));
      });

      test('speed run session configures countdown timer and formatting', () {
        final cubit = buildCubit()
          ..startSprintSession(
            cardPool: tCards,
            sessionTitle: 'Speed Run 3m',
            batchSize: 2,
            targetDurationSeconds: 180,
          );

        expect(cubit.isSpeedRun, isTrue);
        expect(cubit.targetDurationSeconds, equals(180));
        expect(cubit.formattedRemainingTime(0), equals('03:00'));
        expect(cubit.formattedRemainingTime(65), equals('01:55'));
        expect(cubit.formattedRemainingTime(180), equals('00:00'));
      });
    });
  });
}
