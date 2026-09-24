import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_card_clippers.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_circular_buttons.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_login_form_content.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_signup_form_content.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_verification_content.dart';

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
    final isDark = context.isDarkMode;

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
    final confirmPasswordController = useTextEditingController();
    final nameController = useTextEditingController(
      text: draftState.displayName,
    );
    final promoCodeController = useTextEditingController();
    final showPromoField = useState<bool>(false);
    final otpController = useTextEditingController();
    final errorMessageState = useState<String?>(null);

    useEffect(() {
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
    }, [draftState.email, draftState.password, draftState.displayName]);

    useEffect(() {
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
    }, [emailController, passwordController, nameController]);

    final animController = useAnimationController(
      duration: const Duration(milliseconds: 580),
      initialValue: isRegister ? 1.0 : 0.0,
    );

    useEffect(() {
      if (isRegister) {
        unawaited(
          animController.animateTo(
            1,
            curve: Curves.easeInOutCubicEmphasized,
          ),
        );
      } else {
        unawaited(
          animController.animateTo(
            0,
            curve: Curves.easeInOutCubicEmphasized,
          ),
        );
      }
      return null;
    }, [isRegister]);

    void handleSubmit() {
      if (isLoading) return;
      errorMessageState.value = null;

      final email = emailController.text.trim();
      final password = passwordController.text;
      final name = nameController.text.trim();
      final promoCode = promoCodeController.text.trim();

      if (email.isEmpty || password.isEmpty) return;

      if (isRegister) {
        final confirmPassword = confirmPasswordController.text;
        if (confirmPassword.isNotEmpty && confirmPassword != password) {
          errorMessageState.value = 'Passwords do not match';
          return;
        }

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

    void handleToggleForm() {
      unawaited(HapticFeedback.lightImpact());
      errorMessageState.value = null;
      context.read<AuthModeCubit>().toggleFormType();
    }

    final isNeedsEmailVerification =
        authState.status == AuthStatus.needsEmailVerification && isRegister;

    final isAppleSupported = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final statusBarHeight = MediaQuery.of(context).padding.top;
          final bottomSafePadding = MediaQuery.of(context).padding.bottom;

          final maxW = constraints.maxWidth.clamp(320.0, 410.0);
          final maxH = constraints.maxHeight;

          const marginX = 16.0;
          final cardW = maxW - (marginX * 2);

          const slantHeight = 110.0;
          final slope = slantHeight / cardW;

          const gapTop = 40.0;
          const socialDiameter = 44.0;
          const gapBottom = 32.0;
          const channelH = gapTop + socialDiameter + gapBottom;

          final defaultTopPadding = statusBarHeight + 12.0;
          final defaultBottomPadding = math.max(bottomSafePadding + 16.0, 20);

          final loginCardH =
              (maxH - channelH - defaultTopPadding).clamp(420.0, 640.0);
          final peekingCard1H =
              slantHeight + math.max(statusBarHeight + 14.0, 52.0);

          final cardColor = isDark ? colors.surfaceSecondary : colors.white;

          return Center(
            child: SizedBox(
              width: maxW,
              height: maxH,
              child: AnimatedBuilder(
                animation: animController,
                builder: (context, child) {
                  final t = animController.value;

                  final showLogin = t < 0.5;
                  final loginOpacity = ((0.7 - t) / 0.7).clamp(0.0, 1.0);
                  final signupOpacity = ((t - 0.3) / 0.7).clamp(0.0, 1.0);

                  final motionDelta = math.sin(t.clamp(0.0, 1.0) * math.pi);

                  final card1TiltX = -0.11 * motionDelta;
                  final card1TiltY = 0.04 * motionDelta;
                  final card1TiltZ = -0.02 * motionDelta;
                  final card1Scale = 1.0 - (motionDelta * 0.035);

                  final card2TiltX = 0.11 * motionDelta;
                  final card2TiltY = -0.04 * motionDelta;
                  final card2TiltZ = 0.02 * motionDelta;
                  final card2Scale = 1.0 - (motionDelta * 0.035);

                  final card1Top = ui.lerpDouble(defaultTopPadding, 0.0, t)!;
                  final card2Bottom =
                      ui.lerpDouble(0.0, defaultBottomPadding, t)!;
                  final card1H = ui.lerpDouble(loginCardH, peekingCard1H, t)!;

                  double card1BottomAt(double x) =>
                      card1Top + card1H - slantHeight + slope * x;

                  double card2TopAt(double x) => card1BottomAt(x) + channelH;

                  final cardGradient = LinearGradient(
                    begin: Alignment(-0.8 + (motionDelta * 0.4), -1),
                    end: const Alignment(0.8, 1),
                    colors: isDark
                        ? [
                            colors.surfaceSecondary,
                            Color.lerp(
                              colors.surfaceSecondary,
                              Colors.white,
                              0.03 * (1 - motionDelta),
                            )!,
                          ]
                        : [
                            colors.white,
                            Color.lerp(
                              colors.white,
                              colors.primary,
                              0.02 * motionDelta,
                            )!,
                          ],
                  );

                  return Stack(
                    children: [
                      Positioned(
                        top: card2TopAt(0),
                        left: marginX,
                        width: cardW,
                        bottom: card2Bottom,
                        child: RepaintBoundary(
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateX(card2TiltX)
                              ..rotateY(card2TiltY)
                              ..rotateZ(card2TiltZ)
                              ..scaleByDouble(card2Scale, card2Scale, 1, 1),
                            child: CustomPaint(
                              painter: ShapeShadowPainter(
                                clipper: const SignupCardClipper(
                                  slantHeight: slantHeight,
                                ),
                                color: cardColor,
                                shadowColor: colors.black.withAlpha(
                                  isDark
                                      ? (85 + (motionDelta * 45).toInt())
                                      : (30 + (motionDelta * 35).toInt()),
                                ),
                                elevation: 14.0 + (motionDelta * 18.0),
                              ),
                              child: ClipPath(
                                clipper: const SignupCardClipper(
                                  slantHeight: slantHeight,
                                ),
                                child: !showLogin
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          gradient: cardGradient,
                                        ),
                                        padding: const EdgeInsets.only(
                                          left: 20,
                                          right: 20,
                                          top: slantHeight + 14,
                                          bottom: 16,
                                        ),
                                        child: isNeedsEmailVerification
                                            ? AuthVerificationContent(
                                                email: emailController.text,
                                                otpController: otpController,
                                                isLoading: isLoading,
                                              )
                                            : SingleChildScrollView(
                                                physics:
                                                    const ClampingScrollPhysics(),
                                                child: AutofillGroup(
                                                  child: Transform.translate(
                                                    offset: Offset(
                                                      0,
                                                      32.0 * (1.0 - t),
                                                    ),
                                                    child: Opacity(
                                                      opacity: signupOpacity,
                                                      child: AuthSignupFormContent(
                                                        nameController:
                                                            nameController,
                                                        emailController:
                                                            emailController,
                                                        passwordController:
                                                            passwordController,
                                                        confirmPasswordController:
                                                            confirmPasswordController,
                                                        promoCodeController:
                                                            promoCodeController,
                                                        showPromoField:
                                                            showPromoField,
                                                        isLoading: isLoading,
                                                        onSubmit: handleSubmit,
                                                        onToggleForm:
                                                            handleToggleForm,
                                                        errorMessage:
                                                            errorMessageState
                                                                .value,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          gradient: cardGradient,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: card1Top,
                        left: marginX,
                        width: cardW,
                        height: card1H,
                        child: RepaintBoundary(
                          child: Transform(
                            alignment: Alignment.topCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateX(card1TiltX)
                              ..rotateY(card1TiltY)
                              ..rotateZ(card1TiltZ)
                              ..scaleByDouble(card1Scale, card1Scale, 1, 1),
                            child: CustomPaint(
                              painter: ShapeShadowPainter(
                                clipper: const LoginCardClipper(
                                  slantHeight: slantHeight,
                                ),
                                color: cardColor,
                                shadowColor: colors.black.withAlpha(
                                  isDark
                                      ? (85 + (motionDelta * 45).toInt())
                                      : (30 + (motionDelta * 35).toInt()),
                                ),
                                elevation: 14.0 + (motionDelta * 18.0),
                              ),
                              child: ClipPath(
                                clipper: const LoginCardClipper(
                                  slantHeight: slantHeight,
                                ),
                                child: showLogin
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          gradient: cardGradient,
                                        ),
                                        padding: const EdgeInsets.only(
                                          left: 20,
                                          right: 20,
                                          top: 20,
                                          bottom: 20,
                                        ),
                                        child: SingleChildScrollView(
                                          physics:
                                              const ClampingScrollPhysics(),
                                          child: AutofillGroup(
                                            child: Transform.translate(
                                              offset: Offset(0, -32.0 * t),
                                              child: Opacity(
                                                opacity: loginOpacity,
                                                child: AuthLoginFormContent(
                                                  emailController:
                                                      emailController,
                                                  passwordController:
                                                      passwordController,
                                                  isLoading: isLoading,
                                                  onSubmit: handleSubmit,
                                                  onForgotPassword:
                                                      onForgotPassword,
                                                  onToggleForm:
                                                      handleToggleForm,
                                                  errorMessage:
                                                      errorMessageState.value,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          gradient: cardGradient,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: marginX + (isAppleSupported ? 68 : 108),
                        top: card1BottomAt(isAppleSupported ? 90 : 130) +
                            gapTop,
                        child: RepaintBoundary(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0016)
                              ..rotateY(motionDelta * math.pi)
                              ..rotateX(motionDelta * 0.22)
                              ..scaleByDouble(
                                1.0 + (motionDelta * 0.16),
                                1.0 + (motionDelta * 0.16),
                                1,
                                1,
                              ),
                            child: CircularSocialButton(
                              key: const ValueKey<String>('auth_google_button'),
                              icon: const GooglePlusIcon(),
                              color: const Color(0xFFEA4335),
                              onPressed: isLoading ? () {} : onGooglePressed,
                              semanticsLabel: 'Google Sign In',
                            ),
                          ),
                        ),
                      ),
                      if (isAppleSupported)
                        Positioned(
                          left: marginX + 138,
                          top: card1BottomAt(160) + gapTop,
                          child: RepaintBoundary(
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0016)
                                ..rotateY(-motionDelta * math.pi)
                                ..rotateX(motionDelta * 0.22)
                                ..scaleByDouble(
                                  1.0 + (motionDelta * 0.16),
                                  1.0 + (motionDelta * 0.16),
                                  1,
                                  1,
                                ),
                              child: CircularSocialButton(
                                key:
                                    const ValueKey<String>('auth_apple_button'),
                                icon: const Icon(
                                  Icons.apple,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                color: const Color(0xFF1E293B),
                                onPressed: isLoading ? () {} : onApplePressed,
                                semanticsLabel: 'Apple Sign In',
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: marginX + 16,
                        top: card2TopAt(35) + 16,
                        child: RepaintBoundary(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0016)
                              ..rotateZ(t * math.pi)
                              ..scaleByDouble(
                                1.0 + (motionDelta * 0.16),
                                1.0 + (motionDelta * 0.16),
                                1,
                                1,
                              ),
                            child: CircularArrowButton(
                              key: const ValueKey<String>(
                                'auth_arrow_toggle_button',
                              ),
                              icon: showLogin
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: showLogin
                                  ? const Color(0xFFFF7A45)
                                  : const Color(0xFFFF5252),
                              onPressed: handleToggleForm,
                              tooltip:
                                  showLogin ? 'Switch to Signup' : 'Switch to Login',
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: marginX + cardW - 54,
                        top: card1BottomAt(cardW - 35) - 54,
                        child: RepaintBoundary(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0016)
                              ..rotateZ(t * math.pi)
                              ..scaleByDouble(
                                1.0 + (motionDelta * 0.16),
                                1.0 + (motionDelta * 0.16),
                                1,
                                1,
                              ),
                            child: CircularArrowButton(
                              icon: showLogin
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: const Color(0xFFFF5252),
                              onPressed: handleToggleForm,
                              tooltip:
                                  showLogin ? 'Switch to Signup' : 'Switch to Login',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
