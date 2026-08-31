import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

@immutable
sealed class SyllabotChatEvent {
  const SyllabotChatEvent();
}

/// Fired when the user submits a prompt to Syllabot.
final class SubmitPromptEvent extends SyllabotChatEvent {
  const SubmitPromptEvent({
    required this.prompt,
    required this.sessionId,
    required this.socraticMode,
    required this.engineType,
    this.contextHistory = const [],
  });

  final String prompt;
  final String sessionId;
  final SocraticMode socraticMode;
  final ExecutionEngineType engineType;
  final List<ChatMessageEntity> contextHistory;
}

/// A new streaming token arrived from the SSE stream.
final class StreamTokenReceivedEvent extends SyllabotChatEvent {
  const StreamTokenReceivedEvent(this.token);
  final String token;
}

/// Streaming response completed.
final class StreamCompletedEvent extends SyllabotChatEvent {
  const StreamCompletedEvent();
}

/// Streaming hit an error; should show retry.
final class StreamErrorEvent extends SyllabotChatEvent {
  const StreamErrorEvent(this.message);
  final String message;
}

/// User requested a retry of the last failed message.
final class RetryLastMessageEvent extends SyllabotChatEvent {
  const RetryLastMessageEvent();
}

/// User switched the Socratic mode.
final class ChangeSocraticModeEvent extends SyllabotChatEvent {
  const ChangeSocraticModeEvent(this.mode);
  final SocraticMode mode;
}

/// User switched the execution engine.
final class ChangeEngineTypeEvent extends SyllabotChatEvent {
  const ChangeEngineTypeEvent(this.engine);
  final ExecutionEngineType engine;
}

/// Load historical chat messages for a session.
final class LoadChatMessagesEvent extends SyllabotChatEvent {
  const LoadChatMessagesEvent(this.sessionId);
  final String sessionId;
}

/// Start a fresh new session.
final class StartNewSessionEvent extends SyllabotChatEvent {
  const StartNewSessionEvent();
}

/// User requested to clear all chat history.
final class ClearAllHistoryEvent extends SyllabotChatEvent {
  const ClearAllHistoryEvent();
}

/// Convert the current chat into a flashcard deck.
final class ConvertToDeckEvent extends SyllabotChatEvent {
  const ConvertToDeckEvent({
    required this.sessionId,
    required this.deckTitle,
    required this.courseCode,
  });

  final String sessionId;
  final String deckTitle;
  final String courseCode;
}
