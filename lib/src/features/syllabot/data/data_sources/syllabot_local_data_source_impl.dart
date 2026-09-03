import 'dart:convert';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_local_data_source.dart';
import 'package:kortex/src/features/syllabot/data/models/chat_message_model.dart';
import 'package:kortex/src/features/syllabot/data/models/conversation_session_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

class SyllabotLocalDataSourceImpl implements SyllabotLocalDataSource {
  SyllabotLocalDataSourceImpl(
    this._llmClient, {
    LocalStorageService? storageService,
  }) : _storage = storageService;

  final LocalLlmEngineClient _llmClient;
  final LocalStorageService? _storage;

  static const String _sessionsKey = '__syllabot_local_sessions';
  static const String _messageKeyPrefix = '__syllabot_local_msgs_';

  // In-memory cache fallback keyed by sessionId
  final Map<String, List<ChatMessageModel>> _messageCache = {};
  final List<ConversationSessionModel> _sessionCache = [];

  @override
  Stream<String> generateOfflineResponse({
    required String prompt,
    required SocraticMode socraticMode,
  }) {
    const systemMap = {
      SocraticMode.stepByStep:
          'Walk through this problem step-by-step with clarity.',
      SocraticMode.directAnswer: 'Provide a direct and comprehensive answer.',
      SocraticMode.examSim: 'Simulate an exam scenario with marks breakdown.',
      SocraticMode.deepResearch:
          'Provide a deep theoretical research overview.',
    };

    return _llmClient.generate(
      prompt: prompt,
      systemInstruction: systemMap[socraticMode] ?? '',
      socraticMode: socraticMode,
    );
  }

  @override
  Future<List<ConversationSessionModel>> getCachedSessions() async {
    try {
      if (_storage != null) {
        final raw = _storage.getPreference(key: _sessionsKey);
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          final parsed = list
              .map(
                (e) => ConversationSessionModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList();
          return parsed;
        }
      }
    } on Object catch (_) {}

    return _sessionCache;
  }

  @override
  Future<void> saveSession(ConversationSessionModel session) async {
    _sessionCache
      ..removeWhere((s) => s.id == session.id)
      ..insert(0, session);

    try {
      if (_storage != null) {
        final existing = await getCachedSessions();
        final updated = [
          session,
          ...existing.where((s) => s.id != session.id),
        ];
        final jsonStr = jsonEncode(updated.map((s) => s.toJson()).toList());
        await _storage.savePreference(key: _sessionsKey, data: jsonStr);
      }
    } on Object catch (_) {}
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessionCache.removeWhere((s) => s.id == sessionId);
    _messageCache.remove(sessionId);

    try {
      if (_storage != null) {
        final existing = await getCachedSessions();
        final updated = existing.where((s) => s.id != sessionId).toList();
        final jsonStr = jsonEncode(updated.map((s) => s.toJson()).toList());
        await _storage.savePreference(key: _sessionsKey, data: jsonStr);
        await _storage.deletePreference(key: '$_messageKeyPrefix$sessionId');
      }
    } on Object catch (_) {}
  }

  @override
  Future<List<ChatMessageModel>> getCachedMessages({
    required String sessionId,
  }) async {
    try {
      if (_storage != null) {
        final raw = _storage.getPreference(key: '$_messageKeyPrefix$sessionId');
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          final parsed = list
              .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList();
          return parsed;
        }
      }
    } on Object catch (_) {}

    return _messageCache[sessionId] ?? [];
  }

  @override
  Future<void> cacheMessage(ChatMessageEntity message) async {
    final model = ChatMessageModel.fromEntity(message);
    _messageCache.putIfAbsent(message.sessionId, () => []).add(model);

    try {
      if (_storage != null) {
        final existing = await getCachedMessages(sessionId: message.sessionId);
        final updated = [...existing, model];
        final jsonStr = jsonEncode(updated.map((m) => m.toJson()).toList());
        await _storage.savePreference(
          key: '$_messageKeyPrefix${message.sessionId}',
          data: jsonStr,
        );
      }
    } on Object catch (_) {}
  }

  @override
  Future<void> clearExpiredCache({int maxAgeInDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeInDays));
    for (final key in List.of(_messageCache.keys)) {
      _messageCache[key]?.removeWhere((m) => m.createdAt.isBefore(cutoff));
      if (_messageCache[key]?.isEmpty ?? false) {
        _messageCache.remove(key);
      }
    }
  }
}
