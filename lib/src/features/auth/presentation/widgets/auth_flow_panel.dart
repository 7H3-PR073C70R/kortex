import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/social_auth_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_chat_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_form_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/mode_switch_button.dart';
import 'package:kortex/src/features/auth/presentation/widgets/social_auth_bar.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/l10n/l10n.dart';

// -----------------------------------------------------------------------------
// Shared auth-flow building blocks.
//
// These live here so the desktop Auth page and the wide-screen Onboarding
// split layout drive sign-in with one single source of truth: one navigation
// listener, one social sign-in bridge, and one auth workspace panel.
// -----------------------------------------------------------------------------

/// Streams a Google credential into the active [AuthBloc].
Future<void> authGoogleSignIn(BuildContext context) async {
  try {
    final result = await locator<SocialAuthService>().signInWithGoogle();
    if (result != null && context.mounted) {
      context.read<AuthBloc>().add(
        AuthSocialLoginRequested(
          provider: result.provider,
          idToken: result.idToken,
        ),
      );
    }
  } on Object catch (e) {
    if (context.mounted) {
      final message = e is SocialAuthException
          ? e.message
          : 'Google Sign-In failed: $e';
      context.showSnackBar(
        message: message,
        type: SnackBarType.error,
      );
    }
  }
}

/// Streams an Apple credential into the active [AuthBloc].
Future<void> authAppleSignIn(BuildContext context) async {
  try {
    final result = await locator<SocialAuthService>().signInWithApple();
    if (result != null && context.mounted) {
      context.read<AuthBloc>().add(
        AuthSocialLoginRequested(
          provider: result.provider,
          idToken: result.idToken,
          rawNonce: result.rawNonce,
        ),
      );
    }
  } on Object catch (e) {
    if (context.mounted) {
      final message = e is SocialAuthException
          ? e.message
          : 'Apple Sign-In failed: $e';
      context.showSnackBar(
        message: message,
        type: SnackBarType.error,
      );
    }
  }
}

/// Routes the app in response to [AuthBloc] state transitions.
///
/// Wraps any screen that hosts live auth widgets (Auth page on every
/// viewport, the wide Onboarding split) so a successful sign-in always
/// lands on the same destination: Main when the profile is already
/// calibrated, Calibration otherwise, plus OTP / error side effects.
class AuthNavigationListener extends StatelessWidget {
  const AuthNavigationListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        final isChatMode = context.read<AuthModeCubit>().state.isChat;

        final isNewlyRegistered =
            locator.isRegistered<LocalStorageService>() &&
            locator<LocalStorageService>().getPreference(
                  key: PrefKeys.isNewlyRegistered,
                ) ==
                'true';

