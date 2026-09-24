import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_chat_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_flow_panel.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_form_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_shell.dart';
import 'package:kortex/src/features/auth/presentation/widgets/breathing_campus_background.dart';
import 'package:kortex/src/features/auth/presentation/widgets/mode_switch_button.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

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

class _AuthView extends HookWidget {
  const _AuthView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final authModeCubit = context.watch<AuthModeCubit>();
    final modeState = authModeCubit.state;
    final isChatMode = modeState.isChat;

    return AuthNavigationListener(
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
                  return const _DesktopSplitLayout();
                }

                // Mobile & Tablet Layout
                if (isChatMode) {
                  return SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 560 : 480,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const RevealOnMount(
                                    child: AuthBrandLockup(),
                                  ),
                                  RevealOnMount(
                                    delayMs: 90,
                                    child: ModeSwitchButton(
                                      isChatMode: isChatMode,
                                      onToggle: () {
                                        context
                                            .read<AuthModeCubit>()
                                            .toggleMode();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: RevealOnMount(
                                delayMs: 150,
                                child: AuthChatView(
                                  key: const ValueKey<String>(
                                    'auth_chat_view',
                                  ),
                                  onGooglePressed: () =>
                                      authGoogleSignIn(context),
                                  onApplePressed: () =>
                                      authAppleSignIn(context),
                                  onForgotPassword: () {
                                    unawaited(
                                      context.router.push(
                                        const ForgotPasswordRoute(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Quick Form Mode: extends full-bleed to device screen edges
                // covering app bar and status bar without horizontal sharp cuts
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 560 : 480,
                    ),
                    child: RevealOnMount(
                      delayMs: 150,
                      child: AuthFormView(
                        key: const ValueKey<String>(
                          'auth_form_view',
                        ),
                        onForgotPassword: () {
                          unawaited(
                            context.router.push(
                              const ForgotPasswordRoute(),
                            ),
                          );
                        },
                        onGooglePressed: () =>
                            authGoogleSignIn(context),
                        onApplePressed: () =>
                            authAppleSignIn(context),
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
  const _DesktopSplitLayout();

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
              // Animated Breathing Campus Background (white hero copy sits
              // on top, so use the dark cinematic veil).
              const BreathingCampusBackground(
                baseOpacity: 0.8,
                foregroundIsLight: true,
              ),

              // Hero Copy & Badges
              Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Logo
                    const AuthBrandLockup(
                      size: BrandLockupSize.large,
                      onLightSurface: true,
                    ),

                    // Value Propositions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.authDesktopHeroTitle,
                          style: typography.largeTitle.bold.copyWith(
                            color: colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.authDesktopHeroSubtitle,
                          style: typography.body.regular.copyWith(
                            color: colors.white.withAlpha(220),
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
            child: const AuthWorkspacePanel(),
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
    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isHovered ? colors.white.withAlpha(25) : colors.transparent,
            borderRadius: AppRadius.radiusCard,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHovered
                      ? colors.white.withAlpha(55)
                      : colors.white.withAlpha(35),
                  borderRadius: AppRadius.concentricBorderRadius(
                    AppRadius.card,
                    4,
                  ),
                ),
                child: Icon(icon, size: 18, color: colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: context.typography.callout.medium.copyWith(
                    color: colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
