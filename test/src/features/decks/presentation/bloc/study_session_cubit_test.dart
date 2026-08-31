import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/process_card_review_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/save_session_results_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_state.dart';

class _FakeDecksRepository implements DecksRepository {
  List<FlashcardEntity> cardsToReturn = [
    FlashcardEntity(
      id: 'c1',
      deckId: 'd1',
      front: 'Front 1',
      back: 'Back 1',
      nextDueDate: DateTime.now(),
    ),
    FlashcardEntity(
      id: 'c2',
      deckId: 'd1',
      front: 'Front 2',
      back: 'Back 2',
      nextDueDate: DateTime.now(),
    ),
  ];

  @override
  Future<Either<Failure, List<FlashcardEntity>>> getDeckCards(
    String deckId,
  ) async {
    return Right(cardsToReturn);
  }

  @override
  Future<Either<Failure, List<DeckEntity>>> getUserDecks() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, Sm2CalculationResult>> processCardReview({
    required String cardId,
    required int quality,
    required int previousInterval,
    required int previousRepetitions,
    required double previousEaseFactor,
  }) async {
    return Right(
      Sm2CalculationResult(
        nextInterval: 1,
        newEaseFactor: 2.5,
        newRepetitions: 1,
        nextDueDate: DateTime.now().add(const Duration(days: 1)),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> saveSessionResults({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
  }) async {
    return const Right(null);
  }
}

void main() {
  group('StudySessionCubit', () {
    late _FakeDecksRepository fakeRepo;
    late StudySessionCubit cubit;

    setUp(() {
      fakeRepo = _FakeDecksRepository();
      cubit = StudySessionCubit(
        getDeckCardsUseCase: GetDeckCardsUseCase(fakeRepo),
        processCardReviewUseCase: ProcessCardReviewUseCase(fakeRepo),
        saveSessionResultsUseCase: SaveSessionResultsUseCase(fakeRepo),
      );
    });

    tearDown(() {
      unawaited(cubit.close());
    });

    test('initial state has StudySessionStatus.initial', () {
      expect(cubit.state.status, StudySessionStatus.initial);
    });

    test('startSession loads cards and transitions to studying state',
        () async {
      await cubit.startSession('d1');

      expect(cubit.state.status, StudySessionStatus.studying);
      expect(cubit.state.cards.length, 2);
      expect(cubit.state.currentIndex, 0);
      expect(cubit.state.isFlipped, false);
    });

    test('toggleFlip flips card state', () async {
      await cubit.startSession('d1');
      expect(cubit.state.isFlipped, false);

      cubit.toggleFlip();
      expect(cubit.state.isFlipped, true);

      cubit.toggleFlip();
      expect(cubit.state.isFlipped, false);
    });

    test('rateCard advances to next card and finishes on last card', () async {
      await cubit.startSession('d1');

      // Rate card 1: Good (4)
      await cubit.rateCard(4);
      expect(cubit.state.currentIndex, 1);
      expect(cubit.state.goodCount, 1);
      expect(cubit.state.status, StudySessionStatus.studying);

      // Rate card 2: Easy (5) -> triggers completion
      await cubit.rateCard(5);
      expect(cubit.state.status, StudySessionStatus.finished);
      expect(cubit.state.easyCount, 1);
      expect(cubit.state.retentionScore, 1.0);
    });
  });
}