        if (state.status == AuthStatus.needsOnboarding && state.user != null) {
          if (!isChatMode) {
            if (isNewlyRegistered) {
              context.showSnackBar(
                message: context.l10n.authAccountCreatedWelcome,
              );
            }
            unawaited(
              context.router.replace(const OnboardingCalibrationRoute()),
            );
          }
        } else if (state.isAuthenticated) {
          if (!isChatMode) {
            final l10n = context.l10n;
            context.showSnackBar(message: l10n.authSuccessMessage);

            // 1. Fast path: check if server-verified profile says user is onboarded
            final serverSaysOnboarded = state.userProfile?.isOnboarded ?? false;

            // 2. Local pref key set by CalibrationLocalDataSourceImpl.saveCalibrationProfile
            var localSaysOnboarded = false;
            try {
              final storage = locator<LocalStorageService>();
              localSaysOnboarded =
                  storage.getPreference(
                    key: PrefKeys.hasCompletedOnboarding,
                  ) ==
                  'true';
            } on Object catch (_) {}

            // 3. Fallback: read calibration profile from local storage
            var calibSaysOnboarded = false;
            if (!serverSaysOnboarded && !localSaysOnboarded) {
              final calibRepo = locator<CalibrationRepository>();
              final calibResult = await calibRepo.getCalibrationProfile();
              calibSaysOnboarded = calibResult.fold(
                (_) => false,
                (profile) => profile?.isCalibrated ?? false,
              );
            }

            // 4. Remote/local curated courses check for new device logins
            var coursesSayOnboarded = false;
            if (!serverSaysOnboarded &&
                !localSaysOnboarded &&
                !calibSaysOnboarded) {
              try {
                final storage = locator<LocalStorageService>();
                final rawCourses = storage.getPreference(
                  key: PrefKeys.userCuratedCourses,
                );
                if (rawCourses != null && rawCourses.isNotEmpty) {
                  final list = jsonDecode(rawCourses) as List<dynamic>;
                  if (list.isNotEmpty) coursesSayOnboarded = true;
                }
              } on Object catch (_) {}

              if (!coursesSayOnboarded &&
                  locator.isRegistered<DashboardRepository>()) {
                try {
                  final dashRepo = locator<DashboardRepository>();
                  final coursesRes = await dashRepo.getUserCuratedCourses();
                  coursesSayOnboarded = coursesRes.fold(
                    (_) => false,
                    (courses) => courses.isNotEmpty,
                  );
                } on Object catch (_) {}
              }
            }

            final shouldGoToMain =
                serverSaysOnboarded ||
                localSaysOnboarded ||
                calibSaysOnboarded ||
                coursesSayOnboarded;

            if (shouldGoToMain) {
              try {
                final storage = locator<LocalStorageService>();
                unawaited(
                  storage.savePreference(
                    key: PrefKeys.hasCompletedOnboarding,
                    data: 'true',
                  ),
                );
              } on Object catch (_) {}
            }

            if (context.mounted) {
              if (shouldGoToMain) {
                unawaited(context.router.replaceAll([const MainRoute()]));
              } else {
                unawaited(
                  context.router.replace(const OnboardingCalibrationRoute()),
                );
              }
            }
          }
        } else if (state.status == AuthStatus.needsEmailVerification) {
          final email = state.user?.email ?? '';
          if (email.isNotEmpty) {
            unawaited(
              context.router.push(OtpVerificationRoute(email: email)),
            );
          }
        } else if (state.isResetSent) {
          if (!isChatMode) {
            context.showSnackBar(
              message: context.l10n.authPasswordResetSuccess,
            );
          }
        } else if (state.status == AuthStatus.error &&
            state.errorMessage != null) {
          if (!isChatMode) {
            context.showSnackBar(
              message: state.errorMessage!,
              type: SnackBarType.error,
            );
          }
        }
      },
      child: child,
    );
  }
}

/// The full auth workspace: mode switch header, chat/form canvas, and the
/// social auth dock. Shared by the Auth desktop split and the wide-screen
/// Onboarding split so both surfaces stay behaviorally identical.
///
/// Assumes the auth bloc stack ([AuthBloc], [AuthModeCubit], and the draft
/// cubit) is provided above it, and that it is wrapped in an
/// [AuthNavigationListener].
class AuthWorkspacePanel extends StatelessWidget {
  const AuthWorkspacePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final isChatMode = context.watch<AuthModeCubit>().state.isChat;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            // Mode Switch Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isChatMode
                        ? l10n.authSyllabotAssistantTitle
                        : l10n.authAccountSignInTitle,
                    style: typography.headline.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ModeSwitchButton(
                  isChatMode: isChatMode,
                  onToggle: () {
                    context.read<AuthModeCubit>().toggleMode();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Active Auth Body
            // (Preserves state and conversation across modes)
            Expanded(
              child: IndexedStack(
                index: isChatMode ? 0 : 1,
                children: [
                  AuthChatView(
                    key: const ValueKey<String>('auth_workspace_chat'),
                    onGooglePressed: () => authGoogleSignIn(context),
                    onApplePressed: () => authAppleSignIn(context),
                    onForgotPassword: () {
                      context.router.push(const ForgotPasswordRoute());
                    },
                  ),
                  AuthFormView(
                    key: const ValueKey<String>('auth_workspace_form'),
                    onForgotPassword: () {
                      context.router.push(const ForgotPasswordRoute());
                    },
                    onGooglePressed: () => authGoogleSignIn(context),
                    onApplePressed: () => authAppleSignIn(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Social Auth Dock
            SocialAuthBar(
              isLoading: context.watch<AuthBloc>().state.isLoading,
              onGooglePressed: () => authGoogleSignIn(context),
              onApplePressed: () => authAppleSignIn(context),
            ),
          ],
        ),
      ),
    );
  }
}
