import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_shell.dart';
import 'package:kortex/src/features/auth/presentation/widgets/mode_switch_button.dart';
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: AuthBrandLockup(),
            ),
            const SizedBox(width: 8),
            ModeSwitchButton(
              isChatMode: false,
              onToggle: () {
                context.read<AuthModeCubit>().toggleMode();
              },
            ),
          ],
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
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onForgotPassword,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.authChipForgotPassword,
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 44),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 190,
              child: AppButton(
                text: 'Login',
                isLoading: isLoading,
                onPressed: isLoading ? null : onSubmit,
                borderRadius: 24,
              ),
            ),
          ),
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
