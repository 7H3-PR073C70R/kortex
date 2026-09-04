import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_social_button.dart';
import 'package:kortex/src/features/auth/presentation/widgets/breathing_campus_background.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

@RoutePage()
class LoginPage extends HookWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isPasswordMode = useState<bool>(false);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.isFullyAuthenticated) {
          unawaited(context.router.replace(const MainRoute()));
        } else if (state.needsOnboarding) {
          unawaited(context.router.replace(const OnboardingStepperRoute()));
        } else if (state.status == AuthStatus.magicLinkSent) {
          context.showSnackBar(
            message: l10n.magicLinkSentNotice,
          );
        } else if (state.status == AuthStatus.error &&
            state.errorMessage != null) {
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark
              ? colors.backgroundPrimary
              : colors.surfacePrimary,
          body: Stack(
            children: [
              // Atmospheric campus backdrop
              const Positioned.fill(
                child: BreathingCampusBackground(),
              ),

              SafeArea(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 600;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 480 : double.infinity,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color:
                                  (isDark
                                          ? colors.surfaceSecondary
                                          : colors.surfacePrimary)
                                      .withAlpha(isDark ? 230 : 245),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 50 : 25,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isDark ? 70 : 20,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // App Brand Header
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withAlpha(40),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      l10n.engineSubtitle,
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Center(
                                  child: Text(
                                    l10n.welcomeTitle,
                                    style: typography.title1.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    l10n.welcomeSubtitle,
                                    textAlign: TextAlign.center,
                                    style: typography.footnote.regular.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Google Sign In Button
                                AuthSocialButton(
                                  label: l10n.signInWithGoogle,
                                  icon: Image.asset(
                                    'assets/icons/google_icon.png',
                                    width: 22,
                                    height: 22,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Icon(
                                              Icons.g_mobiledata_rounded,
                                              size: 26,
                                              color: colors.error,
                                            ),
                                  ),
                                  isLoading: state.isLoading,
                                  onTap: () {
                                    context.read<AuthBloc>().add(
                                      const AuthSocialLoginRequested(
                                        provider: 'google',
                                        idToken: 'demo_google_token',
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Apple Sign In Button
                                AuthSocialButton(
                                  label: l10n.signInWithApple,
                                  icon: Icon(
                                    Icons.apple_rounded,
                                    size: 24,
                                    color: colors.textPrimary,
                                  ),
                                  isLoading: state.isLoading,
                                  onTap: () {
                                    context.read<AuthBloc>().add(
                                      const AuthSocialLoginRequested(
                                        provider: 'apple',
                                        idToken: 'demo_apple_token',
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Divider
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: colors.textSecondary.withAlpha(
                                          60,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'or email',
                                        style: typography.caption.medium
                                            .copyWith(
                                              color: colors.textSecondary,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: colors.textSecondary.withAlpha(
                                          60,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Email Input
                                AppTextField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  hintText: l10n.authEmailHint,
                                  label: l10n.authEmailLabel,
                                ),

                                if (isPasswordMode.value) ...[
                                  const SizedBox(height: 12),
                                  AppTextField(
                                    controller: passwordController,
                                    isPassword: true,
                                    label: l10n.authPasswordLabel,
                                    hintText: l10n.authPasswordHint,
                                  ),
                                ],

                                const SizedBox(height: 20),

                                // Primary Action (Magic Link or Password)
                                AppButton(
                                  text: isPasswordMode.value
                                      ? l10n.authSubmitLogin
                                      : l10n.sendMagicLink,
                                  isLoading: state.isLoading,
                                  onPressed: state.isLoading
                                      ? null
                                      : () {
                                          final email = emailController.text
                                              .trim();
                                          if (email.isEmpty) return;

                                          if (isPasswordMode.value) {
                                            context.read<AuthBloc>().add(
                                              AuthLoginRequested(
                                                email: email,
                                                password:
                                                    passwordController.text,
                                              ),
                                            );
                                          } else {
                                            context.read<AuthBloc>().add(
                                              AuthMagicLinkRequested(
                                                email: email,
                                              ),
                                            );
                                          }
                                        },
                                ),
                                const SizedBox(height: 14),

                                // Toggle Password vs Magic Link
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      isPasswordMode.value =
                                          !isPasswordMode.value;
                                    },
                                    child: Text(
                                      isPasswordMode.value
                                          ? l10n.authUseMagicLinkInstead
                                          : l10n.authUsePasswordInstead,
                                      style: typography.footnote.bold.copyWith(
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
