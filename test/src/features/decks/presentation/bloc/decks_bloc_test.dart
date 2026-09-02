import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';

class _FakeDecksRepository implements DecksRepository {
  List<DeckEntity> decksToReturn = const [
    DeckEntity(
      id: 'd1',
      title: 'Laplace Transforms',
      subject: 'Mathematics',
      totalCards: 10,
      dueCards: 4,
      masteryRate: 0.7,
      category: 'STEM',
    ),
    DeckEntity(
      id: 'd2',
      title: 'Neurotransmission',
      subject: 'Medicine',
      totalCards: 8,
      dueCards: 0,
      masteryRate: 0.95,
      category: 'Biology',
    ),
  ];

  @override
  Future<Either<Failure, List<DeckEntity>>> getUserDecks() async {
    return Right(decksToReturn);
  }

  @override
  Future<Either<Failure, List<FlashcardEntity>>> getDeckCards(
    String deckId,
  ) async {
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
    throw UnimplementedError();
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

  @override
  Future<Either<Failure, void>> deleteDeck(String deckId) async {
    return const Right(null);
  }
}

void main() {
  group('DecksBloc', () {
    late _FakeDecksRepository repo;
    late DecksBloc bloc;

    setUp(() {
      repo = _FakeDecksRepository();
      bloc = DecksBloc(
        getUserDecksUseCase: GetUserDecksUseCase(repo),
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is correct', () {
      expect(bloc.state.status, DecksStatus.initial);
      expect(bloc.state.allDecks, isEmpty);
      expect(bloc.state.filteredDecks, isEmpty);
    });

    blocTest<DecksBloc, DecksState>(
      'loads decks on DecksStarted',
      build: () => bloc,
      act: (b) => b.add(const DecksStarted()),
      expect: () => [
        const DecksState(status: DecksStatus.loading),
        DecksState(
          status: DecksStatus.loaded,
          allDecks: repo.decksToReturn,
          filteredDecks: repo.decksToReturn,
        ),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'filters by due cards',
      build: () => bloc,
      seed: () => DecksState(
        status: DecksStatus.loaded,
        allDecks: repo.decksToReturn,
        filteredDecks: repo.decksToReturn,
      ),
      act: (b) => b.add(const DecksFilterChanged('due')),
      expect: () => [
        DecksState(
          status: DecksStatus.loaded,
          allDecks: repo.decksToReturn,
          filteredDecks: [repo.decksToReturn[0]],
          activeFilter: 'due',
        ),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'filters by mastered cards (>=90% mastery)',
      build: () => bloc,
      seed: () => DecksState(
        status: DecksStatus.loaded,
        allDecks: repo.decksToReturn,
        filteredDecks: repo.decksToReturn,
      ),
      act: (b) => b.add(const DecksFilterChanged('mastered')),
      expect: () => [
        DecksState(
          status: DecksStatus.loaded,
          allDecks: repo.decksToReturn,
          filteredDecks: [repo.decksToReturn[1]],
          activeFilter: 'mastered',
        ),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'removes deck on DecksDeckDeleted',
      build: () => bloc,
      seed: () => DecksState(
        status: DecksStatus.loaded,
        allDecks: repo.decksToReturn,
        filteredDecks: repo.decksToReturn,
      ),
      act: (b) => b.add(const DecksDeckDeleted('d1')),
      expect: () => [
        DecksState(
          status: DecksStatus.loaded,
          allDecks: [repo.decksToReturn[1]],
          filteredDecks: [repo.decksToReturn[1]],
        ),
      ],
    );
  });
}
