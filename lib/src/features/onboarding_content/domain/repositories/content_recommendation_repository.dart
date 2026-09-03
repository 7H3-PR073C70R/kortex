import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';

abstract class ContentRecommendationRepository {
  Future<Either<Failure, List<RecommendedContentItem>>> getRecommendations({
    required CalibrationProfile profile,
    required String Function(String key, Map<String, dynamic> params)
    localizeHandler,
  });
}
