import 'package:kortex/src/features/syllabot/data/models/chat_message_model.dart';
import 'package:kortex/src/features/syllabot/data/models/conversation_session_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

abstract class SyllabotRemoteDataSource {
  Stream<String> streamResponse({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType engine,
    List<ChatMessageEntity> contextHistory = const [],
  });

  Future<List<ConversationSessionModel>> getChatSessions();

  Future<ConversationSessionModel> createChatSession({
    required String title,
    required SocraticMode socraticMode,
  });

  Future<List<ChatMessageModel>> getSessionMessages({
    required String sessionId,
  });

  Future<void> deleteSession({required String sessionId});
}
