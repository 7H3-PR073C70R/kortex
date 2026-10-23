import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_shell.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_action_chip_button.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_flow_step.dart';
import 'package:kortex/src/features/auth/presentation/widgets/social_auth_bar.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Floating full-width action button controls rendered dynamically according
/// to the active [ChatFlowStep].
class AuthChatActionControls extends StatelessWidget {
  const AuthChatActionControls({
    required this.currentFlow,
    required this.isInputNeeded,
    required this.lastRetryAction,
    required this.lastRetryDescription,
    required this.isAuthLoading,
    required this.userEmail,
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.onAddUserMessage,
    required this.onSimulateBotReply,
    required this.onSubmitRegistration,
    required this.onSetFormType,
    required this.onUpdateDisplayName,
    required this.onSetFlowStep,
    super.key,
  });

  final ChatFlowStep currentFlow;
  final bool isInputNeeded;
  final ValueNotifier<VoidCallback?> lastRetryAction;
  final ValueNotifier<String> lastRetryDescription;
  final bool isAuthLoading;
  final String userEmail;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final void Function(String text, {bool isPassword}) onAddUserMessage;
  final void Function(String replyText, {String? thinkingText})
      onSimulateBotReply;
  final void Function({String? promoOverride}) onSubmitRegistration;
  final void Function(AuthFormType type) onSetFormType;
  final void Function(String name) onUpdateDisplayName;
  final void Function(ChatFlowStep step) onSetFlowStep;

