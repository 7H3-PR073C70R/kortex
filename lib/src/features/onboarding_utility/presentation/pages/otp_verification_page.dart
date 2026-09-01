import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/bloc/otp_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class OtpVerificationPage extends HookWidget {
  const OtpVerificationPage({
    required this.email,
    super.key,
  });

  /// The email address that the OTP was sent to.
  final String email;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OtpCubit>(
      create: (_) => locator<OtpCubit>()..startCountdown(),
      child: _OtpView(email: email),
    );
  }
}

class _OtpView extends HookWidget {
  const _OtpView({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final controllers = List.generate(6, (_) => useTextEditingController());
    final focusNodes = List.generate(6, (_) => useFocusNode());

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNodes[0].requestFocus();
      });
      return null;
    }, []);

    final cubit = context.read<OtpCubit>();

    void submitOtp() {
      final otp = controllers.map((c) => c.text).join();
      if (otp.length == 6) {
        unawaited(cubit.verifyOtp(email: email, otp: otp));
      }
    }

    return BlocListener<OtpCubit, OtpState>(
      listener: (context, state) async {
        if (state.isVerified) {
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
                context.router.replaceAll([const OnboardingCalibrationRoute()]),
              );
            }
          }
        } else if (state.status == OtpStatus.error &&
            state.errorMessage != null) {
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
          for (final c in controllers) {
            c.clear();
          }
          focusNodes[0].requestFocus();
        } else if (state.status == OtpStatus.resent) {
          context.showSnackBar(message: l10n.otpResentMessage);
        }
      },
      child: Scaffold(
        backgroundColor: colors.surfacePrimary,
        body: AuraMeshNebula(
          showBackgroundImage: true,
          child: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          _EnvelopeIcon(),
                          const SizedBox(height: 28),
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.otpTitle,
                              textAlign: TextAlign.center,
                              style: typography.title1.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 26,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.otpSubtitle(email),
                            textAlign: TextAlign.center,
                            style: typography.callout.regular.copyWith(
                              color: colors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 36),
                          _OtpGlassCard(
                            controllers: controllers,
                            focusNodes: focusNodes,
                            onComplete: submitOtp,
                            colors: colors,
                            typography: typography,
                            l10n: l10n,
                            submitOtp: submitOtp,
                          ),
                          const SizedBox(height: 24),
                          _ResendSection(
                            cubit: cubit,
                            email: email,
                            l10n: l10n,
                            typography: typography,
                            colors: colors,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvelopeIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withAlpha(100),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.mark_email_read_rounded,
        color: Colors.white,
        size: 38,
      ),
    );
  }
}

class _OtpGlassCard extends StatelessWidget {
  const _OtpGlassCard({
    required this.controllers,
    required this.focusNodes,
    required this.onComplete,
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.submitOtp,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onComplete;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final VoidCallback submitOtp;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colors.surfacePrimary.withAlpha(60),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withAlpha(40),
            ),
          ),
          child: Column(
            children: [
              Semantics(
                label: l10n.otpInputSemantics,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return _PinBox(
                      controller: controllers[i],
                      focusNode: focusNodes[i],
                      index: i,
                      controllers: controllers,
                      focusNodes: focusNodes,
                      onComplete: onComplete,
                      colors: colors,
                      typography: typography,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 28),
              BlocBuilder<OtpCubit, OtpState>(
                builder: (context, state) {
                  return Semantics(
                    button: true,
                    label: l10n.otpVerifyButtonSemantics,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: state.isLoading ? null : submitOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n.otpVerifyButton,
                                style: typography.callout.semiBold.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendSection extends StatelessWidget {
  const _ResendSection({
    required this.cubit,
    required this.email,
    required this.l10n,
    required this.typography,
    required this.colors,
  });

  final OtpCubit cubit;
  final String email;
  final AppLocalizations l10n;
  final TypographyThemeExtension typography;
  final AppThemeColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OtpCubit, OtpState>(
      builder: (context, state) {
        if (state.canResend) {
          return Semantics(
            button: true,
            label: l10n.otpResendSemantics,
            child: TextButton(
              onPressed: state.isResending
                  ? null
                  : () => unawaited(cubit.resendOtp(email: email)),
              child: Text(
                state.isResending ? l10n.otpResending : l10n.otpResendCode,
                style: typography.callout.semiBold.copyWith(
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          );
        }
        return Text(
          l10n.otpResendIn(state.secondsRemaining),
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
          ),
        );
      },
    );
  }
}

/// Individual PIN digit input box with auto-advance and backspace.
class _PinBox extends StatelessWidget {
  const _PinBox({
    required this.controller,
    required this.focusNode,
    required this.index,
    required this.controllers,
    required this.focusNodes,
    required this.onComplete,
    required this.colors,
    required this.typography,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int index;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onComplete;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 54,
      margin: EdgeInsets.symmetric(horizontal: index == 2 ? 10 : 4),
      decoration: BoxDecoration(
        color: colors.surfacePrimary.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focusNode.hasFocus
              ? const Color(0xFF6366F1)
              : Colors.white.withAlpha(40),
          width: focusNode.hasFocus ? 2 : 1,
        ),
        boxShadow: focusNode.hasFocus
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withAlpha(60),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: typography.title2.bold.copyWith(
          color: colors.textPrimary,
          fontSize: 22,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          if (value.length == 1) {
            if (index < 5) {
              focusNodes[index + 1].requestFocus();
            } else {
              focusNode.unfocus();
              onComplete();
            }
          } else if (value.isEmpty && index > 0) {
            focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
