import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

/// Use case to fetch active review queue powered by FSRS-6 memory model.
class GetReviewQueueUseCase with UseCase<List<StudyDeckEntity>, NoParams> {
  const GetReviewQueueUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, List<StudyDeckEntity>>> call(NoParams params) {
    return _repository.getReviewQueue();
  }
}

@Deprecated('Use GetReviewQueueUseCase with FSRS-6')
typedef GetSm2ReviewQueueUseCase = GetReviewQueueUseCase;
