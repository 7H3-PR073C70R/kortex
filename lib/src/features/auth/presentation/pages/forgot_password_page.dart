import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

@RoutePage()
class ForgotPasswordPage extends HookWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

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
        backgroundColor: colors.surfacePrimary,
        appBar: AppBar(
          backgroundColor: colors.transparent,
          elevation: 0,
          leading: PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return IconButton(
                icon: AnimatedContainer(
                  duration: AppMotion.snappy,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.surfaceBorder.withAlpha(50)
                        : colors.transparent,
                    borderRadius: AppRadius.radiusCard,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                onPressed: () => unawaited(context.router.maybePop()),
              );
            },
          ),
          title: Text(
            l10n.authForgotPasswordTitle,
            style: typography.headline.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? colors.surfaceSecondary.withAlpha(160)
                        : colors.surfacePrimary,
                    borderRadius: AppRadius.radiusPanel,
                    border: Border.all(
                      color: context.isDarkMode
                          ? colors.surfaceBorderHighlight.withAlpha(80)
                          : colors.surfaceBorder.withAlpha(140),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(
                          context.isDarkMode ? 60 : 15,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              AuthResetPasswordRequested(email: email),
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
    );
  }
}
