import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_shell.dart';
import 'package:kortex/src/features/auth/presentation/widgets/breathing_campus_background.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class ForgotPasswordPage extends HookWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final emailController = useTextEditingController();
    final authState = context.watch<AuthBloc>().state;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.isResetSent) {
          context.showSnackBar(
            message: l10n.authSubmitReset,
          );
          unawaited(context.router.maybePop());
        } else if (state.status == AuthStatus.error &&
            state.errorMessage != null) {
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Shared breathing campus atmosphere.
            const Positioned.fill(
              child: BreathingCampusBackground(),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Top bar: a circular back control floats left while the
                  // brand sits centered on the same optical axis — a proper
                  // premium nav bar rather than a left-crammed row.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: SizedBox(
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: RevealOnMount(
                              child: _GlassBackButton(
                                onTap: () =>
                                    unawaited(context.router.maybePop()),
                              ),
                            ),
                          ),
                          const RevealOnMount(
                            delayMs: 60,
                            child: AuthBrandLockup(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: RevealOnMount(
                      delayMs: 130,
                      slideY: 0.06,
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: GlassSurface(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Identity badge for the reset task.
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.primary.withAlpha(
                                        isDark ? 42 : 22,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.lock_reset_rounded,
                                      color: colors.primary,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.authForgotPasswordTitle,
                                    style: typography.title2.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    l10n.authForgotPasswordSubtitle,
                                    style: typography.callout.regular.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  AppTextField(
                                    label: l10n.authEmailLabel,
                                    hintText: l10n.authEmailHint,
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: const Icon(
                                      Icons.mail_outline_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  AppButton.primary(
                                    text: l10n.authSubmitReset,
                                    isLoading: authState.isLoading,
                                    onPressed: () {
                                      final email = emailController.text.trim();
                                      if (email.isNotEmpty) {
                                        context.read<AuthBloc>().add(
                                          AuthResetPasswordRequested(
                                            email: email,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact frosted back control that matches the auth flow's glass language.
class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isHovered
                    ? (isDark
                          ? colors.surfaceSecondary.withAlpha(210)
                          : colors.surfacePrimary)
                    : (isDark
                          ? colors.surfaceSecondary.withAlpha(150)
                          : colors.surfacePrimary.withAlpha(205)),
                border: Border.all(
                  color: isHovered
                      ? colors.primary.withAlpha(140)
                      : (isDark
                            ? colors.surfaceBorderHighlight.withAlpha(90)
                            : colors.surfaceBorder.withAlpha(150)),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: colors.textPrimary,
              ),
            ),
          );
        },
      ),
    );
  }
}
