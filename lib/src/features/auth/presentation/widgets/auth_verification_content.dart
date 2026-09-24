import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

class AuthVerificationContent extends StatelessWidget {
  const AuthVerificationContent({
    required this.email,
    required this.otpController,
    required this.isLoading,
    super.key,
  });

  final String email;
  final TextEditingController otpController;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.pin_outlined,
          size: 42,
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
          l10n.authVerifyAccountSubtitle(email),
          textAlign: TextAlign.center,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
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
                        email: email.trim(),
                        token: otp,
                      ),
                    );
                  }
                },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            context.read<AuthModeCubit>().setFormType(AuthFormType.login);
          },
          child: Text(
            l10n.authSwitchToSignIn,
            style: typography.caption.medium.copyWith(
              color: colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
