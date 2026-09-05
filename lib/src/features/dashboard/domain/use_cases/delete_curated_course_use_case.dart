import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

class DeleteCuratedCourseUseCase implements UseCase<void, String> {
  const DeleteCuratedCourseUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, void>> call(String courseId) {
    return _repository.deleteCuratedCourse(courseId);
  }
}
