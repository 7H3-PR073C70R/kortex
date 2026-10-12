import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/domain/entities/chat_auth_message.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_action_controls.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_bubbles.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_flow_coordinator.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_flow_step.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_input_bar.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_post_login_coordinator.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Conversational AI Chat authentication view with randomized quotes,
/// live auto-scrolling, full-width actions, and synchronized draft state.
class AuthChatView extends HookWidget {
  const AuthChatView({
    required this.onGooglePressed,
    required this.onForgotPassword,
    this.onApplePressed,
    this.postLoginCoordinator,
    super.key,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onForgotPassword;
  final VoidCallback? onApplePressed;
  final AuthPostLoginCoordinator? postLoginCoordinator;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final coordinator =
        postLoginCoordinator ?? const AuthPostLoginCoordinator();

    final draftCubit = context.read<AuthDraftCubit>();
    final draftState = context.watch<AuthDraftCubit>().state;
    final authState = context.watch<AuthBloc>().state;

    final textController = useTextEditingController();
    final scrollController = useScrollController();

    final isThinking = useState<bool>(false);
    final thinkingLabel = useState<String>(l10n.authThinking);
    final isTyping = useState<bool>(false);
    final latestBotMsgId = useState<String>('');
    final hasInputText = useState<bool>(false);
    final isPasswordObscured = useState<bool>(true);
    final rawInputText = useState<String>('');

    final lastRetryAction = useState<VoidCallback?>(null);
    final lastRetryDescription = useState<String>('');

    final currentFlow = useState<ChatFlowStep>(ChatFlowStep.initial);
    final initialGreeting = useMemoized(generateAuthChatInitialGreeting);

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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients &&
              scrollController.position.hasContentDimensions) {
            if (animate) {
              unawaited(
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutQuad,
                ),
              );
            } else {
              scrollController
                  .jumpTo(scrollController.position.maxScrollExtent);
            }
          }
        });
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
      String? thinkingText,
      Duration delay = const Duration(milliseconds: 450),
      bool isError = false,
      ChatAuthStep step = ChatAuthStep.initial,
      VoidCallback? onRetry,
      VoidCallback? onComplete,
    }) {
      isThinking.value = true;
      thinkingLabel.value = thinkingText ?? l10n.authThinking;
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

    void submitRegistration({String? promoOverride}) {
      currentFlow.value = ChatFlowStep.submitting;

      isThinking.value = true;
      thinkingLabel.value = 'Creating your Kortexify neural profile...';
      scrollToBottom(animate: true);

      final currentDraft = context.read<AuthDraftCubit>().state;
      final regEmail =
          currentDraft.email.isNotEmpty ? currentDraft.email : draftState.email;
      final regPassword = currentDraft.password.isNotEmpty
          ? currentDraft.password
          : draftState.password;
      final regName = currentDraft.displayName.isNotEmpty
          ? currentDraft.displayName
          : draftState.displayName;
      final regPromo = (promoOverride ??
              (currentDraft.promoCode.isNotEmpty
                  ? currentDraft.promoCode
                  : draftState.promoCode))
          .trim();

      unawaited(coordinator.saveUserDisplayName(regName));

      void dispatchRegister() {
        context.read<AuthBloc>().add(
          AuthRegisterRequested(
            email: regEmail,
            password: regPassword,
            displayName: regName.isNotEmpty ? regName : null,
            promoCode: regPromo.isNotEmpty ? regPromo : null,
          ),
        );
      }

      lastRetryDescription.value = 'Sign Up';
      lastRetryAction.value = () {
        currentFlow.value = ChatFlowStep.submitting;
        isThinking.value = true;
        thinkingLabel.value = 'Creating your Kortexify neural profile...';
        scrollToBottom(animate: true);
        dispatchRegister();
      };

      dispatchRegister();
    }

    void handleSend() {
      final input = textController.text.trim();
      if (input.isEmpty) return;

      textController.clear();
      hasInputText.value = false;

      AuthChatFlowCoordinator(
        context: context,
        currentFlow: currentFlow,
        coordinator: coordinator,
        onAddUserMessage: addUserMessage,
        onSimulateBotReply: simulateBotReply,
        onSubmitRegistration: submitRegistration,
        isThinking: isThinking,
        thinkingLabel: thinkingLabel,
        lastRetryAction: lastRetryAction,
        lastRetryDescription: lastRetryDescription,
        onScrollToBottom: () => scrollToBottom(animate: true),
        fallbackEmail: authState.user?.email ?? '',
      ).handleInput(input);
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          isThinking.value = false;
          isTyping.value = false;
          currentFlow.value = ChatFlowStep.initial;

          addBotMessage(
            '⚠️ ${state.errorMessage}',
            isError: true,
            onRetry: lastRetryAction.value != null
                ? () {
                    final retry = lastRetryAction.value;
                    if (retry != null) {
                      addUserMessage(
                        '🔄 Retry ${lastRetryDescription.value}',
                      );
                      retry();
                    }
                  }
                : null,
          );
        } else if (state.status == AuthStatus.needsEmailVerification) {
          isThinking.value = false;
          isTyping.value = false;
          lastRetryAction.value = null;
          lastRetryDescription.value = '';
          currentFlow.value = ChatFlowStep.needsEmailConfirmation;
          final email = state.user?.email ??
              (draftState.email.isNotEmpty
                  ? draftState.email
                  : 'your email address');
          final name = state.user?.displayName ??
              (draftState.displayName.isNotEmpty
                  ? draftState.displayName
                  : 'Scholar');
          addBotMessage(
            '🎉 Welcome to Kortexify, $name!\n\n'
            'Enter the 6-digit code sent to **$email** to activate your account.',
          );
        } else if (state.status == AuthStatus.needsOnboarding &&
            state.user != null) {
          isThinking.value = false;
          isTyping.value = false;
          lastRetryAction.value = null;
          lastRetryDescription.value = '';
          currentFlow.value = ChatFlowStep.accountActive;
          final name = state.user?.displayName ?? 'Scholar';
          final newlyRegistered = coordinator.isNewlyRegistered();
          if (newlyRegistered) {
            addBotMessage(
              '🎉 Welcome to Kortexify, **$name**! Your account is active.\n\n'
              "Let's calibrate your academic track and study profile to personalize your learning engine.",
            );
          } else {
            addBotMessage(
              '👋 Welcome back, **$name**!\n\n'
              "Let's calibrate your academic track and study profile to personalize your learning engine.",
            );
          }
        } else if (state.status == AuthStatus.authenticated &&
            state.user != null) {
          isThinking.value = false;
          isTyping.value = false;
          lastRetryAction.value = null;
          lastRetryDescription.value = '';
          final name = state.user?.displayName ?? 'Scholar';

          final isCalibrated = await coordinator.checkIsCalibrated(state);

          if (isCalibrated) {
            addBotMessage(
              '✨ Welcome back, **$name**! Redirecting to your Dashboard...',
            );
            Timer(const Duration(milliseconds: 700), () {
              if (context.mounted) {
                unawaited(context.router.replaceAll([const MainRoute()]));
              }
            });
          } else {
            currentFlow.value = ChatFlowStep.accountActive;
            addBotMessage(
              '✨ Welcome back, **$name**! Signed in successfully.\n\n'
              "Let's calibrate your academic track and study profile to personalize your learning engine.",
            );
          }
        } else if (state.isResetSent) {
          isThinking.value = false;
          isTyping.value = false;
          currentFlow.value = ChatFlowStep.initial;
          addBotMessage(
            '📧 A password reset link has been dispatched to your email address!\n\n'
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
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: messages.value.length +
                          (isThinking.value ||
                                  (authState.isLoading &&
                                      currentFlow.value ==
                                          ChatFlowStep.submitting)
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.value.length) {
                          return AuthThinkingBubble(
                            statusText: authState.isLoading
                                ? 'Connecting to Kortexify neural engine...'
                                : thinkingLabel.value,
                          );
                        }

                        final msg = messages.value[index];
                        final isBot = msg.sender == ChatAuthSender.syllabot;
                        final isStreaming = isBot &&
                            msg.id == latestBotMsgId.value &&
                            isTyping.value;

                        if (isBot) {
                          return AuthBotMessageBubble(
                            message: msg,
                            colors: colors,
                            typography: typography,
                            isDark: isDark,
                            isStreaming: isStreaming,
                            livePasswordText: currentFlow.value ==
                                    ChatFlowStep.signUpPassword
                                ? rawInputText.value
                                : null,
                            onStreamingTick: scrollToBottom,
                            onStreamingComplete: () {
                              isTyping.value = false;
                              scrollToBottom(animate: true);
                            },
                          );
                        } else {
                          return AuthUserMessageBubble(
                            message: msg,
                            colors: colors,
                            typography: typography,
                          );
                        }
                      },
                    ),
                  ),

                  // 2. Floating Full-Width Action Controls
                  AuthChatActionControls(
                    currentFlow: currentFlow.value,
                    isInputNeeded: currentFlow.value.isInputNeeded,
                    lastRetryAction: lastRetryAction,
                    lastRetryDescription: lastRetryDescription,
                    isAuthLoading: authState.isLoading,
                    userEmail: authState.user?.email ??
                        (draftState.email.isNotEmpty
                            ? draftState.email
                            : 'your email address'),
                    onGooglePressed: onGooglePressed,
                    onApplePressed: onApplePressed ??
                        () async {
                          final result = await coordinator.signInWithApple();
                          if (result != null && context.mounted) {
                            context.read<AuthBloc>().add(
                              AuthSocialLoginRequested(
                                provider: result.provider,
                                idToken: result.idToken,
                                rawNonce: result.rawNonce,
                              ),
                            );
                          }
                        },
                    onAddUserMessage: addUserMessage,
                    onSimulateBotReply: simulateBotReply,
                    onSubmitRegistration: submitRegistration,
                    onSetFormType: context.read<AuthModeCubit>().setFormType,
                    onUpdateDisplayName: draftCubit.updateDisplayName,
                    onSetFlowStep: (step) => currentFlow.value = step,
                  ),

                  // 3. Dynamic Bottom Chat Input Bar
                  AuthChatInputBar(
                    isTextFieldVisible: currentFlow.value.isTextFieldVisible,
                    currentFlow: currentFlow.value,
                    textController: textController,
                    isPasswordObscured: isPasswordObscured,
                    hasInputText: hasInputText,
                    isPasswordField: currentFlow.value.isPasswordField,
                    hintText: currentFlow.value.hintText,
                    onSend: handleSend,
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
