part of 'locator.dart';

void _initUseCaseLocator() {
  locator
    ..registerLazySingleton<LoginWithEmailUseCase>(
      () => LoginWithEmailUseCase(locator<AuthRepository>()),
    )
    ..registerLazySingleton<RegisterWithEmailUseCase>(
      () => RegisterWithEmailUseCase(locator<AuthRepository>()),
    )
    ..registerLazySingleton<LoginWithSocialUseCase>(
      () => LoginWithSocialUseCase(locator<AuthRepository>()),
    )
    ..registerLazySingleton<ResetPasswordUseCase>(
      () => ResetPasswordUseCase(locator<AuthRepository>()),
    )
    ..registerLazySingleton<SaveCalibrationProfileUseCase>(
      () => SaveCalibrationProfileUseCase(locator<CalibrationRepository>()),
    )
    ..registerLazySingleton<GetCalibrationProfileUseCase>(
      () => GetCalibrationProfileUseCase(locator<CalibrationRepository>()),
    )
    ..registerLazySingleton<GetRecommendedContentUseCase>(
      () => GetRecommendedContentUseCase(
        locator<ContentRecommendationRepository>(),
      ),
    )
    ..registerLazySingleton<VerifyOtpUseCase>(
      () => VerifyOtpUseCase(locator<OtpRepository>()),
    )
    ..registerLazySingleton<ResendOtpUseCase>(
      () => ResendOtpUseCase(locator<OtpRepository>()),
    )
    ..registerFactory<OtpCubit>(
      () => OtpCubit(
        verifyOtpUseCase: locator<VerifyOtpUseCase>(),
        resendOtpUseCase: locator<ResendOtpUseCase>(),
      ),
    )
    ..registerLazySingleton<GetDashboardFeedUseCase>(
      () => GetDashboardFeedUseCase(locator<DashboardRepository>()),
    )
    ..registerLazySingleton<GetSm2ReviewQueueUseCase>(
      () => GetSm2ReviewQueueUseCase(locator<DashboardRepository>()),
    )
    ..registerLazySingleton<QuickStartMockExamUseCase>(
      () => QuickStartMockExamUseCase(locator<DashboardRepository>()),
    )
    ..registerFactory<DashboardBloc>(
      () => DashboardBloc(
        getDashboardFeedUseCase: locator<GetDashboardFeedUseCase>(),
        quickStartMockExamUseCase: locator<QuickStartMockExamUseCase>(),
      ),
    );
}
