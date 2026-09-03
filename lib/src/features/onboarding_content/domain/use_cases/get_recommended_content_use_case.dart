import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/domain/repositories/content_recommendation_repository.dart';

class GetRecommendationsParams extends Equatable {
  const GetRecommendationsParams({
    required this.profile,
    required this.localizeHandler,
  });

  final CalibrationProfile profile;
  final String Function(String key, Map<String, dynamic> params)
  localizeHandler;

  @override
  List<Object?> get props => [profile];
}

class GetRecommendedContentUseCase
    with UseCase<List<RecommendedContentItem>, GetRecommendationsParams> {
  const GetRecommendedContentUseCase(this._repository);

  final ContentRecommendationRepository _repository;

  @override
  Future<Either<Failure, List<RecommendedContentItem>>> call(
    GetRecommendationsParams params,
  ) {
    return _repository.getRecommendations(
      profile: params.profile,
      localizeHandler: params.localizeHandler,
    );
  }
}
