import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
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
  Future<Either<Failure, void>> updateDeckCards(
    String deckId,
    List<FlashcardEntity> cards,
  ) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> saveSessionResults({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    double? masteryRate,
    int? dueCards,
    List<FlashcardEntity>? updatedCards,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteDeck(String deckId) async {
    return const Right(null);
  }
}

class _FakeLocalStorageService implements LocalStorageService {
  final Map<String, String> storage = {};

  @override
  Future<void> initDB() async {}

  @override
  Future<void> savePreference({required String key, required String data}) async {
    storage[key] = data;
  }

  @override
  String? getPreference({required String key}) => storage[key];

  @override
  Future<void> deletePreference({required String key}) async {
    storage.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudySessionCubit', () {
    late _FakeDecksRepository fakeRepo;
    late _FakeLocalStorageService fakeStorage;
    late StudySessionCubit cubit;

    setUp(() {
      fakeRepo = _FakeDecksRepository();
      fakeStorage = _FakeLocalStorageService();
      cubit = StudySessionCubit(
        getDeckCardsUseCase: GetDeckCardsUseCase(fakeRepo),
        saveSessionResultsUseCase: SaveSessionResultsUseCase(fakeRepo),
        localStorageService: fakeStorage,
      );
    });

    tearDown(() {
      unawaited(cubit.close());
    });

    test('initial state has StudySessionStatus.initial', () {
      expect(cubit.state.status, StudySessionStatus.initial);
    });

    test(
      'startSession loads cards and transitions to studying state',
      () async {
        await cubit.startSession('d1');

        expect(cubit.state.status, StudySessionStatus.studying);
        expect(cubit.state.cards.length, 2);
        expect(cubit.state.currentIndex, 0);
        expect(cubit.state.isFlipped, false);
      },
    );

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

    test(
      'rateCard with FsrsRating computes intervals and enqueues to CardSyncQueue',
      () async {
        await cubit.startSession('d1');

        // Rate card 1 using FsrsRating.hard
        await cubit.rateCard(FsrsRating.hard);
        expect(cubit.state.currentIndex, 1);
        expect(cubit.state.hardCount, 1);
        expect(cubit.cardSyncQueue.getPendingCount(), greaterThanOrEqualTo(1));

        // Rate card 2 using FsrsRating.good
        await cubit.rateCard(FsrsRating.good);
        expect(cubit.state.status, StudySessionStatus.finished);
        expect(cubit.state.goodCount, 1);
      },
    );

    test('checkpoint saves progress on rateCard and restores on next startSession', () async {
      // 1. Start session on deck with 3 cards
      fakeRepo.cardsToReturn = const [
        FlashcardEntity(id: 'c1', deckId: 'd1', front: 'F1', back: 'B1'),
        FlashcardEntity(id: 'c2', deckId: 'd1', front: 'F2', back: 'B2'),
        FlashcardEntity(id: 'c3', deckId: 'd1', front: 'F3', back: 'B3'),
      ];

      await cubit.startSession('d1');
      expect(cubit.state.currentIndex, 0);

      // 2. Study card 1 -> advances to card 2 (index 1) and saves checkpoint
      await cubit.rateCard(FsrsRating.good);
      expect(cubit.state.currentIndex, 1);
      expect(fakeStorage.storage['__kortex_deck_checkpoint_index_d1'], '1');

      // 3. Take a break (finishEarly)
      await cubit.finishEarly();
      expect(cubit.state.status, StudySessionStatus.finished);

      // 4. Start a new session on d1 -> automatically resumes at index 1!
      final newCubit = StudySessionCubit(
        getDeckCardsUseCase: GetDeckCardsUseCase(fakeRepo),
        saveSessionResultsUseCase: SaveSessionResultsUseCase(fakeRepo),
        localStorageService: fakeStorage,
      );
      await newCubit.startSession('d1');
      expect(newCubit.state.currentIndex, 1);
      expect(newCubit.state.currentCard?.id, 'c2');

      // 5. Finish remaining cards
      await newCubit.rateCard(FsrsRating.good); // now at index 2
      expect(newCubit.state.currentIndex, 2);
      await newCubit.rateCard(FsrsRating.easy); // finishes deck

      expect(newCubit.state.status, StudySessionStatus.finished);
      // Checkpoint must be cleared on deck completion
      expect(fakeStorage.storage['__kortex_deck_checkpoint_index_d1'], isNull);

      unawaited(newCubit.close());
    });
  });
}
