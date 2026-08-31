import 'package:auto_route/auto_route.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SplashRoute.page, initial: true),
    AutoRoute(page: OnboardingRoute.page),
    AutoRoute(page: AuthRoute.page),
    AutoRoute(page: ForgotPasswordRoute.page),
    AutoRoute(page: OtpVerificationRoute.page),
    AutoRoute(page: OnboardingCalibrationRoute.page),
    AutoRoute(page: OnboardingContentRoute.page),
    AutoRoute(page: PermissionsRoute.page),
    AutoRoute(page: DeckDetailRoute.page),
    AutoRoute(page: MockExamLobbyRoute.page),
    AutoRoute(page: AnalyticsDetailRoute.page),
    AutoRoute(page: CourseModuleRoute.page),
    AutoRoute(
      page: MainRoute.page,
      children: [
        AutoRoute(page: DashboardRoute.page),
        AutoRoute(page: SyllabotChatRoute.page),
        AutoRoute(page: DecksRoute.page),
        AutoRoute(page: CommunityRoute.page),
        AutoRoute(page: ProfileRoute.page),
      ],
    ),
  ];
}
