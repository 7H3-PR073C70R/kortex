part of 'locator.dart';

void _initServices() {
  locator
    ..registerLazySingleton<AppSyncEngine>(
      AppSyncEngine.new,
    )
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
    ..registerLazySingleton<NotificationRouter>(
      NotificationRouter.new,
    )
    ..registerLazySingleton<DynamicLinkService>(
      DynamicLinkService.new,
    )
    ..registerLazySingleton<LinkSharingService>(
      () => LinkSharingService(
        dynamicLinkService: locator<DynamicLinkService>(),
      ),
    )
    ..registerLazySingleton<SocialAuthService>(
      SocialAuthService.new,
    )
    ..registerLazySingleton<SessionExpiredService>(
      SessionExpiredService.new,
    )
    ..registerLazySingleton<BreakReminderService>(
      BreakReminderService.new,
    )
    ..registerLazySingleton<AppRouter>(
      () => AppRouter(authGuard: locator<AuthRouteGuard>()),
    )
    ..registerLazySingleton<UserStorageService>(
      () => UserStorageServiceImpl(
        locator<LocalStorageService>(),
        secureStorage: locator<FlutterSecureStorage>(),
      ),
    )
    ..registerLazySingleton<LocalStorageService>(
      LocalStorageServiceImpl.new,
    )
    ..registerLazySingleton<DeviceIdentityService>(
      () => DeviceIdentityService(
        localStorageService: locator<LocalStorageService>(),
        secureStorage: locator<FlutterSecureStorage>(),
      ),
    )
    ..registerLazySingleton<SubscriptionGuard>(
      () => SubscriptionGuard(
        userStorageService: locator<UserStorageService>(),
        localStorageService: locator<LocalStorageService>(),
      ),
    )
    ..registerLazySingleton<UserActivityService>(
      () => UserActivityServiceImpl(
        locator<LocalStorageService>(),
        connectivity: Connectivity(),
      ),
    )
    ..registerLazySingleton<ForumOfflineSyncQueue>(
      () => ForumOfflineSyncQueue(
        localStorageService: locator<LocalStorageService>(),
      ),
    )
    ..registerLazySingleton<StudyActivityTracker>(
      StudyActivityTrackerImpl.new,
    )
    ..registerLazySingleton<AssessmentOrchestratorService>(
      () => AssessmentOrchestratorService(
        userActivityService: locator<UserActivityService>(),
        userStorageService: locator<UserStorageService>(),
        fsrsEngine: locator.isRegistered<FsrsAlgorithmEngine>()
            ? locator<FsrsAlgorithmEngine>()
            : null,
        decksRepository: locator.isRegistered<DecksRepository>()
            ? locator<DecksRepository>()
            : null,
        plannerRepository: locator.isRegistered<PlannerRepository>()
            ? locator<PlannerRepository>()
            : null,
      ),
    )
    ..registerLazySingleton<BiometricAuthService>(
      () => BiometricAuthServiceImpl(locator()),
    )
    ..registerLazySingleton<FsrsSettingsSyncService>(
      FsrsSettingsSyncService.new,
    )
    ..registerLazySingleton<FilePickerService>(
      FilePickerService.new,
    )
    ..registerLazySingleton<MediaUploadService>(
      MediaUploadService.new,
    )
    ..registerLazySingleton<AudioRecordingService>(
      AudioRecordingServiceImpl.new,
    )
    ..registerLazySingleton<AudioEarconService>(
      AudioEarconServiceImpl.new,
    )
    ..registerLazySingleton<TextToSpeechService>(
      () => TextToSpeechServiceImpl(
        localStorageService: locator.isRegistered<LocalStorageService>()
            ? locator<LocalStorageService>()
            : null,
      ),
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
      () => AuthRouteGuard(
        locator<AuthBloc>(),
        locator<UserStorageService>(),
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
        autoCurateExamCoursesUseCase: locator<AutoCurateExamCoursesUseCase>(),
        curriculumRepository: locator<CurriculumRepository>(),
        getCuratedCoursesCatalogUseCase:
            locator<GetCuratedCoursesCatalogUseCase>(),
      ),
    )
    ..registerLazySingleton<StudyEngineRouter>(
      StudyEngineRouter.new,
    )
    ..registerLazySingleton<FsrsAlgorithmEngine>(
      FsrsAlgorithmEngine.new,
    )
    ..registerLazySingleton<SchedulerFactory>(
      () => SchedulerFactory(
        fsrsEngine: locator<FsrsAlgorithmEngine>(),
      ),
    )
    ..registerLazySingleton<EbbinghausDecayCalculator>(
      EbbinghausDecayCalculator.new,
    )
    ..registerFactory<PastQuestionsBloc>(
      () => PastQuestionsBloc(
        repository: locator<PastQuestionsRepository>(),
        userActivityService: locator.isRegistered<UserActivityService>()
            ? locator<UserActivityService>()
            : null,
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
      ),
    )
    ..registerFactory<OnboardingStreamController>(
      () => OnboardingStreamController(dio: locator<Dio>()),
    )
    ..registerLazySingleton<LiveKitAudioService>(
      LiveKitAudioServiceImpl.new,
    )
    ..registerLazySingleton<PastQuestionAiExtractorService>(
      () => PastQuestionAiExtractorService(
        ingestionService: locator<LocalIngestionService>(),
        dio: locator<Dio>(),
      ),
    )
    ..registerFactory<QuizDuelCubit>(
      () => QuizDuelCubit(
        repository: locator<QuizDuelRepository>(),
      ),
    )

    // ── Force-Update ─────────────────────────────────────────────────────────
    ..registerLazySingleton<CheckForceUpdateUseCase>(
      () => CheckForceUpdateUseCase(
        repository: locator<AppVersionRepository>(),
      ),
    )
    ..registerLazySingleton<ForceUpdateService>(
      () => ForceUpdateService(
        checkForceUpdateUseCase: locator<CheckForceUpdateUseCase>(),
      ),
    );
}
