import 'package:auto_route/auto_route.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/features/auth/presentation/guards/auth_route_guard.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  AppRouter({required AuthRouteGuard authGuard}) : _authGuard = authGuard;

  final AuthRouteGuard _authGuard;

  @override
  List<AutoRouteGuard> get guards => [_authGuard];

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SplashRoute.page, path: '/splash', initial: true),
    AutoRoute(page: OnboardingRoute.page, path: '/onboarding'),
    AutoRoute(page: AuthRoute.page, path: '/login'),
    AutoRoute(page: ForgotPasswordRoute.page, path: '/forgot-password'),
    AutoRoute(page: OtpVerificationRoute.page, path: '/otp-verification'),
    AutoRoute(page: OnboardingCalibrationRoute.page, path: '/calibration'),
    AutoRoute(page: PermissionsRoute.page, path: '/permissions'),
    AutoRoute(page: DeckDetailRoute.page, path: '/deck'),
    AutoRoute(page: CreateDeckRoute.page, path: '/create-deck'),
    AutoRoute(page: OfflineFlashcardGenerationRoute.page, path: '/generate-cards'),
    AutoRoute(page: StudySessionRoute.page, path: '/study-session'),
    CustomRoute<void>(
      page: SessionSummaryRoute.page,
      path: '/session-summary',
      opaque: false,
      transitionsBuilder: TransitionsBuilders.fadeIn,
    ),
    AutoRoute(page: MockExamLobbyRoute.page, path: '/mock-exam'),
    AutoRoute(page: AnalyticsDetailRoute.page, path: '/analytics'),
    AutoRoute(page: CourseModuleRoute.page, path: '/course-module'),
    AutoRoute(page: CurateCoursesRoute.page, path: '/curate-courses'),
    AutoRoute(page: AllCuratedCoursesRoute.page, path: '/all-courses'),
    AutoRoute(page: DocumentIngestionRoute.page, path: '/document-ingestion'),
    AutoRoute(page: OcrPreviewRoute.page, path: '/ocr-preview'),
    AutoRoute(page: GeneratedCardsReviewRoute.page, path: '/review-generated-cards'),
    AutoRoute(page: LiveStudyRoomRoute.page, path: '/study-room'),
    AutoRoute(page: ForumThreadDetailRoute.page, path: '/forum-thread'),
    AutoRoute(page: CreateForumDiscussionRoute.page, path: '/create-discussion'),
    AutoRoute(page: DeckMarketplaceDetailRoute.page, path: '/marketplace-deck'),
    AutoRoute(page: TwoFactorSetupRoute.page, path: '/two-factor-setup'),
    AutoRoute(page: PastQuestionsBoardRoute.page, path: '/past-questions'),
    AutoRoute(page: CourseQuestionsRoute.page, path: '/course-questions'),
    AutoRoute(page: QuizWorkspaceRoute.page, path: '/quiz-workspace'),
    AutoRoute(page: QuizResultsRoute.page, path: '/quiz-results'),
    CustomRoute<void>(
      page: PaywallRoute.page,
      path: '/paywall',
      opaque: false,
      transitionsBuilder: TransitionsBuilders.fadeIn,
    ),
    AutoRoute(page: SyllabotChatRoute.page, path: '/syllabot'),
    AutoRoute(page: ExamTimetableRoute.page, path: '/timetable'),
    AutoRoute(page: AddAcademicAssessmentRoute.page, path: '/add-assessment'),
    AutoRoute(page: AcademicTrackSettingsRoute.page, path: '/settings/academic-track'),
    AutoRoute(page: DeckPaceSettingsRoute.page, path: '/settings/deck-pace'),
    AutoRoute(page: SyllabotAiSettingsRoute.page, path: '/settings/syllabot-ai'),
    AutoRoute(page: SecuritySettingsRoute.page, path: '/settings/security'),
    AutoRoute(page: AppPreferencesRoute.page, path: '/settings/preferences'),
    AutoRoute(page: AboutSupportRoute.page, path: '/settings/support'),
    AutoRoute(page: LeaderboardRoute.page, path: '/leaderboard'),
    AutoRoute(page: NotificationsRoute.page, path: '/notifications'),
    AutoRoute(
      page: MainRoute.page,
      path: '/',
      children: [
        AutoRoute(page: DashboardRoute.page, path: 'dashboard', initial: true),
        AutoRoute(page: DecksRoute.page, path: 'decks'),
        AutoRoute(page: CommunityHubRoute.page, path: 'community'),
        AutoRoute(page: StudyHubRoute.page, path: 'study'),
        AutoRoute(page: ProfileRoute.page, path: 'profile'),
      ],
    ),
  ];
}