  @override
  Widget build(BuildContext context) {
    if (!isInputNeeded) return const SizedBox.shrink();

    final l10n = context.l10n;

    return RevealOnMount(
      key: ValueKey(currentFlow),
      durationMs: 360,
      slideY: 0.08,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (currentFlow == ChatFlowStep.initial) ...[
              // If last request failed, show 1-tap Retry Pill
              if (lastRetryAction.value != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: AuthChatActionChipButton(
                        icon: Icons.refresh_rounded,
                        label: 'Retry ${lastRetryDescription.value}',
                        isPrimary: true,
                        onTap: () {
                          final retry = lastRetryAction.value;
                          if (retry != null) {
                            onAddUserMessage(
                              '🔄 Retry ${lastRetryDescription.value}',
                            );
                            retry();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AuthChatActionChipButton(
                        icon: Icons.restart_alt_rounded,
                        label: 'Start Over',
                        onTap: () {
                          lastRetryAction.value = null;
                          onAddUserMessage('Start Over');
                          onSetFlowStep(ChatFlowStep.initial);
                          onSimulateBotReply(
                            'Sure! How would you like to proceed?',
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
                    child: AuthChatActionChipButton(
                      icon: Icons.person_add_rounded,
                      label: 'Create Account',
                      isPrimary: lastRetryAction.value == null,
                      onTap: () {
                        lastRetryAction.value = null;
                        onAddUserMessage('Create Account');
                        onUpdateDisplayName('');
                        onSetFormType(AuthFormType.register);
                        onSetFlowStep(ChatFlowStep.signUpName);
                        onSimulateBotReply(
                          "Let's set up your personalized workspace! What is your full name?",
                          thinkingText: 'Initializing signup...',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AuthChatActionChipButton(
                      icon: Icons.login_rounded,
                      label: 'Sign In',
                      onTap: () {
                        lastRetryAction.value = null;
                        onAddUserMessage('Sign In');
                        onSetFormType(AuthFormType.login);
                        onSetFlowStep(ChatFlowStep.loginEmail);
                        onSimulateBotReply(
                          'Welcome back! What is your registered email address?',
                          thinkingText: 'Opening login...',
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Full-width Forgot Password button
              AuthChatActionChipButton(
                icon: Icons.lock_reset_rounded,
                label: l10n.authChipForgotPassword,
                isFullWidth: true,
                onTap: () {
                  lastRetryAction.value = null;
                  onAddUserMessage('Forgot Password');
                  onSetFormType(AuthFormType.login);
                  onSetFlowStep(ChatFlowStep.forgotPasswordEmail);
                  onSimulateBotReply(
                    "No worries! Enter your email address and I'll send you a password reset link.",
                    thinkingText: 'Preparing password reset...',
                  );
                },
              ),
              const SizedBox(height: 10),

              // Row 3: Social Auth Bar
              SocialAuthBar(
                isLoading: isAuthLoading,
                onGooglePressed: onGooglePressed,
                onApplePressed: onApplePressed,
              ),
              const SizedBox(height: 4),
            ] else if (currentFlow == ChatFlowStep.signUpPromoCode) ...[
              Row(
                children: [
                  Expanded(
                    child: AuthChatActionChipButton(
                      icon: Icons.card_giftcard_rounded,
                      label: '🎁 Have Promo Code',
                      isPrimary: true,
                      onTap: () {
                        onSimulateBotReply(
                          'Please type your promo code in the text field below and press Send.',
                          thinkingText: 'Awaiting promo code...',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AuthChatActionChipButton(
                      icon: Icons.rocket_launch_rounded,
                      label: 'Skip & Register 🚀',
                      onTap: () {
                        onAddUserMessage('Skip Promo Code');
                        onSubmitRegistration(promoOverride: '');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AuthChatActionChipButton(
                icon: Icons.arrow_back_rounded,
                label: 'Start Over / Choose Other Option',
                isFullWidth: true,
                onTap: () {
                  lastRetryAction.value = null;
                  onAddUserMessage('Start Over');
                  onSetFlowStep(ChatFlowStep.initial);
                  onSimulateBotReply(
                    'No problem! How would you like to get started?',
                    thinkingText: 'Resetting...',
                  );
                },
              ),
            ] else if (currentFlow ==
                ChatFlowStep.needsEmailConfirmation) ...[
              // 1. Resend 6-Digit Code
              AuthChatActionChipButton(
                icon: Icons.mark_email_read_rounded,
                label: 'Resend 6-Digit Code',
                isFullWidth: true,
                onTap: () {
                  lastRetryAction.value = null;
                  onAddUserMessage('Resend 6-Digit Code');
                  onSimulateBotReply(
                    '📬 A fresh 6-digit code has been dispatched to $userEmail! Enter the code below.',
                    thinkingText: 'Dispatching new code...',
                  );
                },
              ),
              const SizedBox(height: 8),

              // 2. Reset / Start Over
              AuthChatActionChipButton(
                icon: Icons.arrow_back_rounded,
                label: 'Start Over / Use Different Email',
                isFullWidth: true,
                onTap: () {
                  lastRetryAction.value = null;
                  onAddUserMessage('Start Over');
                  onSetFlowStep(ChatFlowStep.initial);
                  onSimulateBotReply(
                    'No problem! How would you like to get started?',
                    thinkingText: 'Resetting...',
                  );
                },
              ),
            ] else if (currentFlow == ChatFlowStep.accountActive) ...[
              // 1. Calibrate Study Profile
              AuthChatActionChipButton(
                icon: Icons.rocket_launch_rounded,
                label: '🚀 Calibrate Study Profile',
                isPrimary: true,
                isFullWidth: true,
                onTap: () {
                  onAddUserMessage("Let's calibrate my study profile");
                  unawaited(
                    context.router.replace(
                      const OnboardingCalibrationRoute(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 2. Go to Dashboard
              AuthChatActionChipButton(
                icon: Icons.dashboard_customize_rounded,
                label: '🎯 Go to Dashboard',
                isFullWidth: true,
                onTap: () {
                  onAddUserMessage('Go to Dashboard');
                  unawaited(
                    context.router.replace(
                      DashboardRoute(),
                    ),
                  );
                },
              ),
            ] else ...[
              AuthChatActionChipButton(
                icon: Icons.arrow_back_rounded,
                label: 'Start Over / Choose Other Option',
                isFullWidth: true,
                onTap: () {
                  lastRetryAction.value = null;
                  onAddUserMessage('Start Over');
                  onSetFlowStep(ChatFlowStep.initial);
                  onSimulateBotReply(
                    'No problem! How would you like to get started?',
                    thinkingText: 'Resetting...',
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
