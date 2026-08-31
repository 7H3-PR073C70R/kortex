import 'package:kortex/src/features/syllabot/data/client/supabase_syllabot_client.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/data/models/chat_message_model.dart';
import 'package:kortex/src/features/syllabot/data/models/conversation_session_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/services/user_storage_service.dart';

class SyllabotRemoteDataSourceImpl implements SyllabotRemoteDataSource {
  SyllabotRemoteDataSourceImpl(this._client, this._userStorage);

  final SupabaseSyllabotClient _client;
  final UserStorageService _userStorage;

  @override
  Stream<String> streamResponse({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType engine,
    List<ChatMessageEntity> contextHistory = const [],
  }) {
    final token = _userStorage.getToken();
    final history = contextHistory
        .map((m) => {
              'sender': m.sender == MessageSender.user ? 'user' : 'syllabot',
              'text': m.text,
            })
        .toList();

    return _client.streamResponse(
      prompt: prompt,
      sessionId: sessionId,
      socraticMode: socraticMode,
      engine: engine,
      contextHistory: history,
      authToken: token,
    );
  }

  @override
  Future<List<ConversationSessionModel>> getChatSessions() async {
    final token = _userStorage.getToken() ?? '';
    final data = await _client.getChatSessions(token);
    return data.map(ConversationSessionModel.fromJson).toList();
  }

  @override
  Future<ConversationSessionModel> createChatSession({
    required String title,
    required SocraticMode socraticMode,
  }) async {
    final token = _userStorage.getToken() ?? '';
    final data = await _client.createChatSession(
      title: title,
      socraticMode: socraticMode.nameString,
      authToken: token,
    );
    return ConversationSessionModel.fromJson(data);
  }

  @override
  Future<List<ChatMessageModel>> getSessionMessages({
    required String sessionId,
  }) async {
    final token = _userStorage.getToken() ?? '';
    final data = await _client.getSessionMessages(
      sessionId: sessionId,
      authToken: token,
    );
    return data.map(ChatMessageModel.fromJson).toList();
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    final token = _userStorage.getToken() ?? '';
    await _client.deleteSession(sessionId: sessionId, authToken: token);
  }
}
