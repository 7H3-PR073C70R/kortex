import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardFeedUseCase with UseCase<DashboardFeedEntity, NoParams> {
  const GetDashboardFeedUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, DashboardFeedEntity>> call(NoParams params) {
    return _repository.getDashboardFeed();
  }
}
