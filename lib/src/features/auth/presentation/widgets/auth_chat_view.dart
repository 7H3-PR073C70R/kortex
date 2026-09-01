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
import 'package:kortex/src/features/auth/domain/entities/chat_auth_message.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/social_auth_bar.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';
import 'package:kortex/src/shared/widgets/typewriter_text.dart';

enum _ChatFlowStep {
  initial,
  signUpName,
  signUpEmail,
  signUpPassword,
  loginEmail,
  loginPassword,
  forgotPasswordEmail,
  needsEmailConfirmation,
  accountActive,
  submitting,
}

const List<({String author, String quote})> _motivationalQuotes = [
  (
    quote:
        'The beautiful thing about learning is that no one can '
        'take it away from you.',
    author: 'B.B. King',
  ),
  (
    quote:
        'Live as if you were to die tomorrow. '
        'Learn as if you were to live forever.',
    author: 'Mahatma Gandhi',
  ),
  (
    quote:
        'Education is the most powerful weapon which you can '
        'use to change the world.',
    author: 'Nelson Mandela',
  ),
  (
    quote: 'The mind is not a vessel to be filled, but a fire to be kindled.',
    author: 'Plutarch',
  ),
  (
    quote: 'An investment in knowledge pays the best interest.',
    author: 'Benjamin Franklin',
  ),
  (
    quote:
        'Develop a passion for learning. If you do, you will '
        'never cease to grow.',
    author: "Anthony J. D'Angelo",
  ),
  (
    quote:
        'The capacity to learn is a gift; the ability to learn is a skill; '
        'the willingness to learn is a choice.',
    author: 'Brian Herbert',
  ),
  (
    quote:
        'Wisdom is not a product of schooling but of the lifelong '
        'attempt to acquire it.',
    author: 'Albert Einstein',
  ),
  (
    quote:
        'Tell me and I forget. Teach me and I remember. '
        'Involve me and I learn.',
    author: 'Benjamin Franklin',
  ),
  (
    quote: 'There is no substitute for hard work and curious minds.',
    author: 'Thomas Edison',
  ),
];

