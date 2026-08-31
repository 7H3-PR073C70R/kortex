import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/decks/domain/entities/sm2_calculation_result.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';

class ProcessCardReviewParams {
  const ProcessCardReviewParams({
    required this.cardId,
    required this.quality,
    required this.previousInterval,
    required this.previousRepetitions,
    required this.previousEaseFactor,
  });

  final String cardId;
  final int quality;
  final int previousInterval;
  final int previousRepetitions;
  final double previousEaseFactor;
}

class ProcessCardReviewUseCase
    implements UseCase<Sm2CalculationResult, ProcessCardReviewParams> {
  const ProcessCardReviewUseCase(this._repository);

  final DecksRepository _repository;

  @override
  Future<Either<Failure, Sm2CalculationResult>> call(
    ProcessCardReviewParams params,
  ) {
    return _repository.processCardReview(
      cardId: params.cardId,
      quality: params.quality,
      previousInterval: params.previousInterval,
      previousRepetitions: params.previousRepetitions,
      previousEaseFactor: params.previousEaseFactor,
    );
  }
}
