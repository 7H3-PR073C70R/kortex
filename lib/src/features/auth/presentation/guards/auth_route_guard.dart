import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';

/// AutoRouter guard directing users based on their active authentication
/// and onboarding session status.
class AuthRouteGuard extends AutoRouteGuard {
  AuthRouteGuard(this._authBloc, this._userStorageService);

  final AuthBloc _authBloc;
  final UserStorageService _userStorageService;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final currentRouteName = resolver.routeName;

    // SplashRoute is always unconditionally accessible
    if (currentRouteName == SplashRoute.name) {
      resolver.next();
      return;
    }

    final hasToken = _userStorageService.getToken()?.isNotEmpty ?? false;
    final status = _authBloc.state.sessionStatus;

    // 1. If not authenticated at all (no stored token and unauthenticated in state)
    if (!hasToken && status == AuthSessionStatus.unauthenticated) {
      if (currentRouteName == AuthRoute.name ||
          currentRouteName == OnboardingRoute.name ||
          currentRouteName == ForgotPasswordRoute.name ||
          currentRouteName == OtpVerificationRoute.name) {
        resolver.next();
      } else {
        resolver.next(false);
        unawaited(router.replace(const AuthRoute()));
      }
      return;
    }

    // 2. User has an active token or session: route appropriately
    switch (status) {
      case AuthSessionStatus.authenticatedNeedsOnboarding:
        final isCalibratedLocally = () {
          try {
            final storage = locator<LocalStorageService>();
            if (storage.getPreference(key: PrefKeys.hasCompletedOnboarding) == 'true') {
              return true;
            }
            final rawCalib = storage.getPreference(key: '__calibration_profile');
            if (rawCalib != null && rawCalib.isNotEmpty) {
              final map = jsonDecode(rawCalib) as Map<String, dynamic>;
              if (map['isCalibrated'] == true) return true;
            }
          } on Object catch (_) {}
          return false;
        }();

        if (isCalibratedLocally) {
          _authBloc.add(
            const AuthStatusChanged(AuthSessionStatus.authenticatedComplete),
          );
          if (currentRouteName == AuthRoute.name ||
              currentRouteName == OnboardingRoute.name ||
              currentRouteName == OnboardingCalibrationRoute.name) {
            resolver.next(false);
            unawaited(router.replace(const MainRoute()));
          } else {
            resolver.next();
          }
          return;
        }

        if (currentRouteName == OnboardingCalibrationRoute.name ||
            currentRouteName == OnboardingContentRoute.name ||
            currentRouteName == PermissionsRoute.name) {
          resolver.next();
        } else {
          resolver.next(false);
          unawaited(router.replace(const OnboardingCalibrationRoute()));
        }
      case AuthSessionStatus.authenticatedComplete:
        // Prevent navigating back to Auth or intro onboarding slides when already authenticated
        if (currentRouteName == AuthRoute.name ||
            currentRouteName == OnboardingRoute.name) {
          resolver.next(false);
          unawaited(router.replace(const MainRoute()));
        } else {
          resolver.next();
        }
      case AuthSessionStatus.unauthenticated:
        // Token exists in storage but AuthBloc is still initializing.
        // Allow the route determined by Splash screen without premature redirection.
        resolver.next();
    }
  }
}
