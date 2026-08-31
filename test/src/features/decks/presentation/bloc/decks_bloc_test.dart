import 'dart:async';
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
}

void main() {
  group('DecksBloc', () {
    late _FakeDecksRepository repo;
    late DecksBloc bloc;

    setUp(() {
      repo = _FakeDecksRepository();
      bloc = DecksBloc(getUserDecksUseCase: GetUserDecksUseCase(repo));
    });

    tearDown(() {
      unawaited(bloc.close());
    });

    test('DecksStarted loads decks and populates state', () async {
      bloc.add(const DecksStarted());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<DecksState>((s) => s.isLoading),
          predicate<DecksState>(
            (s) =>
                !s.isLoading &&
                s.allDecks.length == 2 &&
                s.totalDueCards == 4,
          ),
        ]),
      );
    });

    test('DecksSearchQueryChanged filters deck list by query', () async {
      bloc.add(const DecksStarted());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(const DecksSearchQueryChanged('Laplace'));

      await expectLater(
        bloc.stream,
        emits(
          predicate<DecksState>(
            (s) =>
                s.filteredDecks.length == 1 &&
                s.filteredDecks.first.title.contains('Laplace'),
          ),
        ),
      );
    });

    test('DecksFilterChanged filters decks by due status', () async {
      bloc.add(const DecksStarted());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(const DecksFilterChanged('due'));

      await expectLater(
        bloc.stream,
        emits(
          predicate<DecksState>(
            (s) =>
                s.activeFilter == 'due' &&
                s.filteredDecks.length == 1 &&
                s.filteredDecks.first.dueCards > 0,
          ),
        ),
      );
    });
  });
}
