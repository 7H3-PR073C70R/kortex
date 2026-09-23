import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_shell.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Fast, high-contrast input form with floating glassmorphic card over the
/// full-screen campus backdrop.
class AuthFormView extends HookWidget {
  const AuthFormView({
    required this.onForgotPassword,
    required this.onGooglePressed,
    required this.onApplePressed,
    super.key,
  });

  final VoidCallback onForgotPassword;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final draftCubit = context.read<AuthDraftCubit>();
    final draftState = context.watch<AuthDraftCubit>().state;
    final authMode = context.watch<AuthModeCubit>().state;
    final authState = context.watch<AuthBloc>().state;
    final isLoading = authState.isLoading;
    final isRegister = authMode.formType == AuthFormType.register;

    final emailController = useTextEditingController(text: draftState.email);
    final passwordController = useTextEditingController(
      text: draftState.password,
    );
    final nameController = useTextEditingController(
      text: draftState.displayName,
    );
    final promoCodeController = useTextEditingController();
    final showPromoField = useState<bool>(false);
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
      if (isLoading) return;
      final email = emailController.text.trim();
      final password = passwordController.text;
      final name = nameController.text.trim();
      final promoCode = promoCodeController.text.trim();

      if (email.isEmpty || password.isEmpty) return;

      if (isRegister) {
        context.read<AuthBloc>().add(
          AuthRegisterRequested(
            email: email,
            password: password,
            displayName: name.isNotEmpty ? name : null,
            promoCode: promoCode.isNotEmpty ? promoCode : null,
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
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GlassSurface(
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
                          borderRadius: AppRadius.concentricBorderRadius(
                            AppRadius.dialog,
                            4,
                          ),
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
                              l10n.authVerifyAccountTitle,
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.authVerifyAccountSubtitle(
                                emailController.text,
                              ),
                              textAlign: TextAlign.center,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              label: l10n.authOtpInputLabel,
                              hintText: l10n.authOtpInputHint,
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
                              text: l10n.authVerifyOtpButton,
                              isLoading: isLoading,
                              onPressed: isLoading
                                  ? null
                                  : () {
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
                                l10n.authSwitchToSignIn,
                                style: typography.caption.medium.copyWith(
                                  color: colors.primary,
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
                        hint: l10n.authDisplayNameSemanticsHint,
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
                      hint: l10n.authEmailSemanticsHint,
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
                      hint: l10n.authPasswordSemanticsHint,
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

                    // Promo Code Field (Optional, for Register mode)
                    if (isRegister) ...[
                      const SizedBox(height: 10),
                      if (!showPromoField.value &&
                          promoCodeController.text.isEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              showPromoField.value = true;
                            },
                            icon: Icon(
                              Icons.card_giftcard_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                            label: Text(
                              l10n.authPromoCodeQuestion,
                              style: typography.caption.medium.copyWith(
                                color: colors.primary,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ] else ...[
                        Semantics(
                          textField: true,
                          label: l10n.authPromoCodeLabel,
                          hint: l10n.authPromoCodeSemanticsHint,
                          child: AppTextField(
                            label: l10n.authPromoCodeOptionalLabel,
                            hintText: l10n.authPromoCodeHint,
                            controller: promoCodeController,
                            prefixIcon: const Icon(
                              Icons.confirmation_number_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ],

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
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.authChipForgotPassword,
                              style: typography.caption.medium.copyWith(
                                color: colors.primary,
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
                        isLoading: isLoading,
                        onPressed: isLoading ? null : handleSubmit,
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
                        child: PlatformHoverBuilder(
                          builder: (context, isHovered, child) {
                            return GestureDetector(
                              onTap: () {
                                context.read<AuthModeCubit>().toggleFormType();
                              },
                              child: AnimatedDefaultTextStyle(
                                duration: AppMotion.snappy,
                                curve: AppMotion.easeOutCubic,
                                style: typography.subhead.regular.copyWith(
                                  color: isHovered
                                      ? colors.primary
                                      : colors.textSecondary,
                                  decoration: isHovered
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                ),
                                child: Text(
                                  isRegister
                                      ? l10n.authAlreadyHaveAccount
                                      : l10n.authNeedAccount,
                                ),
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
          ),
        );
      },
    );
  }
}
