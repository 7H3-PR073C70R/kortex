part of 'locator.dart';

void _initServices() {
  locator
    ..registerLazySingleton<CrashlyticsService>(
      CrashlyticsService.new,
    )
    ..registerLazySingleton<AnalyticsService>(
      AnalyticsService.new,
    )
    ..registerLazySingleton<PerformanceService>(
      PerformanceService.new,
    )
    ..registerLazySingleton<NotificationService>(
      NotificationService.new,
    )
    ..registerLazySingleton<SocialAuthService>(
      SocialAuthService.new,
    )
    ..registerLazySingleton<SessionExpiredService>(
      SessionExpiredService.new,
    )
    ..registerLazySingleton<AppRouter>(
      AppRouter.new,
    )
    ..registerLazySingleton<UserStorageService>(
      () => UserStorageServiceImpl(locator()),
    )
    ..registerLazySingleton<LocalStorageService>(
      LocalStorageServiceImpl.new,
    )
    ..registerLazySingleton<UserActivityService>(
      () => UserActivityServiceImpl(locator<LocalStorageService>()),
    )
    ..registerLazySingleton<BiometricAuthService>(
      () => BiometricAuthServiceImpl(locator()),
    )
    ..registerLazySingleton<FilePickerService>(
      FilePickerService.new,
    )
    ..registerLazySingleton<ThemeCubit>(
      () => ThemeCubit(storageService: locator()),
    )
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(
        loginWithEmailUseCase: locator<LoginWithEmailUseCase>(),
        registerWithEmailUseCase: locator<RegisterWithEmailUseCase>(),
        loginWithSocialUseCase: locator<LoginWithSocialUseCase>(),
        resetPasswordUseCase: locator<ResetPasswordUseCase>(),
        observeAuthStateUseCase: locator<ObserveAuthStateUseCase>(),
        updateCourseTrackUseCase: locator<UpdateCourseTrackUseCase>(),
        verifyOtpUseCase: locator<AuthVerifyOtpUseCase>(),
        authRepository: locator<AuthRepository>(),
      ),
    )
    ..registerLazySingleton<AuthRouteGuard>(
      () => AuthRouteGuard(locator<AuthBloc>()),
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
        autoCurateExamCoursesUseCase: locator<AutoCurateExamCoursesUseCase>(),
      ),
    )
    ..registerFactory<ContentRecommendationCubit>(
      () => ContentRecommendationCubit(
        getRecommendedContentUseCase: locator<GetRecommendedContentUseCase>(),
        getCalibrationProfileUseCase: locator<GetCalibrationProfileUseCase>(),
      ),
    )
    ..registerFactory<OnboardingCubit>(
      () => OnboardingCubit(
        completeOnboardingUseCase: locator<CompleteOnboardingUseCase>(),
      ),
    )
    ..registerFactory<ChatOnboardingBloc>(
      ChatOnboardingBloc.new,
    )
    ..registerLazySingleton<FsrsAlgorithmEngine>(
      FsrsAlgorithmEngine.new,
    )
    ..registerLazySingleton<SchedulerFactory>(
      () => SchedulerFactory(
        sm2Engine: const Sm2AlgorithmEngine(),
        fsrsEngine: locator<FsrsAlgorithmEngine>(),
      ),
    )
    ..registerLazySingleton<EbbinghausDecayCalculator>(
      EbbinghausDecayCalculator.new,
    )
    ..registerLazySingleton<AudioWorkspaceCubit>(
      () => AudioWorkspaceCubit(
        sttClient: locator<SpeechToTextClient>(),
        ttsClient: locator<TextToSpeechClient>(),
      ),
    )
    ..registerFactory<PastQuestionsBloc>(
      () => PastQuestionsBloc(
        repository: locator<PastQuestionsRepository>(),
      ),
    )
    ..registerLazySingleton<DocumentParserService>(
      DocumentParserService.new,
    )
    ..registerLazySingleton<LocalPdfParserService>(
      LocalPdfParserService.new,
    )
    ..registerLazySingleton<LocalPptxParserService>(
      LocalPptxParserService.new,
    )
    ..registerLazySingleton<LocalImageOcrService>(
      LocalImageOcrService.new,
    )
    ..registerLazySingleton<LocalIngestionService>(
      () => LocalIngestionService(
        pdfParser: locator<LocalPdfParserService>(),
        pptxParser: locator<LocalPptxParserService>(),
        imageOcr: locator<LocalImageOcrService>(),
        documentParser: locator<DocumentParserService>(),
      ),
    );
}
