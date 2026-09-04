import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/lms_repository.dart';

class FetchLmsCoursesUseCase {
  const FetchLmsCoursesUseCase(this._repository);

  final LmsRepository _repository;

  Future<Either<Failure, List<LmsCourse>>> call({
    required String platform,
    required String authToken,
    String? canvasDomain,
  }) {
    if (platform == 'canvas') {
      return _repository.fetchCanvasCourses(
        canvasDomain: canvasDomain ?? 'canvas.instructure.com',
        apiToken: authToken,
      );
    }
    return _repository.fetchGoogleClassroomCourses(
      oauthToken: authToken,
    );
  }
}
