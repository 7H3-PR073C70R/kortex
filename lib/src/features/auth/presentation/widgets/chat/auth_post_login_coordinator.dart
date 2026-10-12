import 'dart:async';
import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/social_auth_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';

/// Coordinator decoupling post-login onboarding calibration checks,
/// local user storage operations, and social authentication from UI widgets.
class AuthPostLoginCoordinator {
  const AuthPostLoginCoordinator({
    this.localStorageService,
    this.authRepository,
    this.calibrationRepository,
    this.dashboardRepository,
    this.userStorageService,
    this.socialAuthService,
  });

  final LocalStorageService? localStorageService;
  final AuthRepository? authRepository;
  final CalibrationRepository? calibrationRepository;
  final DashboardRepository? dashboardRepository;
  final UserStorageService? userStorageService;
  final SocialAuthService? socialAuthService;

  LocalStorageService? get _localStorageService =>
      localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  AuthRepository? get _authRepository =>
      authRepository ??
      (locator.isRegistered<AuthRepository>()
          ? locator<AuthRepository>()
          : null);

  CalibrationRepository? get _calibrationRepository =>
      calibrationRepository ??
      (locator.isRegistered<CalibrationRepository>()
          ? locator<CalibrationRepository>()
          : null);

  DashboardRepository? get _dashboardRepository =>
      dashboardRepository ??
      (locator.isRegistered<DashboardRepository>()
          ? locator<DashboardRepository>()
          : null);

  UserStorageService? get _userStorageService =>
      userStorageService ??
      (locator.isRegistered<UserStorageService>()
          ? locator<UserStorageService>()
          : null);

  SocialAuthService? get _socialAuthService =>
      socialAuthService ??
      (locator.isRegistered<SocialAuthService>()
          ? locator<SocialAuthService>()
          : null);

  /// Saves the user's display name to persistent user storage.
  Future<void> saveUserDisplayName(String name) async {
    final storage = _userStorageService;
    if (storage != null && name.trim().isNotEmpty) {
      try {
        await storage.saveUserDisplayName(name.trim());
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }
  }

  /// Checks whether a newly registered flag is present in local storage.
  bool isNewlyRegistered() {
    final storage = _localStorageService;
    if (storage == null) return false;
    try {
      return storage.getPreference(key: PrefKeys.isNewlyRegistered) == 'true';
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
      return false;
    }
  }

  /// Evaluates multi-tier onboarding calibration status for returning users.
  Future<bool> checkIsCalibrated(AuthState state) async {
    var serverSaysOnboarded = state.userProfile?.isOnboarded ?? false;
    final authRepo = _authRepository;
    if (!serverSaysOnboarded && authRepo != null) {
      try {
        final profileRes = await authRepo.getUserProfile();
        profileRes.fold(
          (_) {},
          (profile) {
            if (profile.isOnboarded) {
              serverSaysOnboarded = true;
            }
          },
        );
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    var localSaysOnboarded = false;
    final storage = _localStorageService;
    if (storage != null) {
      try {
        localSaysOnboarded =
            storage.getPreference(key: PrefKeys.hasCompletedOnboarding) ==
            'true';
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    var calibSaysOnboarded = false;
    final calibRepo = _calibrationRepository;
    if (!serverSaysOnboarded && !localSaysOnboarded && calibRepo != null) {
      try {
        final calibResult = await calibRepo.getCalibrationProfile();
        calibSaysOnboarded = calibResult.fold(
          (_) => false,
          (profile) => profile?.isCalibrated ?? false,
        );
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    var coursesSayOnboarded = false;
    if (!serverSaysOnboarded &&
        !localSaysOnboarded &&
        !calibSaysOnboarded) {
      if (storage != null) {
        try {
          final rawCourses = storage.getPreference(
            key: PrefKeys.userCuratedCourses,
          );
          if (rawCourses != null && rawCourses.isNotEmpty) {
            final list = jsonDecode(rawCourses) as List<dynamic>;
            if (list.isNotEmpty) coursesSayOnboarded = true;
          }
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }
      }

      final dashRepo = _dashboardRepository;
      if (!coursesSayOnboarded && dashRepo != null) {
        try {
          final coursesRes = await dashRepo.getUserCuratedCourses();
          coursesSayOnboarded = coursesRes.fold(
            (_) => false,
            (courses) => courses.isNotEmpty,
          );
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }
      }
    }

    final isCalibrated =
        serverSaysOnboarded ||
        localSaysOnboarded ||
        calibSaysOnboarded ||
        coursesSayOnboarded;

    if (isCalibrated && storage != null) {
      try {
        unawaited(
          storage.savePreference(
            key: PrefKeys.hasCompletedOnboarding,
            data: 'true',
          ),
        );
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    return isCalibrated;
  }

  /// Triggers Apple Sign-In through the social authentication service.
  Future<SocialAuthResult?> signInWithApple() async {
    final socialService = _socialAuthService;
    if (socialService == null) return null;
    try {
      return await socialService.signInWithApple();
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
      return null;
    }
  }
}
