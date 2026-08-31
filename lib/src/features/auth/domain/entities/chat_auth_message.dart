import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum ChatAuthSender {
  syllabot,
  user,
}

enum ChatAuthStep {
  initial,
  askIntent,
  askName,
  askEmail,
  askPassword,
  askResetEmail,
  submitting,
  completed,
  error,
}

/// Domain entity representing a conversational authentication message
/// or prompt with optional retry action for failed requests.
class ChatAuthMessage extends Equatable {
  const ChatAuthMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.step = ChatAuthStep.initial,
    this.isPasswordInput = false,
    this.isError = false,
    this.sensitiveValue,
    this.onRetry,
  });

  final String id;
  final ChatAuthSender sender;
  final String text;
  final DateTime timestamp;
  final ChatAuthStep step;
  final bool isPasswordInput;
  final bool isError;
  final String? sensitiveValue;
  final VoidCallback? onRetry;

  @override
  List<Object?> get props => [
        id,
        sender,
        text,
        timestamp,
        step,
        isPasswordInput,
        isError,
        sensitiveValue,
        onRetry != null,
      ];
}
