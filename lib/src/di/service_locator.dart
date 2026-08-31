part of 'locator.dart';

void _initServices() {
  locator
    ..registerLazySingleton<UserStorageService>(
      () => UserStorageServiceImpl(locator()),
    )
    ..registerLazySingleton<LocalStorageService>(
      LocalStorageServiceImpl.new,
    )
    ..registerLazySingleton<FilePickerService>(
      FilePickerService.new,
    )
    ..registerLazySingleton<ThemeCubit>(
      () => ThemeCubit(storageService: locator()),
    )
    ..registerFactory<AuthBloc>(
      () => AuthBloc(
        loginWithEmailUseCase: locator<LoginWithEmailUseCase>(),
        registerWithEmailUseCase: locator<RegisterWithEmailUseCase>(),
        loginWithSocialUseCase: locator<LoginWithSocialUseCase>(),
        resetPasswordUseCase: locator<ResetPasswordUseCase>(),
      ),
    )
    ..registerLazySingleton<AuthModeCubit>(
      AuthModeCubit.new,
    )
    ..registerLazySingleton<AuthDraftCubit>(
      AuthDraftCubit.new,
    )
    ..registerFactory<CalibrationCubit>(
      () => CalibrationCubit(
        saveCalibrationProfileUseCase: locator<SaveCalibrationProfileUseCase>(),
      ),
    )
    ..registerFactory<ContentRecommendationCubit>(
      () => ContentRecommendationCubit(
        getRecommendedContentUseCase: locator<GetRecommendedContentUseCase>(),
        getCalibrationProfileUseCase: locator<GetCalibrationProfileUseCase>(),
      ),
    );
}
