import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/get_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_content/domain/use_cases/get_recommended_content_use_case.dart';
import 'package:kortex/src/features/onboarding_content/presentation/bloc/content_recommendation_state.dart';

class ContentRecommendationCubit extends Cubit<ContentRecommendationState> {
  ContentRecommendationCubit({
    required GetRecommendedContentUseCase getRecommendedContentUseCase,
    required GetCalibrationProfileUseCase getCalibrationProfileUseCase,
  }) : _getRecommendedContentUseCase = getRecommendedContentUseCase,
       _getCalibrationProfileUseCase = getCalibrationProfileUseCase,
       super(const ContentRecommendationState());

  final GetRecommendedContentUseCase _getRecommendedContentUseCase;
  final GetCalibrationProfileUseCase _getCalibrationProfileUseCase;

  Future<void> loadRecommendations({
    required String Function(String key, Map<String, dynamic> params)
    localizeHandler,
  }) async {
    emit(state.copyWith(status: ContentRecommendationStatus.loading));

    final profileResult = await _getCalibrationProfileUseCase(const NoParams());
    final profile = profileResult.fold(
      (_) => const CalibrationProfile(),
      (loaded) => loaded ?? const CalibrationProfile(),
    );

    final result = await _getRecommendedContentUseCase(
      GetRecommendationsParams(
        profile: profile,
        localizeHandler: localizeHandler,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ContentRecommendationStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (items) => emit(
        state.copyWith(
          status: ContentRecommendationStatus.loaded,
          items: items,
          currentIndex: 0,
        ),
      ),
    );
  }

  void onPageChanged(int index) {
    emit(state.copyWith(currentIndex: index));
  }
}
