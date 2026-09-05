import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

class SyncUserCoursesParams extends Equatable {
  const SyncUserCoursesParams({required this.courses});

  final List<Map<String, dynamic>> courses;

  @override
  List<Object?> get props => [courses];
}

class SyncUserCoursesUseCase with UseCase<void, SyncUserCoursesParams> {
  const SyncUserCoursesUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, void>> call(SyncUserCoursesParams params) {
    return _repository.syncUserCourses(params.courses);
  }
}
