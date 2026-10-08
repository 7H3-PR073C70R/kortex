import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

class AuthLoginFormContent extends StatelessWidget {
  const AuthLoginFormContent({
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onToggleForm,
    required this.errorMessage,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onToggleForm;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authAccountSignInTitle,
          style: typography.headline.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 28),
        if (errorMessage != null) ...[
          Text(
            errorMessage!,
            style: typography.caption.medium.copyWith(
              color: colors.error,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AppTextField(
          label: l10n.authEmailLabel,
          hintText: l10n.authEmailHint,
          controller: emailController,
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(
            Icons.mail_outline_rounded,
            size: 20,
          ),
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: l10n.authPasswordLabel,
          hintText: l10n.authPasswordHint,
          controller: passwordController,
          autofillHints: const [AutofillHints.password],
          isPassword: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onForgotPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.authChipForgotPassword,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 44),
        AppButton(
          text: 'Login',
          isLoading: isLoading,
          onPressed: isLoading ? null : onSubmit,
          borderRadius: 24,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            key: const ValueKey<String>('auth_to_signup_button'),
            onPressed: onToggleForm,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text.rich(
              TextSpan(
                text: "I don't have an account? ",
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: 'Sign up',
                    style: typography.caption.semiBold.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
