import 'package:dio/dio.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/syllabot/data/client/syllabot_api_client.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/data/models/chat_message_model.dart';
import 'package:kortex/src/features/syllabot/data/models/conversation_session_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

class SyllabotRemoteDataSourceImpl implements SyllabotRemoteDataSource {
  SyllabotRemoteDataSourceImpl(
    this._client,
    this._dio, {
    UserStorageService? userStorage,
  }) : _userStorage = userStorage;

  final SyllabotApiClient _client;
  final Dio _dio;
  final UserStorageService? _userStorage;

  @override
  Stream<String> streamResponse({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType engine,
    List<ChatMessageEntity> contextHistory = const [],
  }) {
    final history = contextHistory
        .map(
          (m) => {
            'sender': m.sender == MessageSender.user ? 'user' : 'syllabot',
            'text': m.text,
          },
        )
        .toList();

    return _dio.streamSyllabotResponse(
      prompt: prompt,
      sessionId: sessionId,
      socraticMode: socraticMode,
      engine: engine,
      contextHistory: history,
    );
  }

  @override
  Future<List<ConversationSessionModel>> getChatSessions() async {
    final res = await _client.getChatSessions(
      {'select': '*', 'order': 'updated_at.desc'},
    );
    final list = res.data is List ? (res.data as List) : <dynamic>[];
    return list
        .map(
          (e) => ConversationSessionModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<ConversationSessionModel> createChatSession({
    required String title,
    required SocraticMode socraticMode,
    String? id,
  }) async {
    final userId = _userStorage?.getUserId() ?? '';
    final payload = <String, dynamic>{
      if (id != null && id.isNotEmpty && UuidUtils.isValidUuid(id)) 'id': id,
      'title': title,
      'socratic_mode': socraticMode.nameString,
      if (userId.isNotEmpty) 'user_id': userId,
    };
    final res = await _client.createChatSession(payload);
    final list = res.data is List ? (res.data as List) : <dynamic>[];
    if (list.isEmpty) throw Exception('No session returned');
    return ConversationSessionModel.fromJson(
      list.first as Map<String, dynamic>,
    );
  }

  @override
  Future<List<ChatMessageModel>> getSessionMessages({
    required String sessionId,
  }) async {
    final res = await _client.getSessionMessages(
      {
        'select': '*',
        'session_id': 'eq.$sessionId',
        'order': 'created_at.asc',
      },
    );
    final list = res.data is List ? (res.data as List) : <dynamic>[];
    return list
        .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    await _client.deleteSession(
      {'id': 'eq.$sessionId'},
    );
  }
}
