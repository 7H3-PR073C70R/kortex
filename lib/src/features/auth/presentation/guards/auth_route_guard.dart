import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';

/// AutoRouter guard directing users based on their active authentication
/// and onboarding session status.
class AuthRouteGuard extends AutoRouteGuard {
  AuthRouteGuard(this._authBloc);

  final AuthBloc _authBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final status = _authBloc.state.sessionStatus;
    final currentRouteName = resolver.routeName;

    switch (status) {
      case AuthSessionStatus.unauthenticated:
        if (currentRouteName == LoginRoute.name ||
            currentRouteName == AuthRoute.name ||
            currentRouteName == OnboardingRoute.name ||
            currentRouteName == SplashRoute.name ||
            currentRouteName == ForgotPasswordRoute.name ||
            currentRouteName == OtpVerificationRoute.name) {
          resolver.next();
        } else {
          resolver.next(false);
          unawaited(router.replace(const LoginRoute()));
        }
      case AuthSessionStatus.authenticatedNeedsOnboarding:
        if (currentRouteName == OnboardingStepperRoute.name) {
          resolver.next();
        } else {
          resolver.next(false);
          unawaited(router.replace(const OnboardingStepperRoute()));
        }
      case AuthSessionStatus.authenticatedComplete:
        if (currentRouteName == LoginRoute.name ||
            currentRouteName == AuthRoute.name ||
            currentRouteName == OnboardingStepperRoute.name) {
          resolver.next(false);
          unawaited(router.replace(const MainRoute()));
        } else {
          resolver.next();
        }
    }
  }
}
