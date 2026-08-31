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
    )
    ..registerLazySingleton<GetUserDecksUseCase>(
      () => GetUserDecksUseCase(locator<DecksRepository>()),
    )
    ..registerLazySingleton<GetDeckCardsUseCase>(
      () => GetDeckCardsUseCase(locator<DecksRepository>()),
    )
    ..registerLazySingleton<ProcessCardReviewUseCase>(
      () => ProcessCardReviewUseCase(locator<DecksRepository>()),
    )
    ..registerLazySingleton<SaveSessionResultsUseCase>(
      () => SaveSessionResultsUseCase(locator<DecksRepository>()),
    )
    ..registerFactory<DecksBloc>(
      () => DecksBloc(
        getUserDecksUseCase: locator<GetUserDecksUseCase>(),
      ),
    )
    ..registerFactory<StudySessionCubit>(
      () => StudySessionCubit(
        getDeckCardsUseCase: locator<GetDeckCardsUseCase>(),
        processCardReviewUseCase: locator<ProcessCardReviewUseCase>(),
        saveSessionResultsUseCase: locator<SaveSessionResultsUseCase>(),
      ),
    )
    ..registerLazySingleton<StreamSyllabotResponseUseCase>(
      () => StreamSyllabotResponseUseCase(locator<SyllabotRepository>()),
    )
    ..registerLazySingleton<GetChatHistoryUseCase>(
      () => GetChatHistoryUseCase(locator<SyllabotRepository>()),
    )
    ..registerLazySingleton<GenerateDeckFromChatUseCase>(
      () => GenerateDeckFromChatUseCase(locator<SyllabotRepository>()),
    )
    ..registerLazySingleton<PurgeExpiredAiCacheUseCase>(
      () => PurgeExpiredAiCacheUseCase(locator<SyllabotRepository>()),
    )
    ..registerFactory<SyllabotChatBloc>(
      () => SyllabotChatBloc(
        streamResponseUseCase: locator<StreamSyllabotResponseUseCase>(),
        getChatHistoryUseCase: locator<GetChatHistoryUseCase>(),
        generateDeckUseCase: locator<GenerateDeckFromChatUseCase>(),
      ),
    )
    ..registerLazySingleton<UploadStudyDocumentUseCase>(
      () => UploadStudyDocumentUseCase(locator<IngestionRepository>()),
    )
    ..registerLazySingleton<ProcessStemOcrUseCase>(
      () => ProcessStemOcrUseCase(locator<IngestionRepository>()),
    )
    ..registerLazySingleton<GenerateFlashcardsFromDocUseCase>(
      () => GenerateFlashcardsFromDocUseCase(locator<IngestionRepository>()),
    )
    ..registerLazySingleton<FetchUserDocumentsUseCase>(
      () => FetchUserDocumentsUseCase(locator<IngestionRepository>()),
    )
    ..registerFactory<IngestionBloc>(
      () => IngestionBloc(
        uploadUseCase: locator<UploadStudyDocumentUseCase>(),
        processOcrUseCase: locator<ProcessStemOcrUseCase>(),
        generateDeckUseCase: locator<GenerateFlashcardsFromDocUseCase>(),
        fetchUserDocsUseCase: locator<FetchUserDocumentsUseCase>(),
      ),
    )
    ..registerLazySingleton<JoinLiveStudyRoomUseCase>(
      () => JoinLiveStudyRoomUseCase(locator<CommunityRepository>()),
    )
    ..registerLazySingleton<FetchForumPostsUseCase>(
      () => FetchForumPostsUseCase(locator<CommunityRepository>()),
    )
    ..registerLazySingleton<CloneSharedDeckUseCase>(
      () => CloneSharedDeckUseCase(locator<CommunityRepository>()),
    )
    ..registerLazySingleton<StreamLeaderboardRankingsUseCase>(
      () => StreamLeaderboardRankingsUseCase(locator<CommunityRepository>()),
    )
    ..registerFactory<CommunityHubBloc>(
      () => CommunityHubBloc(
        repository: locator<CommunityRepository>(),
      ),
    );
}
