import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/curriculum_metadata_entity.dart';

abstract class CurriculumRepository {
  /// Fetches active curriculum metadata items belonging to a specific category.
  Future<Either<Failure, List<CurriculumMetadataEntity>>> getMetadataByCategory(
    String category,
  );

  /// Fetches all active curriculum metadata items grouped by category.
  Future<Either<Failure, Map<String, List<CurriculumMetadataEntity>>>>
      getAllMetadata();
}
