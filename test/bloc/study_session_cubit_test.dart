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
        const StudySessionState(
          status: StudySessionStatus.studying,
          deckId: 'deck_100',
          cards: tCards,
          currentIndex: 1,
          correctCount: 1,
          goodCount: 1,
        ),
      ],
      verify: (cubit) {
        expect(cubit.cardSyncQueue.getPendingCount(), equals(1));
      },
    );
  });
}
