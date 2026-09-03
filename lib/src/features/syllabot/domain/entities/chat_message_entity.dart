import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';

enum MessageSender {
  user,
  syllabot,
}

/// Domain entity representing a rich chat message bubble with LaTeX snippets,
/// engine origin, and streaming lifecycle states.
class ChatMessageEntity extends Equatable {
  const ChatMessageEntity({
    required this.id,
    required this.sessionId,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.latexSnippets = const [],
    this.engineType = ExecutionEngineType.cloudRemote,
    this.tokensCount = 0,
    this.isStreaming = false,
    this.isError = false,
    this.onRetry,
  });

  final String id;
  final String sessionId;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final List<String> latexSnippets;
  final ExecutionEngineType engineType;
  final int tokensCount;
  final bool isStreaming;
  final bool isError;
  final VoidCallback? onRetry;

  ChatMessageEntity copyWith({
    String? id,
    String? sessionId,
    MessageSender? sender,
    String? text,
    DateTime? timestamp,
    List<String>? latexSnippets,
    ExecutionEngineType? engineType,
    int? tokensCount,
    bool? isStreaming,
    bool? isError,
    VoidCallback? onRetry,
  }) {
    return ChatMessageEntity(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      latexSnippets: latexSnippets ?? this.latexSnippets,
      engineType: engineType ?? this.engineType,
      tokensCount: tokensCount ?? this.tokensCount,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
      onRetry: onRetry ?? this.onRetry,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    sender,
    text,
    timestamp,
    latexSnippets,
    engineType,
    tokensCount,
    isStreaming,
    isError,
    onRetry != null,
  ];
}
