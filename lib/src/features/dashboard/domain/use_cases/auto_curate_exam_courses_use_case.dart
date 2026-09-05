import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

class AutoCurateExamCoursesParams extends Equatable {
  const AutoCurateExamCoursesParams({
    required this.examName,
    required this.subjects,
  });

  final String examName;
  final List<String> subjects;

  @override
  List<Object?> get props => [examName, subjects];
}

class AutoCurateExamCoursesUseCase
    with UseCase<void, AutoCurateExamCoursesParams> {
  const AutoCurateExamCoursesUseCase(this._repository);

  final DashboardRepository _repository;

  @override
  Future<Either<Failure, void>> call(AutoCurateExamCoursesParams params) {
    return _repository.autoCurateExamCourses(
      examName: params.examName,
      subjects: params.subjects,
    );
  }
}
