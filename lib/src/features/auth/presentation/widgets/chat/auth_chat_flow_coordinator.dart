import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/auth/domain/entities/chat_auth_message.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_flow_step.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_post_login_coordinator.dart';

/// Coordinator that processes user chat input text across the various [ChatFlowStep] stages
/// and dispatches corresponding validation, bot responses, or auth events.
class AuthChatFlowCoordinator {
  const AuthChatFlowCoordinator({
    required this.context,
    required this.currentFlow,
    required this.coordinator,
    required this.onAddUserMessage,
    required this.onSimulateBotReply,
    required this.onSubmitRegistration,
    required this.isThinking,
    required this.thinkingLabel,
    required this.lastRetryAction,
    required this.lastRetryDescription,
    required this.onScrollToBottom,
    required this.fallbackEmail,
  });

  final BuildContext context;
  final ValueNotifier<ChatFlowStep> currentFlow;
  final AuthPostLoginCoordinator coordinator;
  final void Function(String text, {bool isPassword}) onAddUserMessage;
  final void Function(
    String replyText, {
    String? thinkingText,
    bool isError,
    ChatAuthStep step,
  }) onSimulateBotReply;
  final void Function({String? promoOverride}) onSubmitRegistration;
  final ValueNotifier<bool> isThinking;
  final ValueNotifier<String> thinkingLabel;
  final ValueNotifier<VoidCallback?> lastRetryAction;
  final ValueNotifier<String> lastRetryDescription;
  final VoidCallback onScrollToBottom;
  final String fallbackEmail;

  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  /// Dispatches the user input string according to the active chat flow step.
  void handleInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    final draftCubit = context.read<AuthDraftCubit>();
    final draftState = draftCubit.state;

    switch (currentFlow.value) {
      case ChatFlowStep.signUpName:
        onAddUserMessage(trimmed);
        draftCubit.updateDisplayName(trimmed);
        unawaited(coordinator.saveUserDisplayName(trimmed));
        currentFlow.value = ChatFlowStep.signUpEmail;
        onSimulateBotReply(
          'Nice to meet you, **$trimmed**! 🎓 What is your student email address?',
          thinkingText: 'Updating profile...',
        );

      case ChatFlowStep.signUpEmail:
        if (!_emailRegex.hasMatch(trimmed)) {
          onAddUserMessage(trimmed);
          onSimulateBotReply(
            'Hmm, that does not look like a valid email address. Could you double-check and enter it again?',
            isError: true,
            thinkingText: 'Validating email...',
          );
          return;
        }
        onAddUserMessage(trimmed);
        draftCubit.updateEmail(trimmed);
        currentFlow.value = ChatFlowStep.signUpPassword;
        onSimulateBotReply(
          'Almost there! Set a secure password for your workspace. '
          'It should be at least 8 characters with letters, numbers, and symbols.',
          step: ChatAuthStep.askPassword,
          thinkingText: 'Securing workspace...',
        );

      case ChatFlowStep.signUpPassword:
        final hasMinLength = trimmed.length >= 8;
        final hasNumber = RegExp('[0-9]').hasMatch(trimmed);
        final hasUppercase = RegExp('[A-Z]').hasMatch(trimmed);
        final hasSpecial = RegExp(
          r'[!@#$%^&*(),.?":{}|<>/_+\-=\[\]\\;`~]',
        ).hasMatch(trimmed);

        if (!hasMinLength || !hasNumber || !hasUppercase || !hasSpecial) {
          onAddUserMessage(trimmed, isPassword: true);
          onSimulateBotReply(
            'Your password is not quite strong enough yet. Please make sure it meets all the requirements shown above!',
            isError: true,
            step: ChatAuthStep.askPassword,
            thinkingText: 'Verifying password strength...',
          );
          return;
        }
        onAddUserMessage(trimmed, isPassword: true);
        draftCubit.updatePassword(trimmed);
        currentFlow.value = ChatFlowStep.signUpPromoCode;
        onSimulateBotReply(
          'Awesome! Do you have an educational access code or campus promo pass?',
          thinkingText: 'Checking promo benefits...',
        );

      case ChatFlowStep.signUpPromoCode:
        onAddUserMessage(trimmed);
        draftCubit.updatePromoCode(trimmed);
        onSubmitRegistration(promoOverride: trimmed);

      case ChatFlowStep.loginEmail:
        if (!_emailRegex.hasMatch(trimmed)) {
          onAddUserMessage(trimmed);
          onSimulateBotReply(
            'Please enter a valid email address so I can find your profile.',
            isError: true,
            thinkingText: 'Checking email format...',
          );
          return;
        }
        onAddUserMessage(trimmed);
        draftCubit.updateEmail(trimmed);
        currentFlow.value = ChatFlowStep.loginPassword;
        onSimulateBotReply(
          'Great. Now enter your password to sign in.',
          step: ChatAuthStep.askPassword,
          thinkingText: 'Locating account...',
        );

      case ChatFlowStep.loginPassword:
        onAddUserMessage(trimmed, isPassword: true);
        draftCubit.updatePassword(trimmed);
        currentFlow.value = ChatFlowStep.submitting;

        isThinking.value = true;
        thinkingLabel.value = 'Verifying your credentials...';
        onScrollToBottom();

        final loginEmail =
            draftState.email.isNotEmpty ? draftState.email : fallbackEmail;

        lastRetryDescription.value = 'Sign In';
        lastRetryAction.value = () {
          currentFlow.value = ChatFlowStep.submitting;
          isThinking.value = true;
          thinkingLabel.value = 'Verifying your credentials...';
          onScrollToBottom();
          context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: loginEmail,
              password: trimmed,
            ),
          );
        };

        context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: loginEmail,
            password: trimmed,
          ),
        );

      case ChatFlowStep.forgotPasswordEmail:
        if (!_emailRegex.hasMatch(trimmed)) {
          onAddUserMessage(trimmed);
          onSimulateBotReply(
            'Please provide a valid email address to receive your reset link.',
            isError: true,
            thinkingText: 'Checking email format...',
          );
          return;
        }
        onAddUserMessage(trimmed);
        currentFlow.value = ChatFlowStep.submitting;

        isThinking.value = true;
        thinkingLabel.value = 'Sending password reset link...';
        onScrollToBottom();

        context.read<AuthBloc>().add(
          AuthResetPasswordRequested(email: trimmed),
        );

      case ChatFlowStep.needsEmailConfirmation:
        final otp = trimmed.replaceAll(' ', '').trim();
        if (otp.length != 6 || int.tryParse(otp) == null) {
          onAddUserMessage(trimmed);
          onSimulateBotReply(
            'Please enter the complete 6-digit confirmation code from your email.',
            isError: true,
            thinkingText: 'Verifying code format...',
          );
          return;
        }
        onAddUserMessage(trimmed);
        currentFlow.value = ChatFlowStep.submitting;
        isThinking.value = true;
        thinkingLabel.value = 'Verifying confirmation code...';
        onScrollToBottom();

        final email =
            draftState.email.isNotEmpty ? draftState.email : fallbackEmail;

        context.read<AuthBloc>().add(
          AuthVerifyOtpRequested(
            email: email,
            token: otp,
          ),
        );

      case ChatFlowStep.initial:
      case ChatFlowStep.accountActive:
      case ChatFlowStep.submitting:
        break;
    }
  }
}
