import 'package:auto_route/auto_route.dart';
import 'package:kortex/src/shared/wrappers/main_page.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: MainRoute.page, initial: true),
      ];
}
