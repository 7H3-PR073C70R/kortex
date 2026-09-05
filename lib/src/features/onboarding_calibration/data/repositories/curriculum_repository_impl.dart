import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/curriculum_remote_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/curriculum_metadata_entity.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/curriculum_repository.dart';

class CurriculumRepositoryImpl implements CurriculumRepository {
  const CurriculumRepositoryImpl(this._remoteDataSource);

  final CurriculumRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<CurriculumMetadataEntity>>> getMetadataByCategory(
    String category,
  ) async {
    try {
      final models = await _remoteDataSource.fetchMetadataByCategory(category);
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, List<CurriculumMetadataEntity>>>>
      getAllMetadata() async {
    try {
      final models = await _remoteDataSource.fetchAllMetadata();
      final map = <String, List<CurriculumMetadataEntity>>{};

      for (final model in models) {
        final entity = model.toEntity();
        map.putIfAbsent(entity.category, () => []).add(entity);
      }

      return Right(map);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
