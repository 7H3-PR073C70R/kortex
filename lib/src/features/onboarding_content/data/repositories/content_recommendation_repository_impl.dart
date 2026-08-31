import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_content/data/data_sources/content_recommendation_data_source.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/domain/repositories/content_recommendation_repository.dart';

class ContentRecommendationRepositoryImpl
    implements ContentRecommendationRepository {
  const ContentRecommendationRepositoryImpl({
    required ContentRecommendationDataSource dataSource,
  }) : _dataSource = dataSource;

  final ContentRecommendationDataSource _dataSource;

  @override
  Future<Either<Failure, List<RecommendedContentItem>>> getRecommendations({
    required CalibrationProfile profile,
    required String Function(String key, Map<String, dynamic> params)
        localizeHandler,
  }) async {
    try {
      final items = _dataSource.generateRecommendations(
        profile: profile,
        localizeHandler: localizeHandler,
      );
      return Right(items);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
