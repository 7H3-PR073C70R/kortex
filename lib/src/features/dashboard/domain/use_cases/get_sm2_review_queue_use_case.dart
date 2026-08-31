import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetSm2ReviewQueueUseCase with UseCase<List<StudyDeckEntity>, NoParams> {
  const GetSm2ReviewQueueUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, List<StudyDeckEntity>>> call(NoParams params) {
    return _repository.getSm2ReviewQueue();
  }
}
