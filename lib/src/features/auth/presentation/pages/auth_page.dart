import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/social_auth_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_chat_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_form_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/breathing_campus_background.dart';
import 'package:kortex/src/features/auth/presentation/widgets/mode_switch_button.dart';
import 'package:kortex/src/features/auth/presentation/widgets/social_auth_bar.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class AuthPage extends HookWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: locator<AuthBloc>(),
        ),
        BlocProvider<AuthModeCubit>.value(
          value: locator<AuthModeCubit>(),
        ),
        BlocProvider<AuthDraftCubit>(
          create: (_) => AuthDraftCubit(),
        ),
      ],
      child: const _AuthView(),
    );
  }
}

Future<void> _handleGoogleSignIn(BuildContext context) async {
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
      context.showSnackBar(
        message: 'Google Sign-In failed: $e',
        type: SnackBarType.error,
      );
    }
  }
}

Future<void> _handleAppleSignIn(BuildContext context) async {
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
      context.showSnackBar(
        message: 'Apple Sign-In failed: $e',
        type: SnackBarType.error,
      );
    }
  }
}

class _AuthView extends HookWidget {
  const _AuthView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final authModeCubit = context.watch<AuthModeCubit>();
    final modeState = authModeCubit.state;
    final isChatMode = modeState.isChat;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state.status == AuthStatus.needsOnboarding && state.user != null) {
          if (!isChatMode) {
            context.showSnackBar(
              message: 'Account created! Welcome to Kortexify.',
            );
            unawaited(
              context.router.replace(const OnboardingCalibrationRoute()),
            );
          }
        } else if (state.isAuthenticated) {
          if (!isChatMode) {
            context.showSnackBar(message: l10n.authSuccessMessage);
            final calibRepo = locator<CalibrationRepository>();
            final calibResult = await calibRepo.getCalibrationProfile();
            final isCalibrated = calibResult.fold(
              (_) => false,
              (profile) => profile?.isCalibrated ?? false,
            );
            if (context.mounted) {
              if (isCalibrated) {
                unawaited(context.router.replaceAll([const MainRoute()]));
              } else {
                unawaited(
                  context.router.replace(const OnboardingCalibrationRoute()),
                );
              }
            }
          }
        } else if (state.isResetSent) {
          if (!isChatMode) {
            context.showSnackBar(
              message: 'Password reset link sent to your email.',
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
      child: Scaffold(
        backgroundColor: colors.surfacePrimary,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full-Screen Breathing Campus Atmosphere
            const Positioned.fill(
              child: BreathingCampusBackground(),
            ),

            // 2. Main Content Canvas
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                final isTablet =
                    constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

                if (isDesktop) {
                  return _DesktopSplitLayout(
                    isChatMode: isChatMode,
                  );
                }

                // Mobile & Tablet Layout
                return SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 560 : double.infinity,
                      ),
                      child: Column(
                        children: [
                          // ==========================================
                          // 1. TOP BAR (Brand Logo + Mode Switch)
                          // Sits directly on the background canvas
                          // ==========================================
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Brand Logo
                                Row(
                                  children: [
                                    AppAssets.svgs.kortexLogo.svg(
                                      width: 26,
                                      height: 26,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.appName,
                                      style: typography.caption.bold.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.4,
                                        fontSize: 14,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),

                                // Dual Mode Switch Button
                                ModeSwitchButton(
                                  isChatMode: isChatMode,
                                  onToggle: () {
                                    context.read<AuthModeCubit>().toggleMode();
                                  },
                                ),
                              ],
                            ),
                          ),

                          // ==========================================
                          // 2. DUAL VIEW CANVAS (Chat vs Form)
                          // Preserves Chat History Across Modes
                          // ==========================================
                          Expanded(
                            child: IndexedStack(
                              index: isChatMode ? 0 : 1,
                              children: [
                                AuthChatView(
                                  key: const ValueKey<String>('auth_chat_view'),
                                  onGooglePressed: () =>
                                      _handleGoogleSignIn(context),
                                  onApplePressed: () =>
                                      _handleAppleSignIn(context),
                                  onForgotPassword: () {
                                    unawaited(
                                      context.router.push(
                                        const ForgotPasswordRoute(),
                                      ),
                                    );
                                  },
                                ),
                                AuthFormView(
                                  key: const ValueKey<String>('auth_form_view'),
                                  onForgotPassword: () {
                                    unawaited(
                                      context.router.push(
                                        const ForgotPasswordRoute(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // ==========================================
                          // 3. BOTTOM SOCIAL AUTH BAR (Form Mode Only)
                          // ==========================================
                          if (!isChatMode)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                              child: SocialAuthBar(
                                isLoading: context
                                    .watch<AuthBloc>()
                                    .state
                                    .isLoading,
                                onGooglePressed: () =>
                                    _handleGoogleSignIn(context),
                                onApplePressed: () =>
                                    _handleAppleSignIn(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-column split layout for expanded screen sizes (Desktop / Web / 4K).
class _DesktopSplitLayout extends StatelessWidget {
  const _DesktopSplitLayout({
    required this.isChatMode,
  });

  final bool isChatMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Row(
      children: [
        // ==========================================
        // LEFT HERO PANEL (Campus Atmosphere & Value Prop)
        // ==========================================
        Expanded(
          flex: 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Animated Breathing Campus Background
              const BreathingCampusBackground(
                baseOpacity: 0.55,
              ),

              // Hero Copy & Badges
              Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Logo
                    Row(
                      children: [
                        AppAssets.svgs.kortexLogo.svg(
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.appName,
                          style: typography.headline.bold.copyWith(
                            letterSpacing: 2,
                            color: colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    // Value Propositions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.authDesktopHeroTitle,
                          style: typography.largeTitle.bold.copyWith(
                            color: colors.white,
                            fontSize: 36,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.authDesktopHeroSubtitle,
                          style: typography.body.regular.copyWith(
                            color: colors.white.withAlpha(220),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Features Bullets
                        _FeatureBullet(
                          icon: Icons.document_scanner_rounded,
                          text: l10n.authDesktopFeature1,
                        ),
                        const SizedBox(height: 14),
                        _FeatureBullet(
                          icon: Icons.auto_graph_rounded,
                          text: l10n.authDesktopFeature2,
                        ),
                        const SizedBox(height: 14),
                        _FeatureBullet(
                          icon: Icons.psychology_rounded,
                          text: l10n.authDesktopFeature3,
                        ),
                      ],
                    ),

                    // Footer Engine Tag
                    Text(
                      l10n.engineSubtitle,
                      style: typography.caption.semiBold.copyWith(
                        color: colors.white.withAlpha(160),
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ==========================================
        // RIGHT AUTH WORKSPACE (Form / Chat Dock)
        // ==========================================
        Expanded(
          flex: 4,
          child: Container(
            color: colors.surfacePrimary,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            child: Center(
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
                                ? 'Syllabot Assistant'
                                : 'Account Sign In',
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
                            key: const ValueKey<String>('chat_desktop'),
                            onGooglePressed: () => _handleGoogleSignIn(context),
                            onApplePressed: () => _handleAppleSignIn(context),
                            onForgotPassword: () {
                              unawaited(
                                context.router.push(
                                  const ForgotPasswordRoute(),
                                ),
                              );
                            },
                          ),
                          AuthFormView(
                            key: const ValueKey<String>('form_desktop'),
                            onForgotPassword: () {
                              unawaited(
                                context.router.push(
                                  const ForgotPasswordRoute(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Social Auth Dock
                    SocialAuthBar(
                      isLoading: context.watch<AuthBloc>().state.isLoading,
                      onGooglePressed: () => _handleGoogleSignIn(context),
                      onApplePressed: () => _handleAppleSignIn(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.white.withAlpha(35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: context.typography.callout.medium.copyWith(
              color: colors.white,
              fontSize: 14.5,
            ),
          ),
        ),
      ],
    );
  }
}
