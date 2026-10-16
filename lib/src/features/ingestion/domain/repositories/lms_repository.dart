import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/domain/entities/lms_course_entity.dart';

abstract class LmsRepository {
  Future<Either<Failure, List<LmsCourse>>> fetchGoogleClassroomCourses({
    required String oauthToken,
  });

  Future<Either<Failure, List<LmsCourse>>> fetchCanvasCourses({
    required String canvasDomain,
    required String apiToken,
  });

  Future<Either<Failure, LmsImportBundle>> importCourse({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  });
}
