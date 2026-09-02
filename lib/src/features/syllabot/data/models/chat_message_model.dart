import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.latexSnippets = const [],
    this.engineType = 'cloudRemote',
    this.tokensCount = 0,
  });

  final String id;
  final String sessionId;
  final String userId;
  final String sender;
  final String text;
  final DateTime createdAt;
  final List<String> latexSnippets;
  final String engineType;
  final int tokensCount;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      sender: json['sender'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      latexSnippets: (json['latex_snippets'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      engineType: json['engine_type'] as String? ?? 'cloudRemote',
      tokensCount: json['tokens_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'sender': sender,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'latex_snippets': latexSnippets,
      'engine_type': engineType,
      'tokens_count': tokensCount,
    };
  }

  ChatMessageEntity toEntity() {
    return ChatMessageEntity(
      id: id,
      sessionId: sessionId,
      sender: sender == 'user' ? MessageSender.user : MessageSender.syllabot,
      text: text,
      timestamp: createdAt,
      latexSnippets: latexSnippets,
      engineType: ExecutionEngineTypeX.fromString(engineType),
      tokensCount: tokensCount,
    );
  }

  static ChatMessageModel fromEntity(ChatMessageEntity entity) {
    return ChatMessageModel(
      id: entity.id,
      sessionId: entity.sessionId,
      userId: '',
      sender: entity.sender == MessageSender.user ? 'user' : 'syllabot',
      text: entity.text,
      createdAt: entity.timestamp,
      latexSnippets: entity.latexSnippets,
      engineType: entity.engineType.nameString,
      tokensCount: entity.tokensCount,
    );
  }
}
