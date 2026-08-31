import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/syllabot_repository.dart';

class PurgeExpiredAiCacheUseCase {
  const PurgeExpiredAiCacheUseCase(this._repository);

  final SyllabotRepository _repository;

  Future<Either<Failure, void>> call() {
    return _repository.purgeExpiredAiCache();
  }
}
