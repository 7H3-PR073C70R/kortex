import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:kortex/src/features/auth/presentation/widgets/mode_switch_button.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Animated sliding card authentication form for Login and Signup.
///
/// Features a single, fixed screen with no scrolling, an authentic diagonal
/// card surface, theme primary action buttons, default [AppTextField] inputs,
/// and selective social triggers (Google and Apple on supported platforms)
/// aligned diagonally matching the design reference.
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

    // Sync controllers with draft state
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

    // Animation controller for the Login <-> Signup slide transition
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 600),
      initialValue: isRegister ? 1.0 : 0.0,
    );

    useEffect(() {
      if (isRegister) {
        unawaited(
          animController.animateTo(
            1,
            curve: const Cubic(0.34, 1.35, 0.64, 1),
          ),
        );
      } else {
        unawaited(
          animController.animateTo(
            0,
            curve: const Cubic(0.34, 1.35, 0.64, 1),
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

          // Margins so card is framed by campus background
          const marginX = 16.0;
          final cardW = maxW - (marginX * 2);

          // Slant geometry (dramatic 20° diagonal)
          const slantHeight = 110.0;
          final slope = slantHeight / cardW;

          // Channel spacing: exactly 32px between Card 1 and socials,
          // and exactly 32px between socials and Card 2.
          const gap = 32.0;
          const socialDiameter = 44.0;
          const channelH = gap + socialDiameter + gap; // 32 + 44 + 32 = 108.0

          // Default safe padding for when cards are in their resting states:
          // Card 1 does not touch status bar on Login; Card 2 does not touch bottom on Signup.
          final defaultTopPadding = statusBarHeight + 12.0;
          final defaultBottomPadding = math.max(bottomSafePadding + 16.0, 20);

          final loginCardH =
              (maxH - 108.0 - defaultTopPadding).clamp(420.0, 640.0);
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

                  // Fun & Crazy Motion Kinetics:
                  // 1. Motion peak delta (peaks at midpoint t = 0.5)
                  final motionDelta = math.sin(t.clamp(0.0, 1.0) * math.pi);
                  // 2. Dynamic 3D tilt of cards while sliding
                  final tiltAngle = motionDelta * 0.045;
                  // 3. 360-degree joyful spin on the floating social buttons
                  final socialRotation = t * math.pi * 2;
                  final socialScale = 1.0 + (motionDelta * 0.22);
                  final arrowScale = 1.0 + (motionDelta * 0.25);

                  // Card 1 top: on Login (t=0) maintains default padding below status bar;
                  // on Signup (t=1) extends to top: 0 covering the app bar.
                  final card1Top = ui.lerpDouble(defaultTopPadding, 0.0, t)!;

                  // Card 2 bottom: on Login (t=0) extends to bottom: 0;
                  // on Signup (t=1) maintains proper padding and safe area above bottom.
                  final card2Bottom =
                      ui.lerpDouble(0.0, defaultBottomPadding, t)!;

                  // Card 1 height smoothly interpolates from loginCardH to peekingCard1H
                  final card1H = ui.lerpDouble(loginCardH, peekingCard1H, t)!;

                  // Y-coordinate functions along the slant:
                  // Card 1 bottom at x:
                  double card1BottomAt(double x) =>
                      card1Top + card1H - slantHeight + slope * x;

                  // Card 2 top at x:
                  double card2TopAt(double x) => card1BottomAt(x) + channelH;

                  return Stack(
                    children: [
                      // ========================================================
                      // 1. CARD 2: Peeking in Login / Full Card in Signup
                      // Uses 3D kinetic tilt and maintains proper padding on Signup
                      // ========================================================
                      Positioned(
                        top: card2TopAt(0),
                        left: marginX,
                        width: cardW,
                        bottom: card2Bottom,
                        child: Transform(
                          alignment: Alignment.bottomCenter,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateZ(showLogin ? tiltAngle : -tiltAngle),
                          child: CustomPaint(
                            painter: _ShapeShadowPainter(
                              clipper: const _SignupCardClipper(
                                slantHeight: slantHeight,
                              ),
                              color: cardColor,
                              shadowColor:
                                  colors.black.withAlpha(isDark ? 90 : 35),
                              elevation: 14 + (motionDelta * 6),
                            ),
                            child: ClipPath(
                              clipper: const _SignupCardClipper(
                                slantHeight: slantHeight,
                              ),
                              child: !showLogin
                                  ? Container(
                                      color: cardColor,
                                      padding: const EdgeInsets.only(
                                        left: 20,
                                        right: 20,
                                        top: slantHeight + 14,
                                        bottom: 16,
                                      ),
                                      child: isNeedsEmailVerification
                                          ? _buildVerificationView(
                                              context,
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
                                                    30.0 * (1.0 - t),
                                                  ),
                                                  child: Opacity(
                                                    opacity: signupOpacity,
                                                    child: _buildSignupForm(
                                                      context,
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
                                  : Container(color: cardColor),
                            ),
                          ),
                        ),
                      ),

                      // ========================================================
                      // 2. CARD 1: Full Card in Login / Peeking in Signup
                      // Uses 3D kinetic tilt and maintains proper padding on Login
                      // ========================================================
                      Positioned(
                        top: card1Top,
                        left: marginX,
                        width: cardW,
                        height: card1H,
                        child: Transform(
                          alignment: Alignment.topCenter,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateZ(showLogin ? -tiltAngle : tiltAngle),
                          child: CustomPaint(
                            painter: _ShapeShadowPainter(
                              clipper: const _LoginCardClipper(
                                slantHeight: slantHeight,
                              ),
                              color: cardColor,
                              shadowColor:
                                  colors.black.withAlpha(isDark ? 90 : 35),
                              elevation: 14 + (motionDelta * 6),
                            ),
                            child: ClipPath(
                              clipper: const _LoginCardClipper(
                                slantHeight: slantHeight,
                              ),
                              child: showLogin
                                  ? Container(
                                      color: cardColor,
                                      padding: const EdgeInsets.only(
                                        left: 20,
                                        right: 20,
                                        top: 20,
                                        bottom: 20,
                                      ),
                                      child: SingleChildScrollView(
                                        physics: const ClampingScrollPhysics(),
                                        child: AutofillGroup(
                                          child: Transform.translate(
                                            offset: Offset(0, -30.0 * t),
                                            child: Opacity(
                                              opacity: loginOpacity,
                                              child: _buildLoginForm(
                                                context,
                                                emailController:
                                                    emailController,
                                                passwordController:
                                                    passwordController,
                                                isLoading: isLoading,
                                                onSubmit: handleSubmit,
                                                onForgotPassword:
                                                    onForgotPassword,
                                                onToggleForm: handleToggleForm,
                                                errorMessage:
                                                    errorMessageState.value,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(color: cardColor),
                            ),
                          ),
                        ),
                      ),

                      // ========================================================
                      // 3. SOCIALS (Directly on canvas with 32px padding and acrobatics)
                      // ========================================================
                      // Google Button
                      Positioned(
                        left: marginX + (isAppleSupported ? 68 : 108),
                        top: card1BottomAt(isAppleSupported ? 90 : 130) + gap,
                        child: Transform.scale(
                          scale: socialScale,
                          child: Transform.rotate(
                            angle: socialRotation,
                            child: _CircularSocialButton(
                              key: const ValueKey<String>('auth_google_button'),
                              icon: const _GooglePlusIcon(),
                              color: const Color(0xFFEA4335),
                              onPressed: isLoading ? () {} : onGooglePressed,
                              semanticsLabel: 'Google Sign In',
                            ),
                          ),
                        ),
                      ),

                      // Apple Button (iOS/macOS)
                      if (isAppleSupported)
                        Positioned(
                          left: marginX + 138,
                          top: card1BottomAt(160) + gap,
                          child: Transform.scale(
                            scale: socialScale,
                            child: Transform.rotate(
                              angle: -socialRotation,
                              child: _CircularSocialButton(
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

                      // ========================================================
                      // 4. ARROW BUTTONS (Spring scaling toggle buttons)
                      // ========================================================
                      // Left Circle Arrow (Inside Card 2)
                      Positioned(
                        left: marginX + 16,
                        top: card2TopAt(35) + 16,
                        child: Transform.scale(
                          scale: arrowScale,
                          child: _CircularArrowButton(
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

                      // Right Circle Arrow (Inside Card 1)
                      Positioned(
                        left: marginX + cardW - 54,
                        top: card1BottomAt(cardW - 35) - 54,
                        child: Transform.scale(
                          scale: arrowScale,
                          child: _CircularArrowButton(
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

  // ==========================================================================
  // LOGIN FORM CONTENT
  // ==========================================================================
  Widget _buildLoginForm(
    BuildContext context, {
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required bool isLoading,
    required VoidCallback onSubmit,
    required VoidCallback onForgotPassword,
    required VoidCallback onToggleForm,
    required String? errorMessage,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Header with AI Mode Switch option
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
            errorMessage,
            style: typography.caption.medium.copyWith(
              color: colors.error,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Email Input (Using our standard AppTextField)
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

        // Password Input (Using our standard AppTextField)
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

        // Forgot Password
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

        // Primary Theme Login Button (Aligned to the right, pill button)
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

        // "I don't have an account" toggle link
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

  // ==========================================================================
  // SIGNUP FORM CONTENT
  // ==========================================================================
  Widget _buildSignupForm(
    BuildContext context, {
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required TextEditingController confirmPasswordController,
    required TextEditingController promoCodeController,
    required ValueNotifier<bool> showPromoField,
    required bool isLoading,
    required VoidCallback onSubmit,
    required VoidCallback onToggleForm,
    required String? errorMessage,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Header with AI Mode Switch option
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
        const SizedBox(height: 10),

        if (errorMessage != null) ...[
          Text(
            errorMessage,
            style: typography.caption.medium.copyWith(
              color: colors.error,
            ),
          ),
          const SizedBox(height: 4),
        ],

        // Name (Using our standard AppTextField)
        AppTextField(
          label: l10n.authDisplayNameLabel,
          hintText: l10n.authDisplayNameHint,
          controller: nameController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(
            Icons.person_outline_rounded,
            size: 20,
          ),
        ),
        const SizedBox(height: 12),

        // Email (Using our standard AppTextField)
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
        const SizedBox(height: 12),

        // Password (Using our standard AppTextField)
        AppTextField(
          label: l10n.authPasswordLabel,
          hintText: l10n.authPasswordHint,
          controller: passwordController,
          isPassword: true,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            size: 20,
          ),
        ),
        const SizedBox(height: 12),

        // Confirm Password (Using our standard AppTextField)
        AppTextField(
          label: 'Confirm password',
          hintText: l10n.authPasswordHint,
          controller: confirmPasswordController,
          isPassword: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            size: 20,
          ),
        ),

        // Optional Promo Code
        if (showPromoField.value || promoCodeController.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppTextField(
            label: l10n.authPromoCodeOptionalLabel,
            hintText: l10n.authPromoCodeHint,
            controller: promoCodeController,
            prefixIcon: const Icon(
              Icons.card_giftcard_rounded,
              size: 20,
            ),
          ),
        ],
        const SizedBox(height: 28),

        // Primary Theme Signup Button (Aligned to the right, pill button)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 190,
              child: AppButton(
                text: 'Signup',
                isLoading: isLoading,
                onPressed: isLoading ? null : onSubmit,
                borderRadius: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // "Already have an account" toggle link
        Center(
          child: TextButton(
            key: const ValueKey<String>('auth_to_login_button'),
            onPressed: onToggleForm,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: 'Log in',
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

  // ==========================================================================
  // OTP EMAIL VERIFICATION
  // ==========================================================================
  Widget _buildVerificationView(
    BuildContext context, {
    required String email,
    required TextEditingController otpController,
    required bool isLoading,
  }) {
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

// ============================================================================
// CIRCULAR SOCIAL BUTTONS
// ============================================================================
class _CircularSocialButton extends StatelessWidget {
  const _CircularSocialButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.semanticsLabel,
    super.key,
  });

  final Widget icon;
  final Color color;
  final VoidCallback onPressed;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 65 : 35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: color.withAlpha(isHovered ? 120 : 70),
                    blurRadius: isHovered ? 14 : 8,
                    offset: Offset(0, isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Center(child: icon),
            ),
          );
        },
      ),
    );
  }
}

class _GooglePlusIcon extends StatelessWidget {
  const _GooglePlusIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G+',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    );
  }
}

// ============================================================================
// CIRCULAR ARROW TOGGLE BUTTON
// ============================================================================
class _CircularArrowButton extends StatelessWidget {
  const _CircularArrowButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(isHovered ? 130 : 80),
                    blurRadius: isHovered ? 12 : 7,
                    offset: Offset(0, isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// CUSTOM CARD CLIPPERS & PAINTERS
// ============================================================================

/// Painter that draws any clipped shape path with ambient drop shadow.
class _ShapeShadowPainter extends CustomPainter {
  const _ShapeShadowPainter({
    required this.clipper,
    required this.color,
    required this.shadowColor,
    required this.elevation,
  });

  final CustomClipper<Path> clipper;
  final Color color;
  final Color shadowColor;
  final double elevation;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);
    if (elevation > 0) {
      canvas.drawShadow(path, shadowColor, elevation, false);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ShapeShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.elevation != elevation;
}

/// Card 1 Clipper (Top anchored, rounded top corners, slanted bottom edge with rounded bottom corners).
class _LoginCardClipper extends CustomClipper<Path> {
  const _LoginCardClipper({
    required this.slantHeight,
  });

  static const double radius = AppRadius.sheet;
  final double slantHeight;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius.clamp(0.0, w / 4);
    final slope = slantHeight / w;
    final leftY = (h - slantHeight).clamp(0.0, h);

    return Path()
      // Top-left corner
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      // Top edge
      ..lineTo(w - r, 0)
      // Top-right corner
      ..quadraticBezierTo(w, 0, w, r)
      // Right edge down to bottom-right corner
      ..lineTo(w, h - r)
      // Bottom-right corner smoothly curving into slant
      ..quadraticBezierTo(w, h, w - r, h - slope * r)
      // Slanted edge upwards to the left
      ..lineTo(r, leftY + slope * r)
      // Bottom-left corner smoothly curving into left vertical edge
      ..quadraticBezierTo(0, leftY, 0, leftY - r)
      // Left edge back to top-left
      ..lineTo(0, r)
      ..close();
  }

  @override
  bool shouldReclip(covariant _LoginCardClipper oldClipper) =>
      oldClipper.slantHeight != slantHeight;
}

/// Card 2 Clipper (Slanted top edge with rounded top corners, rounded bottom corners).
class _SignupCardClipper extends CustomClipper<Path> {
  const _SignupCardClipper({
    required this.slantHeight,
  });

  static const double radius = AppRadius.sheet;
  final double slantHeight;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius.clamp(0.0, w / 4);
    final slope = slantHeight / w;

    return Path()
      // Top-left corner curving from vertical left edge into slant
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, slope * r)
      // Slanted top edge
      ..lineTo(w - r, slantHeight - slope * r)
      // Top-right corner curving from slant into right vertical edge
      ..quadraticBezierTo(w, slantHeight, w, slantHeight + r)
      // Right edge down to bottom-right corner
      ..lineTo(w, h - r)
      // Bottom-right corner
      ..quadraticBezierTo(w, h, w - r, h)
      // Bottom edge
      ..lineTo(r, h)
      // Bottom-left corner
      ..quadraticBezierTo(0, h, 0, h - r)
      // Left edge back to top-left
      ..lineTo(0, r)
      ..close();
  }

  @override
  bool shouldReclip(covariant _SignupCardClipper oldClipper) =>
      oldClipper.slantHeight != slantHeight;
}
