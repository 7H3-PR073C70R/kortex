import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/dynamic_link_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';

/// AutoRouter guard directing users based on their active authentication
/// and onboarding session status.
class AuthRouteGuard extends AutoRouteGuard {
  AuthRouteGuard(this._authBloc, this._userStorageService);

  final AuthBloc _authBloc;
  final UserStorageService _userStorageService;

  @override
  Future<void> onNavigation(NavigationResolver resolver, StackRouter router) async {
    final currentRouteName = resolver.routeName;

    // SplashRoute is always unconditionally accessible
    if (currentRouteName == SplashRoute.name) {
      resolver.next();
      return;
    }

    final hasSession = _userStorageService.hasActiveSession();
    final status = _authBloc.state.sessionStatus;

    // 1. If not authenticated at all (no active session in storage)
    if (!hasSession) {
      if (currentRouteName == AuthRoute.name ||
          currentRouteName == OnboardingRoute.name ||
          currentRouteName == ForgotPasswordRoute.name ||
          currentRouteName == OtpVerificationRoute.name) {
        resolver.next();
      } else {
        resolver.next(false);
        locator<AuthModeCubit>().resetToLogin();
        unawaited(router.replace(const AuthRoute()));
      }
      return;
    }

    // 2. User has an active token or session: route appropriately
    switch (status) {
      case AuthSessionStatus.authenticatedNeedsOnboarding:
        final serverSaysOnboarded =
            _authBloc.state.userProfile?.isOnboarded ?? false;
        final isCalibratedLocally = () {
          try {
            final storage = locator<LocalStorageService>();
            if (storage.getPreference(key: PrefKeys.hasCompletedOnboarding) ==
                'true') {
              return true;
            }
            final rawCalib = storage.getPreference(
              key: '__calibration_profile',
            );
            if (rawCalib != null && rawCalib.isNotEmpty) {
              final map = jsonDecode(rawCalib) as Map<String, dynamic>;
              if (map['isCalibrated'] == true) return true;
            }
            final rawCourses = storage.getPreference(
              key: PrefKeys.userCuratedCourses,
            );
            if (rawCourses != null && rawCourses.isNotEmpty) {
              final list = jsonDecode(rawCourses) as List<dynamic>;
              if (list.isNotEmpty) return true;
            }
          } on Object catch (_) {}
          return false;
        }();

        var isCalibrated = serverSaysOnboarded || isCalibratedLocally;

        if (!isCalibrated && locator.isRegistered<AuthRepository>()) {
          try {
            final profileRes = await locator<AuthRepository>().getUserProfile();
            profileRes.fold(
              (_) {},
              (profile) {
                if (profile.isOnboarded) {
                  isCalibrated = true;
                }
              },
            );
          } on Object catch (_) {}
        }

        if (!isCalibrated && locator.isRegistered<DashboardRepository>()) {
          try {
            final coursesRes =
                await locator<DashboardRepository>().getUserCuratedCourses();
            coursesRes.fold(
              (_) {},
              (courses) {
                if (courses.isNotEmpty) {
                  isCalibrated = true;
                }
              },
            );
          } on Object catch (_) {}
        }

        if (isCalibrated) {
          try {
            final storage = locator<LocalStorageService>();
            await storage.savePreference(
              key: PrefKeys.hasCompletedOnboarding,
              data: 'true',
            );
          } on Object catch (_) {}
          _authBloc.add(
            const AuthStatusChanged(AuthSessionStatus.authenticatedComplete),
          );
          if (currentRouteName == AuthRoute.name ||
              currentRouteName == OnboardingRoute.name ||
              currentRouteName == ForgotPasswordRoute.name ||
              currentRouteName == OnboardingCalibrationRoute.name) {
            resolver.next(false);
            if (locator.isRegistered<DynamicLinkService>() &&
                locator<DynamicLinkService>().pendingPayload != null) {
              final linkService = locator<DynamicLinkService>();
              final payload = linkService.pendingPayload!;
              linkService.clearPendingPayload();
              final targetRoute = linkService.routeForPayload(payload);
              if (targetRoute != null) {
                unawaited(router.replaceAll([const MainRoute(), targetRoute]));
                return;
              }
            }
            unawaited(router.replace(const MainRoute()));
          } else {
            resolver.next();
          }
          return;
        }

        if (currentRouteName == OnboardingCalibrationRoute.name ||
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
        if (_authBloc.state.status == AuthStatus.initial) {
          _authBloc.add(const AuthCheckRequested());
        }
        final cachedProfile = _userStorageService.getCachedUserProfile();
        final isCalibrated = cachedProfile?.isOnboarded ?? false;
        if ((currentRouteName == AuthRoute.name ||
                currentRouteName == OnboardingRoute.name) &&
            isCalibrated) {
          resolver.next(false);
          unawaited(router.replace(const MainRoute()));
        } else {
          resolver.next();
        }
    }
  }
}
