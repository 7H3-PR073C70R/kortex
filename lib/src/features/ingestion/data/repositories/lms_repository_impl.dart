import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/lms_repository.dart';

class LmsRepositoryImpl implements LmsRepository {
  LmsRepositoryImpl({LmsImportDataSource? dataSource})
    : _dataSource = dataSource ?? LmsImportDataSourceImpl();

  final LmsImportDataSource _dataSource;

  @override
  Future<Either<Failure, List<LmsCourse>>> fetchGoogleClassroomCourses({
    required String oauthToken,
  }) {
    return _dataSource
        .fetchGoogleClassroomCourses(oauthToken: oauthToken)
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<LmsCourse>>> fetchCanvasCourses({
    required String canvasDomain,
    required String apiToken,
  }) {
    return _dataSource
        .fetchCanvasCourses(
          canvasDomain: canvasDomain,
          apiToken: apiToken,
        )
        .makeRequest();
  }

  @override
  Future<Either<Failure, LmsImportBundle>> importCourse({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  }) {
    return _dataSource
        .importCourseData(
          platform: platform,
          courseId: courseId,
          authToken: authToken,
          canvasDomain: canvasDomain,
        )
        .makeRequest();
  }
}
