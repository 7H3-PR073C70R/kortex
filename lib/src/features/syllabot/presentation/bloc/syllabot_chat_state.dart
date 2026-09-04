import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

enum SyllabotStatus {
  idle,
  loading,
  streaming,
  error,
  generatingDeck,
  deckGenerated,
}

class SyllabotChatState extends Equatable {
  const SyllabotChatState({
    this.status = SyllabotStatus.idle,
    this.messages = const [],
    this.sessionId = '',
    this.streamingText = '',
    this.socraticMode = SocraticMode.stepByStep,
    this.engineType = ExecutionEngineType.cloudRemote,
    this.errorMessage,
    this.generatedDeck,
    this.isConvertedToDeck = false,
    this.lastPrompt,
    this.lastEngine,
    this.lastSocraticMode,
  });

  final SyllabotStatus status;
  final List<ChatMessageEntity> messages;
  final String sessionId;
  final String streamingText;
  final SocraticMode socraticMode;
  final ExecutionEngineType engineType;
  final String? errorMessage;
  final DeckEntity? generatedDeck;
  final bool isConvertedToDeck;

  // Retry support
  final String? lastPrompt;
  final ExecutionEngineType? lastEngine;
  final SocraticMode? lastSocraticMode;

  bool get isStreaming => status == SyllabotStatus.streaming;
  bool get hasError => status == SyllabotStatus.error;
  bool get isGeneratingDeck => status == SyllabotStatus.generatingDeck;

  SyllabotChatState copyWith({
    SyllabotStatus? status,
    List<ChatMessageEntity>? messages,
    String? sessionId,
    String? streamingText,
    SocraticMode? socraticMode,
    ExecutionEngineType? engineType,
    String? errorMessage,
    DeckEntity? generatedDeck,
    bool? isConvertedToDeck,
    String? lastPrompt,
    ExecutionEngineType? lastEngine,
    SocraticMode? lastSocraticMode,
  }) {
    return SyllabotChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sessionId: sessionId ?? this.sessionId,
      streamingText: streamingText ?? this.streamingText,
      socraticMode: socraticMode ?? this.socraticMode,
      engineType: engineType ?? this.engineType,
      errorMessage: errorMessage ?? this.errorMessage,
      generatedDeck: generatedDeck ?? this.generatedDeck,
      isConvertedToDeck: isConvertedToDeck ?? this.isConvertedToDeck,
      lastPrompt: lastPrompt ?? this.lastPrompt,
      lastEngine: lastEngine ?? this.lastEngine,
      lastSocraticMode: lastSocraticMode ?? this.lastSocraticMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    sessionId,
    streamingText,
    socraticMode,
    engineType,
    errorMessage,
    generatedDeck,
    isConvertedToDeck,
    lastPrompt,
    lastEngine,
    lastSocraticMode,
  ];
}
