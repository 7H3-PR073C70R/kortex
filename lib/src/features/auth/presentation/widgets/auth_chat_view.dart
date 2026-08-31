import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/chat_auth_message.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/social_auth_bar.dart';
import 'package:kortex/src/features/onboarding_utility/domain/use_cases/resend_otp_use_case.dart';
import 'package:kortex/src/features/onboarding_utility/domain/use_cases/verify_otp_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';
import 'package:kortex/src/shared/widgets/typewriter_text.dart';

enum _ChatFlowStep {
  initial,
  signUpName,
  signUpEmail,
  signUpPassword,
  otpVerification,
  loginEmail,
  loginPassword,
  forgotPasswordEmail,
  submitting,
}

/// Conversational AI Chat authentication view with unique Syllabot AI mascot.
///
/// Features a caring motivational greeting, context-driven floating inputs,
/// responsive disabled state for empty send button,
/// animated "Thinking..." state, live typewriter streaming,
/// and in-chat OTP verification.
class AuthChatView extends HookWidget {
  const AuthChatView({
    required this.onGooglePressed,
    required this.onForgotPassword,
    super.key,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onForgotPassword;

  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final draftCubit = context.read<AuthDraftCubit>();
    final draftState = context.watch<AuthDraftCubit>().state;
    final authState = context.watch<AuthBloc>().state;

    final textController = useTextEditingController();
    final scrollController = useScrollController();

    final isThinking = useState<bool>(false);
    final thinkingLabel = useState<String>('Thinking...');
    final isTyping = useState<bool>(false);
    final latestBotMsgId = useState<String>('');
    final hasInputText = useState<bool>(false);

    final currentFlow = useState<_ChatFlowStep>(_ChatFlowStep.initial);
    final otpEmail = useState<String>('');

    useEffect(
      () {
        void textListener() {
          hasInputText.value = textController.text.trim().isNotEmpty;
        }

        textController.addListener(textListener);
        return () => textController.removeListener(textListener);
      },
      [textController],
    );

    final messages = useState<List<ChatAuthMessage>>([
      ChatAuthMessage(
        id: 'msg_welcome',
        sender: ChatAuthSender.syllabot,
        text: l10n.authChatWelcome,
        timestamp: DateTime.now(),
      ),
    ]);

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          unawaited(
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutQuad,
            ),
          );
        }
      });
    }

    void addBotMessage(
      String text, {
      bool isError = false,
      ChatAuthStep step = ChatAuthStep.initial,
      bool enableTypewriter = true,
    }) {
      final msgId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
      final msg = ChatAuthMessage(
        id: msgId,
        sender: ChatAuthSender.syllabot,
        text: text,
        timestamp: DateTime.now(),
        isError: isError,
        step: step,
      );
      messages.value = [...messages.value, msg];
      latestBotMsgId.value = msgId;
      isTyping.value = enableTypewriter;
      scrollToBottom();
    }

    void addUserMessage(String text, {bool isPassword = false}) {
      final msg = ChatAuthMessage(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        sender: ChatAuthSender.user,
        text: isPassword ? '••••••••' : text,
        timestamp: DateTime.now(),
        isPasswordInput: isPassword,
        sensitiveValue: isPassword ? text : null,
      );
      messages.value = [...messages.value, msg];
      scrollToBottom();
    }

    void simulateBotReply(
      String replyText, {
      String thinkingText = 'Thinking...',
      Duration delay = const Duration(milliseconds: 950),
      bool isError = false,
      VoidCallback? onComplete,
    }) {
      isThinking.value = true;
      thinkingLabel.value = thinkingText;
      scrollToBottom();

      Timer(delay, () {
        if (!context.mounted) return;
        isThinking.value = false;
        addBotMessage(replyText, isError: isError);
        onComplete?.call();
      });
    }

    Future<void> handleOtpSubmit(String code) async {
      addUserMessage(code, isPassword: true);
      textController.clear();

      if (code.length != 6 || int.tryParse(code) == null) {
        simulateBotReply(
          'Please enter a valid 6-digit numeric verification code.',
          isError: true,
          thinkingText: 'Checking verification code...',
        );
        return;
      }

      isThinking.value = true;
      thinkingLabel.value = 'Verifying security credentials...';
      scrollToBottom();

      try {
        final verifyUseCase = locator<VerifyOtpUseCase>();
        final result = await verifyUseCase(
          email: otpEmail.value.isNotEmpty ? otpEmail.value : draftState.email,
          otp: code,
        );

        if (!context.mounted) return;
        isThinking.value = false;

        result.fold(
          (failure) {
            addBotMessage(
              'Verification Failed: '
              '${failure.message ?? "Invalid or expired code"}. '
              'Please check your code or tap Resend Code below.',
              isError: true,
            );
          },
          (_) {
            addBotMessage(
              'Security verification complete! '
              'Initializing your academic calibration profile...',
            );
            Timer(const Duration(milliseconds: 700), () {
              if (context.mounted) {
                unawaited(
                  context.router.replace(const OnboardingCalibrationRoute()),
                );
              }
            });
          },
        );
      } on Object catch (_) {
        if (!context.mounted) return;
        isThinking.value = false;
        addBotMessage(
          'Network error during verification. '
          'Please check your connection and tap Resend Code.',
          isError: true,
        );
      }
    }

    Future<void> handleResendOtp() async {
      addUserMessage('Resend Verification Code');
      isThinking.value = true;
      thinkingLabel.value = 'Dispatching fresh verification code...';
      scrollToBottom();

      try {
        final resendUseCase = locator<ResendOtpUseCase>();
        final result = await resendUseCase(
          email: otpEmail.value.isNotEmpty ? otpEmail.value : draftState.email,
        );

        if (!context.mounted) return;
        isThinking.value = false;

        result.fold(
          (failure) {
            addBotMessage(
              'Could not resend verification code: '
              '${failure.message ?? "Request timed out"}. '
              'Please wait a moment and try again.',
              isError: true,
            );
          },
          (_) {
            addBotMessage(
              'A fresh 6-digit verification code has been dispatched to '
              '${otpEmail.value}. '
              'Check your inbox and enter the code below.',
            );
          },
        );
      } on Object catch (_) {
        if (!context.mounted) return;
        isThinking.value = false;
        addBotMessage(
          'Network error while sending verification code. '
          'Please try again.',
          isError: true,
        );
      }
    }

    void handleSend() {
      final input = textController.text.trim();
      if (input.isEmpty || isThinking.value || isTyping.value) return;

      unawaited(HapticFeedback.lightImpact());

      switch (currentFlow.value) {
        case _ChatFlowStep.initial:
          break;

        case _ChatFlowStep.signUpName:
          if (input.length < 2) {
            addUserMessage(input);
            textController.clear();
            simulateBotReply(
              'Please enter your full name so Syllabot '
              'can address you properly.',
              isError: true,
              thinkingText: 'Validating name...',
            );
            return;
          }

          addUserMessage(input);
          draftCubit.updateDisplayName(input);
          textController.clear();
          currentFlow.value = _ChatFlowStep.signUpEmail;

          simulateBotReply(
            'Great to meet you, $input! 🎓 '
            'What is your academic or personal email address?',
            thinkingText: 'Preparing profile setup...',
          );

        case _ChatFlowStep.signUpEmail:
          if (!_emailRegex.hasMatch(input)) {
            addUserMessage(input);
            textController.clear();
            simulateBotReply(
              'That does not look like a valid email address. '
              'Please check and try again (e.g. name@university.edu).',
              isError: true,
              thinkingText: 'Checking email format...',
            );
            return;
          }

          addUserMessage(input);
          draftCubit.updateEmail(input);
          textController.clear();
          currentFlow.value = _ChatFlowStep.signUpPassword;

          simulateBotReply(
            'Almost there! Set a secure password '
            '(at least 6 characters).',
            thinkingText: 'Configuring credentials...',
          );

        case _ChatFlowStep.signUpPassword:
          if (input.length < 6) {
            addUserMessage(input, isPassword: true);
            textController.clear();
            simulateBotReply(
              'Password must be at least 6 characters long for security. '
              'Please try again.',
              isError: true,
              thinkingText: 'Checking password security...',
            );
            return;
          }

          addUserMessage(input, isPassword: true);
          draftCubit.updatePassword(input);
          textController.clear();
          currentFlow.value = _ChatFlowStep.submitting;

          isThinking.value = true;
          thinkingLabel.value = 'Creating your Kortex neural profile...';
          scrollToBottom();

          context.read<AuthBloc>().add(
            AuthRegisterRequested(
              email: draftState.email,
              password: input,
              displayName: draftState.displayName,
            ),
          );

        case _ChatFlowStep.otpVerification:
          unawaited(handleOtpSubmit(input));

        case _ChatFlowStep.loginEmail:
          if (!_emailRegex.hasMatch(input)) {
            addUserMessage(input);
            textController.clear();
            simulateBotReply(
              'Please enter a valid email address (e.g. student@mit.edu).',
              isError: true,
              thinkingText: 'Validating email format...',
            );
            return;
          }

          addUserMessage(input);
          draftCubit.updateEmail(input);
          textController.clear();
          currentFlow.value = _ChatFlowStep.loginPassword;

          simulateBotReply(
            'Please enter your password to sign in.',
            thinkingText: 'Finding account...',
          );

        case _ChatFlowStep.loginPassword:
          addUserMessage(input, isPassword: true);
          draftCubit.updatePassword(input);
          textController.clear();
          currentFlow.value = _ChatFlowStep.submitting;

          isThinking.value = true;
          thinkingLabel.value = 'Authenticating credentials with AI...';
          scrollToBottom();

          context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: draftState.email.isNotEmpty ? draftState.email : input,
              password: input,
            ),
          );

        case _ChatFlowStep.forgotPasswordEmail:
          if (!_emailRegex.hasMatch(input)) {
            addUserMessage(input);
            textController.clear();
            simulateBotReply(
              'Please enter a valid registered email address.',
              isError: true,
              thinkingText: 'Validating email...',
            );
            return;
          }

          addUserMessage(input);
          draftCubit.updateEmail(input);
          textController.clear();
          currentFlow.value = _ChatFlowStep.submitting;

          isThinking.value = true;
          thinkingLabel.value = 'Dispatching password reset link...';
          scrollToBottom();

          context.read<AuthBloc>().add(
            AuthResetPasswordRequested(email: input),
          );

        case _ChatFlowStep.submitting:
          break;
      }
    }

    final isInputNeeded =
        !isThinking.value &&
        !isTyping.value &&
        !authState.isLoading &&
        currentFlow.value != _ChatFlowStep.submitting;

    final isTextFieldVisible =
        isInputNeeded && currentFlow.value != _ChatFlowStep.initial;

    String getHintText() {
      switch (currentFlow.value) {
        case _ChatFlowStep.signUpName:
          return 'Enter your full name (e.g. Ada Lovelace)';
        case _ChatFlowStep.signUpEmail:
        case _ChatFlowStep.loginEmail:
        case _ChatFlowStep.forgotPasswordEmail:
        case _ChatFlowStep.initial:
          return l10n.authEmailHint;
        case _ChatFlowStep.signUpPassword:
        case _ChatFlowStep.loginPassword:
          return l10n.authPasswordHint;
        case _ChatFlowStep.otpVerification:
          return 'Enter 6-digit verification code (e.g. 123456)';
        case _ChatFlowStep.submitting:
          return 'Processing...';
      }
    }

    final isPasswordField =
        currentFlow.value == _ChatFlowStep.signUpPassword ||
        currentFlow.value == _ChatFlowStep.loginPassword ||
        currentFlow.value == _ChatFlowStep.otpVerification;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          (current.status == AuthStatus.error &&
              current.errorMessage != previous.errorMessage),
      listener: (context, state) {
        if (state.status == AuthStatus.error) {
          isThinking.value = false;
          isTyping.value = false;
          currentFlow.value = _ChatFlowStep.initial;
          final err =
              state.errorMessage ??
              'Network connection error. Please try again.';
          addBotMessage(
            'Authentication Error: $err. '
            'Would you like to try again or reset your password?',
            isError: true,
          );
        } else if (state.requiresOtp && state.user != null) {
          isThinking.value = false;
          currentFlow.value = _ChatFlowStep.otpVerification;
          otpEmail.value = state.user!.email;
          addBotMessage(
            'Account created! We have sent a 6-digit verification code to '
            '${state.user!.email}. '
            'Please enter the code below to verify your account.',
          );
        } else if (state.isResetSent) {
          isThinking.value = false;
          currentFlow.value = _ChatFlowStep.initial;
          addBotMessage(
            'A password reset link has been dispatched to your email! '
            'Follow the link in your inbox to reset your password.',
          );
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                children: [
                  // 1. Message Thread
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount:
                          messages.value.length +
                          (isThinking.value ||
                                  (authState.isLoading &&
                                      currentFlow.value ==
                                          _ChatFlowStep.submitting)
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.value.length) {
                          return _ThinkingBubble(
                            statusText: authState.isLoading
                                ? 'Connecting to Kortex neural engine...'
                                : thinkingLabel.value,
                          );
                        }

                        final msg = messages.value[index];
                        final isBot = msg.sender == ChatAuthSender.syllabot;
                        final isStreaming =
                            isBot &&
                            msg.id == latestBotMsgId.value &&
                            isTyping.value;

                        if (isBot) {
                          return _BotMessageBubble(
                            message: msg,
                            colors: colors,
                            typography: typography,
                            isDark: isDark,
                            isStreaming: isStreaming,
                            onStreamingTick: scrollToBottom,
                            onStreamingComplete: () {
                              isTyping.value = false;
                              scrollToBottom();
                            },
                          );
                        } else {
                          return _UserMessageBubble(
                            message: msg,
                            colors: colors,
                            typography: typography,
                          );
                        }
                      },
                    ),
                  ),

                  // 2. Floating Action Controls (Buttons & Social Auth)
                  if (isInputNeeded)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                if (currentFlow.value ==
                                    _ChatFlowStep.otpVerification) ...[
                                  _QuickChip(
                                    icon: Icons.refresh_rounded,
                                    label: 'Resend Code',
                                    onTap: handleResendOtp,
                                  ),
                                  _QuickChip(
                                    icon: Icons.arrow_back_rounded,
                                    label: 'Change Email / Sign In',
                                    onTap: () {
                                      addUserMessage('Change Email / Sign In');
                                      currentFlow.value = _ChatFlowStep.initial;
                                      simulateBotReply(
                                        'Sure! How would you like to proceed?',
                                        thinkingText: 'Resetting flow...',
                                      );
                                    },
                                  ),
                                ] else if (currentFlow.value ==
                                    _ChatFlowStep.initial) ...[
                                  _QuickChip(
                                    icon: Icons.person_add_rounded,
                                    label: 'Create Account / Sign Up',
                                    isPrimary: true,
                                    onTap: () {
                                      addUserMessage('Create Account');
                                      currentFlow.value =
                                          _ChatFlowStep.signUpName;
                                      simulateBotReply(
                                        "Let's set up your personalized "
                                        'workspace! What is your full name?',
                                        thinkingText: 'Initializing signup...',
                                      );
                                    },
                                  ),
                                  _QuickChip(
                                    icon: Icons.login_rounded,
                                    label: 'Sign In / Log In',
                                    onTap: () {
                                      addUserMessage('Sign In');
                                      currentFlow.value =
                                          _ChatFlowStep.loginEmail;
                                      simulateBotReply(
                                        'Welcome back! What is your '
                                        'registered email address?',
                                        thinkingText: 'Opening login...',
                                      );
                                    },
                                  ),
                                  _QuickChip(
                                    icon: Icons.lock_reset_rounded,
                                    label: l10n.authChipForgotPassword,
                                    onTap: () {
                                      addUserMessage('Forgot Password');
                                      currentFlow.value =
                                          _ChatFlowStep.forgotPasswordEmail;
                                      simulateBotReply(
                                        'No worries! Enter your email address '
                                        'and '
                                        "I'll send you a password reset link.",
                                        thinkingText:
                                            'Preparing password reset...',
                                      );
                                    },
                                  ),
                                ] else ...[
                                  _QuickChip(
                                    icon: Icons.arrow_back_rounded,
                                    label: 'Start Over / Choose Other Option',
                                    onTap: () {
                                      addUserMessage('Start Over');
                                      currentFlow.value = _ChatFlowStep.initial;
                                      simulateBotReply(
                                        'No problem! How would you like to '
                                        'get started?',
                                        thinkingText: 'Resetting...',
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (currentFlow.value == _ChatFlowStep.initial) ...[
                            const SizedBox(height: 10),
                            SocialAuthBar(
                              isLoading: authState.isLoading,
                              onGooglePressed: onGooglePressed,
                              onApplePressed: () {
                                context.read<AuthBloc>().add(
                                  const AuthSocialLoginRequested(
                                    provider: 'apple',
                                    idToken: 'demo_apple_token',
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),

                  // 3. Dynamic Bottom Chat Input Bar
                  // (Floating Glassmorphic Pill)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isTextFieldVisible
                        ? Padding(
                            key: ValueKey(currentFlow.value),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Semantics(
                                    textField: true,
                                    label: l10n.authChatInputSemantics,
                                    hint: getHintText(),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 16,
                                          sigmaY: 16,
                                        ),
                                        child: TextField(
                                          controller: textController,
                                          autofocus: true,
                                          textCapitalization:
                                              currentFlow.value ==
                                                  _ChatFlowStep.signUpName
                                              ? TextCapitalization.words
                                              : TextCapitalization.none,
                                          keyboardType: isPasswordField
                                              ? (currentFlow.value ==
                                                        _ChatFlowStep
                                                            .otpVerification
                                                    ? TextInputType.number
                                                    : TextInputType
                                                          .visiblePassword)
                                              : (currentFlow.value ==
                                                        _ChatFlowStep.signUpName
                                                    ? TextInputType.name
                                                    : TextInputType
                                                          .emailAddress),
                                          obscureText: isPasswordField,
                                          style: typography.callout.regular
                                              .copyWith(
                                                color: colors.textPrimary,
                                              ),
                                          decoration: InputDecoration(
                                            hintText: getHintText(),
                                            hintStyle: typography
                                                .footnote
                                                .regular
                                                .copyWith(
                                                  color: colors.textMuted,
                                                  fontSize: 13,
                                                ),
                                            filled: true,
                                            fillColor: isDark
                                                ? colors.surfaceSecondary
                                                      .withAlpha(190)
                                                : colors.surfacePrimary
                                                      .withAlpha(220),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 18,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              borderSide: BorderSide(
                                                color: isDark
                                                    ? colors
                                                          .surfaceBorderHighlight
                                                          .withAlpha(80)
                                                    : colors.surfaceBorder
                                                          .withAlpha(140),
                                                width: 1.2,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              borderSide: BorderSide(
                                                color: isDark
                                                    ? colors
                                                          .surfaceBorderHighlight
                                                          .withAlpha(80)
                                                    : colors.surfaceBorder
                                                          .withAlpha(140),
                                                width: 1.2,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              borderSide: BorderSide(
                                                color: colors.primary,
                                                width: 1.6,
                                              ),
                                            ),
                                          ),
                                          onSubmitted: (_) => handleSend(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Semantics(
                                  button: true,
                                  label: l10n.authChatSendSemantics,
                                  child: ShrinkableButton(
                                    onTap: hasInputText.value
                                        ? handleSend
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: hasInputText.value
                                            ? colors.primary
                                            : (isDark
                                                  ? colors
                                                        .surfaceBorderHighlight
                                                        .withAlpha(60)
                                                  : colors
                                                        .surfaceBorderHighlight
                                                        .withAlpha(90)),
                                        boxShadow: hasInputText.value
                                            ? [
                                                BoxShadow(
                                                  color: colors.primary
                                                      .withAlpha(80),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.arrow_upward_rounded,
                                        color: hasInputText.value
                                            ? Colors.white
                                            : colors.textMuted.withAlpha(140),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BotMessageBubble extends StatelessWidget {
  const _BotMessageBubble({
    required this.message,
    required this.colors,
    required this.typography,
    required this.isDark,
    this.isStreaming = false,
    this.onStreamingTick,
    this.onStreamingComplete,
  });

  final ChatAuthMessage message;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final bool isStreaming;
  final VoidCallback? onStreamingTick;
  final VoidCallback? onStreamingComplete;

  @override
  Widget build(BuildContext context) {
    final isError = message.isError;

    return Semantics(
      container: true,
      label: isError
          ? 'Syllabot alert: ${message.text}'
          : 'Syllabot message: ${message.text}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SyllabotAvatar(
              size: 36,
              isError: isError,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isError
                          ? (isDark
                                ? colors.error.withAlpha(40)
                                : colors.error.withAlpha(20))
                          : (isDark
                                ? colors.surfaceSecondary.withAlpha(170)
                                : colors.surfacePrimary.withAlpha(220)),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: isError
                            ? colors.error.withAlpha(isDark ? 140 : 90)
                            : (isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(70)
                                  : colors.surfaceBorder.withAlpha(140)),
                        width: isError ? 1.4 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isError
                              ? colors.error.withAlpha(isDark ? 40 : 15)
                              : Colors.black.withAlpha(isDark ? 40 : 10),
                          blurRadius: isError ? 12 : 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isError) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 14,
                                color: colors.error,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Syllabot Alert',
                                style: typography.caption.bold.copyWith(
                                  color: colors.error,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        TypewriterText(
                          text: message.text,
                          isStreaming: isStreaming,
                          onTick: onStreamingTick,
                          onComplete: onStreamingComplete,
                          style: typography.callout.regular.copyWith(
                            color: isError
                                ? (isDark ? colors.white : colors.error)
                                : colors.textPrimary,
                            fontSize: 14,
                            height: 1.35,
                          ),
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
    );
  }
}

class _UserMessageBubble extends HookWidget {
  const _UserMessageBubble({
    required this.message,
    required this.colors,
    required this.typography,
  });

  final ChatAuthMessage message;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    final isObscured = useState<bool>(message.isPasswordInput);
    final isPassword = message.isPasswordInput;
    final rawText = message.sensitiveValue ?? message.text;
    final displayText = isPassword && isObscured.value ? '••••••••' : rawText;

    return Semantics(
      container: true,
      label: 'Your response: ${isPassword ? "Password entered" : displayText}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayText,
                        style: typography.callout.regular.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (isPassword) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: isObscured.value
                            ? 'Show password'
                            : 'Hide password',
                        child: GestureDetector(
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            isObscured.value = !isObscured.value;
                          },
                          child: Icon(
                            isObscured.value
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends HookWidget {
  const _ThinkingBubble({
    required this.statusText,
  });

  final String statusText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    useEffect(
      () {
        unawaited(controller.repeat());
        return null;
      },
      const [],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SyllabotAvatar(
            size: 36,
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(160)
                      : colors.surfacePrimary.withAlpha(220),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(70)
                        : colors.surfaceBorder.withAlpha(140),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 40 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(3, (i) {
                      return AnimatedBuilder(
                        animation: controller,
                        builder: (context, child) {
                          final delay = i * 0.2;
                          final t = (controller.value - delay) % 1.0;
                          final curveValue = math.sin(t * math.pi);
                          final scale =
                              0.6 + (0.4 * (curveValue > 0 ? curveValue : 0));
                          final opacity =
                              0.4 + (0.6 * (curveValue > 0 ? curveValue : 0));

                          return Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity.clamp(0.2, 1.0),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2.5,
                                ),
                                width: 6.5,
                                height: 6.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == 1
                                      ? colors.syllabotAccent
                                      : colors.primary,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    const SizedBox(width: 10),
                    Text(
                      statusText,
                      style: typography.footnote.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: 'Quick action: $label',
        child: ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            onTap();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isPrimary
                      ? colors.primary.withAlpha(isDark ? 220 : 240)
                      : (isDark
                            ? colors.surfaceSecondary.withAlpha(160)
                            : colors.surfacePrimary.withAlpha(210)),
                  border: Border.all(
                    color: isPrimary
                        ? colors.primary
                        : (isDark
                              ? colors.surfaceBorderHighlight.withAlpha(80)
                              : colors.surfaceBorder.withAlpha(140)),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPrimary
                          ? colors.primary.withAlpha(40)
                          : Colors.black.withAlpha(isDark ? 50 : 10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 15,
                        color: isPrimary ? Colors.white : colors.primary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: typography.caption.semiBold.copyWith(
                        color: isPrimary ? Colors.white : colors.textPrimary,
                        fontSize: 12.5,
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
  }
}
