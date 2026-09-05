import 'package:kortex/src/features/onboarding_calibration/data/models/curriculum_metadata_model.dart';

abstract class CurriculumRemoteDataSource {
  Future<List<CurriculumMetadataModel>> fetchMetadataByCategory(
    String category,
  );

  Future<List<CurriculumMetadataModel>> fetchAllMetadata();
}
