import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardFeedParams extends NoParams {
  const GetDashboardFeedParams({this.forceRefresh = false});

  final bool forceRefresh;

  @override
  List<Object> get props => [forceRefresh];
}

class GetDashboardFeedUseCase with UseCase<DashboardFeedEntity, NoParams> {
  const GetDashboardFeedUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, DashboardFeedEntity>> call(NoParams params) {
    final forceRefresh =
        params is GetDashboardFeedParams && params.forceRefresh;
    return _repository.getDashboardFeed(forceRefresh: forceRefresh);
  }
}