/// Conversational AI Chat authentication view with randomized quotes,
/// live auto-scrolling, full-width actions, and synchronized draft state.
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
    final inputBorderColor = isDark
        ? colors.surfaceBorderHighlight.withAlpha(80)
        : colors.surfaceBorder.withAlpha(140);

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
    final isPasswordObscured = useState<bool>(true);
    final rawInputText = useState<String>('');

    final lastRetryAction = useState<VoidCallback?>(null);
    final lastRetryDescription = useState<String>('');

    final currentFlow = useState<_ChatFlowStep>(_ChatFlowStep.initial);

    final initialGreeting = useMemoized(() {
      final randomIndex = math.Random().nextInt(_motivationalQuotes.length);
      final item = _motivationalQuotes[randomIndex];
      return 'Hi Stranger! 👋 Welcome to Kortexify.\n\n'
          '✨ "${item.quote}" — ${item.author}\n\n'
          "I'm Syllabot, your AI study partner. "
          'How would you like to get started today?';
    });

    useEffect(
      () {
        void textListener() {
          hasInputText.value = textController.text.trim().isNotEmpty;
          rawInputText.value = textController.text;
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
        text: initialGreeting,
        timestamp: DateTime.now(),
      ),
    ]);

    void scrollToBottom({bool animate = false}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          if (animate) {
            unawaited(
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutQuad,
              ),
            );
          } else {
            scrollController.jumpTo(
              scrollController.position.maxScrollExtent,
            );
          }
        }
      });
    }

    void addBotMessage(
      String text, {
      bool isError = false,
      ChatAuthStep step = ChatAuthStep.initial,
      bool enableTypewriter = true,
      VoidCallback? onRetry,
    }) {
      final msgId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
      final msg = ChatAuthMessage(
        id: msgId,
        sender: ChatAuthSender.syllabot,
        text: text,
        timestamp: DateTime.now(),
        isError: isError,
        step: step,
        onRetry: onRetry,
      );
      messages.value = [...messages.value, msg];
      latestBotMsgId.value = msgId;
      isTyping.value = enableTypewriter;
      scrollToBottom(animate: true);
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
      scrollToBottom(animate: true);
    }

    void simulateBotReply(
      String replyText, {
      String thinkingText = 'Thinking...',
      Duration delay = const Duration(milliseconds: 450),
      bool isError = false,
      ChatAuthStep step = ChatAuthStep.initial,
      VoidCallback? onRetry,
      VoidCallback? onComplete,
    }) {
      isThinking.value = true;
      thinkingLabel.value = thinkingText;
      scrollToBottom(animate: true);

      Timer(delay, () {
        if (!context.mounted) return;
        isThinking.value = false;
        addBotMessage(
          replyText,
          isError: isError,
          step: step,
          onRetry: onRetry,
        );
        onComplete?.call();
      });
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
          context.read<AuthModeCubit>().setFormType(AuthFormType.register);
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
            '(at least 8 characters).',
            step: ChatAuthStep.askPassword,
            thinkingText: 'Configuring credentials...',
          );

        case _ChatFlowStep.signUpPassword:
          if (input.length < 8) {
            addUserMessage(input, isPassword: true);
            textController.clear();
            simulateBotReply(
              'Password must be at least 8 characters long for security. '
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
          thinkingLabel.value = 'Creating your Kortexify neural profile...';
          scrollToBottom(animate: true);

          final regEmail = draftState.email;
          final regPassword = input;
          final regName = draftState.displayName;

          lastRetryDescription.value = 'Sign Up';
          lastRetryAction.value = () {
            currentFlow.value = _ChatFlowStep.submitting;
            isThinking.value = true;
            thinkingLabel.value = 'Creating your Kortexify neural profile...';
            scrollToBottom(animate: true);
            context.read<AuthBloc>().add(
              AuthRegisterRequested(
                email: regEmail,
                password: regPassword,
                displayName: regName,
              ),
            );
          };

          context.read<AuthBloc>().add(
            AuthRegisterRequested(
              email: regEmail,
              password: regPassword,
              displayName: regName,
            ),
          );

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
          context.read<AuthModeCubit>().setFormType(AuthFormType.login);
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
          scrollToBottom(animate: true);

          final logEmail =
              draftState.email.isNotEmpty ? draftState.email : input;
          final logPassword = input;

          lastRetryDescription.value = 'Sign In';
          lastRetryAction.value = () {
            currentFlow.value = _ChatFlowStep.submitting;
            isThinking.value = true;
            thinkingLabel.value = 'Authenticating credentials with AI...';
            scrollToBottom(animate: true);
            context.read<AuthBloc>().add(
              AuthLoginRequested(
                email: logEmail,
                password: logPassword,
              ),
            );
          };

          context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: logEmail,
              password: logPassword,
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
          context.read<AuthModeCubit>().setFormType(AuthFormType.login);
          textController.clear();
          currentFlow.value = _ChatFlowStep.submitting;

          isThinking.value = true;
          thinkingLabel.value = 'Dispatching password reset link...';
          scrollToBottom(animate: true);

          final resetEmail = input;
          lastRetryDescription.value = 'Reset Password';
          lastRetryAction.value = () {
            currentFlow.value = _ChatFlowStep.submitting;
            isThinking.value = true;
            thinkingLabel.value = 'Dispatching password reset link...';
            scrollToBottom(animate: true);
            context.read<AuthBloc>().add(
              AuthResetPasswordRequested(email: resetEmail),
            );
          };

          context.read<AuthBloc>().add(
            AuthResetPasswordRequested(email: resetEmail),
          );

        case _ChatFlowStep.needsEmailConfirmation:
          final otp = input.replaceAll(RegExp('[^0-9]'), '');
          if (otp.length != 6) {
            addUserMessage(input);
            textController.clear();
            simulateBotReply(
              'Please enter a valid 6-digit verification code.',
              isError: true,
              thinkingText: 'Checking verification code...',
            );
            return;
          }

          addUserMessage(otp);
          textController.clear();
          currentFlow.value = _ChatFlowStep.submitting;

          isThinking.value = true;
          thinkingLabel.value = 'Verifying your 6-digit code...';
          scrollToBottom(animate: true);

          final verifyEmail = draftState.email.isNotEmpty
              ? draftState.email
              : (authState.user?.email ?? '');

          lastRetryDescription.value = 'Verify OTP';
          lastRetryAction.value = () {
            currentFlow.value = _ChatFlowStep.submitting;
            isThinking.value = true;
            thinkingLabel.value = 'Verifying your 6-digit code...';
            scrollToBottom(animate: true);
            context.read<AuthBloc>().add(
              AuthVerifyOtpRequested(
                email: verifyEmail,
                token: otp,
              ),
            );
          };

          context.read<AuthBloc>().add(
            AuthVerifyOtpRequested(
              email: verifyEmail,
              token: otp,
            ),
          );

        case _ChatFlowStep.accountActive:
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
        isInputNeeded &&
        currentFlow.value != _ChatFlowStep.initial &&
        currentFlow.value != _ChatFlowStep.accountActive;

    String getHintText() {
      switch (currentFlow.value) {
        case _ChatFlowStep.signUpName:
          return 'Enter your full name';
        case _ChatFlowStep.signUpEmail:
          return 'Enter your email address';
        case _ChatFlowStep.signUpPassword:
          return 'Enter secure password (min. 8 chars)';
        case _ChatFlowStep.loginEmail:
          return 'Enter your registered email';
        case _ChatFlowStep.loginPassword:
          return 'Enter your password';
        case _ChatFlowStep.forgotPasswordEmail:
          return 'Enter your registered email';
        case _ChatFlowStep.needsEmailConfirmation:
          return 'Enter 6-digit code (e.g. 123456)';
        case _ChatFlowStep.accountActive:
          return 'Choose an option below...';
        case _ChatFlowStep.initial:
          return 'Choose an option below...';
        case _ChatFlowStep.submitting:
          return 'Processing...';
      }
    }

    final isPasswordField =
        currentFlow.value == _ChatFlowStep.signUpPassword ||
        currentFlow.value == _ChatFlowStep.loginPassword;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          (current.status == AuthStatus.error &&
              current.errorMessage != previous.errorMessage) ||
          (current.isResetSent && !previous.isResetSent),
      listener: (context, state) {
        if (state.status == AuthStatus.error) {
          isThinking.value = false;
          isTyping.value = false;
          currentFlow.value = _ChatFlowStep.initial;
          final retryCallback = lastRetryAction.value;
          final err = state.errorMessage ??
              'Unable to connect to the study servers. '
                  'Please check your internet connection and try again.';
          final actionDesc = lastRetryDescription.value.isNotEmpty
              ? lastRetryDescription.value
              : 'request';
          addBotMessage(
            'Unable to complete $actionDesc:\n$err\n\n'
            'Tap "Retry Request" below to try again without re-typing.',
            isError: true,
            onRetry: retryCallback != null
                ? () {
                    addUserMessage('🔄 Retry ${lastRetryDescription.value}');
                    retryCallback();
                  }
                : null,
          );
        } else if (state.status == AuthStatus.needsEmailVerification) {
          isThinking.value = false;
          isTyping.value = false;
          currentFlow.value = _ChatFlowStep.needsEmailConfirmation;
          final name = state.user?.displayName ??
              (draftState.displayName.isNotEmpty
                  ? draftState.displayName
                  : 'Scholar');
          final email = state.user?.email ??
              (draftState.email.isNotEmpty
                  ? draftState.email
                  : 'your email address');
          addBotMessage(
            '🎉 Welcome to Kortexify, $name!\n\n'
            'Enter the 6-digit code sent to **$email** to activate '
            'your account.',
          );
        } else if (state.status == AuthStatus.needsOnboarding &&
            state.user != null) {
          isThinking.value = false;
          isTyping.value = false;
          lastRetryAction.value = null;
          lastRetryDescription.value = '';
          currentFlow.value = _ChatFlowStep.accountActive;
          final name = state.user?.displayName ?? 'Scholar';
          addBotMessage(
            '🎉 Welcome to Kortexify, **$name**! Your account is active.\n\n'
            "Let's calibrate your academic track and study profile to "
            'personalize your learning engine.',
          );
        } else if (state.status == AuthStatus.authenticated &&
            state.user != null) {
          isThinking.value = false;
          isTyping.value = false;
          lastRetryAction.value = null;
          lastRetryDescription.value = '';
          currentFlow.value = _ChatFlowStep.accountActive;
          final name = state.user?.displayName ?? 'Scholar';
          addBotMessage(
            '✨ Welcome back, **$name**! Signed in successfully.',
          );
        } else if (state.isResetSent) {
          isThinking.value = false;
          isTyping.value = false;
          currentFlow.value = _ChatFlowStep.initial;
          addBotMessage(
            '📧 A password reset link has been dispatched to your email '
            'address!\n\n'
            'Please check your inbox to create a new password, then sign in.',
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
                                ? 'Connecting to Kortexify neural engine...'
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
                            livePasswordText: currentFlow.value ==
                                    _ChatFlowStep.signUpPassword
                                ? rawInputText.value
                                : null,
                            onStreamingTick: scrollToBottom,
                            onStreamingComplete: () {
                              isTyping.value = false;
                              scrollToBottom(animate: true);
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

                  // 2. Floating Full-Width Action Controls
                  if (isInputNeeded)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (currentFlow.value == _ChatFlowStep.initial) ...[
                            // If last request failed, show 1-tap Retry Pill
                            if (lastRetryAction.value != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _ActionChipButton(
                                      icon: Icons.refresh_rounded,
                                      label:
                                          'Retry ${lastRetryDescription.value}',
                                      isPrimary: true,
                                      onTap: () {
                                        final retry = lastRetryAction.value;
                                        if (retry != null) {
                                          addUserMessage(
                                            '🔄 Retry '
                                            '${lastRetryDescription.value}',
                                          );
                                          retry();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ActionChipButton(
                                      icon: Icons.restart_alt_rounded,
                                      label: 'Start Over',
                                      onTap: () {
                                        lastRetryAction.value = null;
                                        addUserMessage('Start Over');
                                        currentFlow.value =
                                            _ChatFlowStep.initial;
                                        simulateBotReply(
                                          'Sure! How would you like to '
                                          'proceed?',
                                          thinkingText: 'Resetting flow...',
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Row 1: Create Account & Sign In across 50/50 full width
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionChipButton(
                                    icon: Icons.person_add_rounded,
                                    label: 'Create Account',
                                    isPrimary: lastRetryAction.value == null,
                                    onTap: () {
                                      lastRetryAction.value = null;
                                      addUserMessage('Create Account');
                                      draftCubit.updateDisplayName('');
                                      context.read<AuthModeCubit>().setFormType(
                                        AuthFormType.register,
                                      );
                                      currentFlow.value =
                                          _ChatFlowStep.signUpName;
                                      simulateBotReply(
                                        "Let's set up your personalized "
                                        'workspace! What is your full name?',
                                        thinkingText: 'Initializing signup...',
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ActionChipButton(
                                    icon: Icons.login_rounded,
                                    label: 'Sign In',
                                    onTap: () {
                                      lastRetryAction.value = null;
                                      addUserMessage('Sign In');
                                      context.read<AuthModeCubit>().setFormType(
                                        AuthFormType.login,
                                      );
                                      currentFlow.value =
                                          _ChatFlowStep.loginEmail;
                                      simulateBotReply(
                                        'Welcome back! What is your '
                                        'registered email address?',
                                        thinkingText: 'Opening login...',
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Row 2: Full-width Forgot Password button
                            _ActionChipButton(
                              icon: Icons.lock_reset_rounded,
                              label: l10n.authChipForgotPassword,
                              isFullWidth: true,
                              onTap: () {
                                lastRetryAction.value = null;
                                addUserMessage('Forgot Password');
                                context.read<AuthModeCubit>().setFormType(
                                  AuthFormType.login,
                                );
                                currentFlow.value =
                                    _ChatFlowStep.forgotPasswordEmail;
                                simulateBotReply(
                                  'No worries! Enter your email address '
                                  'and '
                                  "I'll send you a password reset link.",
                                  thinkingText: 'Preparing password reset...',
                                );
                              },
                            ),
                            const SizedBox(height: 10),

                            // Row 3: Social Auth Bar
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
                            const SizedBox(height: 4),
                          ] else if (currentFlow.value ==
                              _ChatFlowStep.needsEmailConfirmation) ...[
                            // 1. Resend 6-Digit Code
                            _ActionChipButton(
                              icon: Icons.mark_email_read_rounded,
                              label: 'Resend 6-Digit Code',
                              isFullWidth: true,
                              onTap: () {
                                lastRetryAction.value = null;
                                addUserMessage('Resend 6-Digit Code');
                                final email = authState.user?.email ??
                                    (draftState.email.isNotEmpty
                                        ? draftState.email
                                        : 'your email address');
                                simulateBotReply(
                                  '📬 A fresh 6-digit code has been '
                                  'dispatched to $email! Enter the code below.',
                                  thinkingText: 'Dispatching new code...',
                                );
                              },
                            ),
                            const SizedBox(height: 8),

                            // 2. Reset / Start Over
                            _ActionChipButton(
                              icon: Icons.arrow_back_rounded,
                              label: 'Start Over / Use Different Email',
                              isFullWidth: true,
                              onTap: () {
                                lastRetryAction.value = null;
                                addUserMessage('Start Over');
                                currentFlow.value = _ChatFlowStep.initial;
                                simulateBotReply(
                                  'No problem! How would you like to '
                                  'get started?',
                                  thinkingText: 'Resetting...',
                                );
                              },
                            ),
                          ] else if (currentFlow.value ==
                              _ChatFlowStep.accountActive) ...[
                            // 1. Calibrate Study Profile
                            _ActionChipButton(
                              icon: Icons.rocket_launch_rounded,
                              label: '🚀 Calibrate Study Profile',
                              isPrimary: true,
                              isFullWidth: true,
                              onTap: () {
                                addUserMessage(
                                  "Let's calibrate my study profile",
                                );
                                unawaited(
                                  context.router.replace(
                                    const OnboardingCalibrationRoute(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),

                            // 2. Go to Dashboard
                            _ActionChipButton(
                              icon: Icons.dashboard_customize_rounded,
                              label: '🎯 Go to Dashboard',
                              isFullWidth: true,
                              onTap: () {
                                addUserMessage('Go to Dashboard');
                                unawaited(
                                  context.router.replace(
                                    const DashboardRoute(),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            _ActionChipButton(
                              icon: Icons.arrow_back_rounded,
                              label: 'Start Over / Choose Other Option',
                              isFullWidth: true,
                              onTap: () {
                                lastRetryAction.value = null;
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

                  // 3. Dynamic Bottom Chat Input Bar
                  // (Floating Glassmorphic Pill)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isTextFieldVisible
                        ? Builder(
                            builder: (context) {
                              final isObscured = isPasswordObscured.value;
                              final borderHighlight = isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(60)
                                  : colors.surfaceBorderHighlight.withAlpha(90);
                              final eyeIcon = isObscured
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined;
                              final eyeTooltip = isObscured
                                  ? 'Show password'
                                  : 'Hide password';
                              final side = BorderSide(
                                color: inputBorderColor,
                                width: 1.2,
                              );
                              final pillRadius = BorderRadius.circular(24);

                              return Padding(
                                key: ValueKey(currentFlow.value),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                child: Row(
                                  children: [
                                        Expanded(
                                          child: Semantics(
                                            textField: true,
                                            label: l10n.authChatInputSemantics,
                                            hint: getHintText(),
                                            child: ClipRRect(
                                              borderRadius: pillRadius,
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
                                                              _ChatFlowStep
                                                                  .signUpName
                                                          ? TextCapitalization
                                                              .words
                                                          : TextCapitalization
                                                              .none,
                                                  keyboardType: isPasswordField
                                                      ? TextInputType
                                                          .visiblePassword
                                                      : (currentFlow.value ==
                                                              _ChatFlowStep
                                                                  .signUpName
                                                          ? TextInputType.name
                                                          : TextInputType
                                                              .emailAddress),
                                                  obscureText:
                                                      isPasswordField &&
                                                          isObscured,
                                                  style: typography
                                                      .callout.regular
                                                      .copyWith(
                                                        color:
                                                            colors.textPrimary,
                                                      ),
                                                  decoration: InputDecoration(
                                                    hintText: getHintText(),
                                                    hintStyle: typography
                                                        .footnote.regular
                                                        .copyWith(
                                                          color:
                                                              colors.textMuted,
                                                          fontSize: 13,
                                                        ),
                                                    filled: true,
                                                    fillColor: isDark
                                                        ? colors
                                                            .surfaceSecondary
                                                            .withAlpha(190)
                                                        : colors.surfacePrimary
                                                            .withAlpha(220),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 18,
                                                          vertical: 12,
                                                        ),
                                                    suffixIcon: isPasswordField
                                                        ? IconButton(
                                                            tooltip: eyeTooltip,
                                                            icon: Icon(
                                                              eyeIcon,
                                                              size: 19,
                                                              color: colors
                                                                  .textMuted,
                                                            ),
                                                            onPressed: () {
                                                              isPasswordObscured
                                                                      .value =
                                                                  !isObscured;
                                                            },
                                                          )
                                                        : null,
                                                    border: OutlineInputBorder(
                                                      borderRadius: pillRadius,
                                                      borderSide: side,
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              pillRadius,
                                                          borderSide: side,
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              pillRadius,
                                                          borderSide:
                                                              BorderSide(
                                                            color:
                                                                colors.primary,
                                                            width: 1.6,
                                                          ),
                                                        ),
                                                  ),
                                                  onSubmitted: (_) =>
                                                      handleSend(),
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
                                                    : borderHighlight,
                                                boxShadow: hasInputText.value
                                                    ? [
                                                        BoxShadow(
                                                          color: colors.primary
                                                              .withAlpha(80),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                              0, 3),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.arrow_upward_rounded,
                                                color: hasInputText.value
                                                    ? Colors.white
                                                    : colors.textMuted
                                                        .withAlpha(140),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
    this.livePasswordText,
    this.onStreamingTick,
    this.onStreamingComplete,
  });

  final ChatAuthMessage message;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final bool isStreaming;
  final String? livePasswordText;
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
                                ? const Color(0xFF450A0A).withAlpha(220)
                                : const Color(0xFFFFF1F2).withAlpha(245))
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
                            ? const Color(0xFFEF4444)
                            : (isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(70)
                                  : colors.surfaceBorder.withAlpha(140)),
                        width: isError ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isError
                              ? const Color(
                                  0xFFEF4444,
                                ).withAlpha(isDark ? 60 : 30)
                              : Colors.black.withAlpha(isDark ? 40 : 10),
                          blurRadius: isError ? 14 : 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isError) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Syllabot Alert',
                                  style: typography.caption.bold.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        TypewriterText(
                          text: message.text,
                          isStreaming: isStreaming,
                          onTick: onStreamingTick,
                          onComplete: onStreamingComplete,
                          style: typography.callout.regular.copyWith(
                            color: isError
                                ? (isDark
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFF991B1B))
                                : colors.textPrimary,
                            fontWeight: isError
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        if (message.step == ChatAuthStep.askPassword ||
                            message.text.contains(
                              'Almost there! Set a secure password',
                            )) ...[
                          _VerticalPasswordRequirementsList(
                            password: livePasswordText ?? '',
                            colors: colors,
                            typography: typography,
                            isDark: isDark,
                          ),
                        ],
                        if (isError && message.onRetry != null) ...[
                          const SizedBox(height: 10),
                          Semantics(
                            button: true,
                            label: 'Retry last request',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: message.onRetry,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withAlpha(
                                      isDark ? 60 : 30,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withAlpha(
                                        140,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.refresh_rounded,
                                        size: 15,
                                        color: Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Retry Request',
                                        style: typography.caption.bold.copyWith(
                                          color: isDark
                                              ? const Color(0xFFFCA5A5)
                                              : const Color(0xFFB91C1C),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.isPrimary = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isPrimary;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: 'Action: $label',
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          onTap();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isPrimary
                    ? colors.primary.withAlpha(isDark ? 220 : 240)
                    : (isDark
                          ? colors.surfaceSecondary.withAlpha(170)
                          : colors.surfacePrimary.withAlpha(220)),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: isPrimary ? Colors.white : colors.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.caption.semiBold.copyWith(
                        color: isPrimary ? Colors.white : colors.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated vertical checklist card displaying real-time password requirements
/// inside the chat bubble right below the password prompt message.
class _VerticalPasswordRequirementsList extends StatelessWidget {
  const _VerticalPasswordRequirementsList({
    required this.password,
    required this.colors,
    required this.typography,
    required this.isDark,
  });

  final String password;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasMinLength = password.length >= 8;
    final hasNumber = RegExp('[0-9]').hasMatch(password);
    final hasUppercase = RegExp('[A-Z]').hasMatch(password);
    final hasSpecial =
        RegExp(r'[!@#$%^&*(),.?":{}|<>/_+\-=\[\]\\;`~]').hasMatch(password);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withAlpha(140)
            : colors.surfaceSecondary.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(50)
              : colors.surfaceBorder.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PasswordRequirementItem(
            isMet: hasMinLength,
            label: '8+ characters',
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: 6),
          _PasswordRequirementItem(
            isMet: hasNumber,
            label: 'Includes number (0-9)',
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: 6),
          _PasswordRequirementItem(
            isMet: hasUppercase,
            label: 'Uppercase letter (A-Z)',
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: 6),
          _PasswordRequirementItem(
            isMet: hasSpecial,
            label: 'Special character (!@#...)',
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }
}

/// Individual requirement row item with a round check animating from an
/// empty circle to a filled circle and label transitioning to success color.
class _PasswordRequirementItem extends StatelessWidget {
  const _PasswordRequirementItem({
    required this.isMet,
    required this.label,
    required this.colors,
    required this.typography,
  });

  final bool isMet;
  final String label;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    const successColor = Color(0xFF10B981);
    final textColor = isMet ? successColor : colors.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMet ? successColor : Colors.transparent,
              border: Border.all(
                color: isMet ? successColor : colors.surfaceBorderHighlight,
                width: 1.4,
              ),
              boxShadow: isMet
                  ? [
                      BoxShadow(
                        color: successColor.withAlpha(80),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            child: isMet
                ? const Center(
                    child: Icon(
                      Icons.check,
                      size: 10,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: typography.caption.medium.copyWith(
              color: textColor,
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w600 : null,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
