import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';

class DecksRepositoryImpl implements DecksRepository {
  const DecksRepositoryImpl(this._remoteDataSource);

  final DecksRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<DeckEntity>>> getUserDecks() async {
    try {
      final models = await _remoteDataSource.getUserDecks();
      return Right(models.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FlashcardEntity>>> getDeckCards(
    String deckId,
  ) async {
    try {
      final models = await _remoteDataSource.getDeckCards(deckId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Sm2CalculationResult>> processCardReview({
    required String cardId,
    required int quality,
    required int previousInterval,
    required int previousRepetitions,
    required double previousEaseFactor,
  }) async {
    try {
      final result = await _remoteDataSource.processCardReview(
        cardId: cardId,
        quality: quality,
        previousInterval: previousInterval,
        previousRepetitions: previousRepetitions,
        previousEaseFactor: previousEaseFactor,
      );
      return Right(result);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveSessionResults({
    required String deckId,
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
  }) async {
    try {
      await _remoteDataSource.saveSessionResults(
        deckId: deckId,
        cardsReviewed: cardsReviewed,
        durationSeconds: durationSeconds,
        retentionScore: retentionScore,
      );
      return const Right(null);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
