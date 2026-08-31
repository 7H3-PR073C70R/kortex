import 'package:kortex/src/core/error/failure.dart';
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
  }) async {
    try {
      final courses = await _dataSource.fetchGoogleClassroomCourses(
        oauthToken: oauthToken,
      );
      return Right(courses);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LmsCourse>>> fetchCanvasCourses({
    required String canvasDomain,
    required String apiToken,
  }) async {
    try {
      final courses = await _dataSource.fetchCanvasCourses(
        canvasDomain: canvasDomain,
        apiToken: apiToken,
      );
      return Right(courses);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, LmsImportBundle>> importCourse({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  }) async {
    try {
      final bundle = await _dataSource.importCourseData(
        platform: platform,
        courseId: courseId,
        authToken: authToken,
        canvasDomain: canvasDomain,
      );
      return Right(bundle);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
