import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Fast, high-contrast input form with floating glassmorphic card over the
/// full-screen campus backdrop.
class AuthFormView extends HookWidget {
  const AuthFormView({
    required this.onForgotPassword,
    super.key,
  });

  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final draftCubit = context.read<AuthDraftCubit>();
    final draftState = context.watch<AuthDraftCubit>().state;
    final authMode = context.watch<AuthModeCubit>().state;
    final isRegister = authMode.formType == AuthFormType.register;

    final emailController = useTextEditingController(text: draftState.email);
    final passwordController = useTextEditingController(
      text: draftState.password,
    );
    final nameController = useTextEditingController(
      text: draftState.displayName,
    );
    final otpController = useTextEditingController();

    useEffect(
      () {
        if (emailController.text != draftState.email) {
          emailController.text = draftState.email;
        }
        if (passwordController.text != draftState.password) {
          passwordController.text = draftState.password;
        }
        if (nameController.text != draftState.displayName) {
          nameController.text = draftState.displayName;
        }
        return null;
      },
      [draftState.email, draftState.password, draftState.displayName],
    );

    useEffect(
      () {
        void listener() {
          draftCubit
            ..updateEmail(emailController.text)
            ..updatePassword(passwordController.text)
            ..updateDisplayName(nameController.text);
        }

        emailController.addListener(listener);
        passwordController.addListener(listener);
        nameController.addListener(listener);
        return () {
          emailController.removeListener(listener);
          passwordController.removeListener(listener);
          nameController.removeListener(listener);
        };
      },
      [emailController, passwordController, nameController],
    );

    void handleSubmit() {
      final email = emailController.text.trim();
      final password = passwordController.text;
      final name = nameController.text.trim();

      if (email.isEmpty || password.isEmpty) return;

      if (isRegister) {
        context.read<AuthBloc>().add(
          AuthRegisterRequested(
            email: email,
            password: password,
            displayName: name.isNotEmpty ? name : null,
          ),
        );
      } else {
        context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: email,
            password: password,
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(160)
                          : colors.surfacePrimary.withAlpha(210),
                      border: Border.all(
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(80)
                            : colors.surfaceBorder.withAlpha(140),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 60 : 20),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (context.watch<AuthBloc>().state.status ==
                                AuthStatus.needsEmailVerification &&
                            isRegister) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.primary.withAlpha(80),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.pin_outlined,
                                  size: 38,
                                  color: colors.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Verify Your Account',
                                  style: typography.headline.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Enter the 6-digit code sent to your email '
                                  '(${emailController.text}).',
                                  textAlign: TextAlign.center,
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  label: '6-Digit OTP Code',
                                  hintText: '123456',
                                  controller: otpController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AppButton(
                                  text: 'Verify Code',
                                  onPressed: () {
                                    final otp = otpController.text.trim();
                                    if (otp.length == 6) {
                                      context.read<AuthBloc>().add(
                                        AuthVerifyOtpRequested(
                                          email: emailController.text.trim(),
                                          token: otp,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    context.read<AuthModeCubit>().setFormType(
                                      AuthFormType.login,
                                    );
                                  },
                                  child: Text(
                                    'Switch to Sign In',
                                    style: typography.caption.medium.copyWith(
                                      color: colors.primary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        // Registration Display Name Field
                        if (isRegister) ...[
                          Semantics(
                            textField: true,
                            label: l10n.authDisplayNameLabel,
                            hint: 'Enter your full name',
                            child: AppTextField(
                              label: l10n.authDisplayNameLabel,
                              hintText: l10n.authDisplayNameHint,
                              controller: nameController,
                              keyboardType: TextInputType.name,
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email Field
                        Semantics(
                          textField: true,
                          label: l10n.authEmailLabel,
                          hint: 'Enter your email address',
                          child: AppTextField(
                            label: l10n.authEmailLabel,
                            hintText: l10n.authEmailHint,
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(
                              Icons.mail_outline_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        Semantics(
                          textField: true,
                          label: l10n.authPasswordLabel,
                          hint: 'Enter your password',
                          child: AppTextField(
                            label: l10n.authPasswordLabel,
                            hintText: l10n.authPasswordHint,
                            controller: passwordController,
                            isPassword: true,
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                            ),
                          ),
                        ),

                        // Forgot Password Link (Login mode only)
                        if (!isRegister) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Semantics(
                              button: true,
                              label: l10n.authChipForgotPassword,
                              child: TextButton(
                                onPressed: onForgotPassword,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  l10n.authChipForgotPassword,
                                  style: typography.caption.medium.copyWith(
                                    color: colors.primary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),

                        // Submit Button
                        Semantics(
                          button: true,
                          label: isRegister
                              ? l10n.authSubmitRegister
                              : l10n.authSubmitLogin,
                          child: AppButton(
                            text: isRegister
                                ? l10n.authSubmitRegister
                                : l10n.authSubmitLogin,
                            onPressed: handleSubmit,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Mode Toggle Form Type
                        Center(
                          child: Semantics(
                            button: true,
                            label: isRegister
                                ? l10n.authAlreadyHaveAccount
                                : l10n.authNeedAccount,
                            child: GestureDetector(
                              onTap: () {
                                context.read<AuthModeCubit>().toggleFormType();
                              },
                              child: Text(
                                isRegister
                                    ? l10n.authAlreadyHaveAccount
                                    : l10n.authNeedAccount,
                                style: typography.subhead.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
