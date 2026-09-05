import 'package:auto_route/auto_route.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SplashRoute.page, initial: true),
    AutoRoute(page: OnboardingRoute.page),
    AutoRoute(page: AuthRoute.page),
    AutoRoute(page: LoginRoute.page),
    AutoRoute(page: ForgotPasswordRoute.page),
    AutoRoute(page: OtpVerificationRoute.page),
    AutoRoute(page: OnboardingStepperRoute.page),
    AutoRoute(page: OnboardingWrapperRoute.page),
    AutoRoute(page: OnboardingCalibrationRoute.page),
    AutoRoute(page: OnboardingContentRoute.page),
    AutoRoute(page: PermissionsRoute.page),
    AutoRoute(page: DeckDetailRoute.page),
    AutoRoute(page: StudySessionRoute.page),
    AutoRoute(page: SessionSummaryRoute.page),
    AutoRoute(page: MockExamLobbyRoute.page),
    AutoRoute(page: AnalyticsDetailRoute.page),
    AutoRoute(page: CourseModuleRoute.page),
    AutoRoute(page: CurateCoursesRoute.page),
    AutoRoute(page: AllCuratedCoursesRoute.page),
    AutoRoute(page: DocumentIngestionRoute.page),
    AutoRoute(page: OcrPreviewRoute.page),
    AutoRoute(page: GeneratedCardsReviewRoute.page),
    AutoRoute(page: LiveStudyRoomRoute.page),
    AutoRoute(page: ForumThreadDetailRoute.page),
    AutoRoute(page: DeckMarketplaceDetailRoute.page),
    AutoRoute(page: UserProfileRoute.page),
    AutoRoute(page: TwoFactorSetupRoute.page),
    AutoRoute(page: PastQuestionsBoardRoute.page),
    AutoRoute(page: QuizWorkspaceRoute.page),
    AutoRoute(page: QuizResultsRoute.page),
    AutoRoute(page: PaywallRoute.page),
    AutoRoute(page: SyllabotChatRoute.page),
    AutoRoute(
      page: MainRoute.page,
      children: [
        AutoRoute(page: DashboardRoute.page),
        AutoRoute(page: DecksRoute.page),
        AutoRoute(page: CommunityHubRoute.page),
        AutoRoute(page: ProfileRoute.page),
      ],
    ),
  ];
}
