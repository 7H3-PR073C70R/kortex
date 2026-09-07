import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:kortex/src/core/database/app_database.dart';
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
    AppDatabase? database,
    LocalStorageService? storageService,
  })  : _database = database,
        _storage = storageService;

  final LocalLlmEngineClient _llmClient;
  final AppDatabase? _database;
  final LocalStorageService? _storage;

  static const String _sessionsKey = '__syllabot_local_sessions';
  static const String _messageKeyPrefix = '__syllabot_local_msgs_';

  // In-memory cache fallback keyed by sessionId
  final Map<String, List<ChatMessageModel>> _messageCache = {};
  final List<ConversationSessionModel> _sessionCache = [];
  bool _sessionsMigrated = false;

  @override
  Stream<String> generateOfflineResponse({
    required String prompt,
    required SocraticMode socraticMode,
    List<ChatMessageEntity> contextHistory = const [],
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
      contextHistory: contextHistory,
    );
  }

  @override
  Future<List<ConversationSessionModel>> getCachedSessions() async {
    final db = _database;
    if (db != null) {
      try {
        final entries = await db.getAllSyllabotSessions();
        if (entries.isNotEmpty) {
          return entries
              .map(
                (e) => ConversationSessionModel(
                  id: e.id,
                  userId: e.userId,
                  title: e.title,
                  socraticMode: e.socraticMode,
                  createdAt: e.createdAt,
                  updatedAt: e.updatedAt,
                ),
              )
              .toList();
        }

        // Check if migration from SharedPreferences is needed
        if (!_sessionsMigrated && _storage != null) {
          _sessionsMigrated = true;
          final raw = _storage.getPreference(key: _sessionsKey);
          if (raw != null && raw.isNotEmpty) {
            final list = jsonDecode(raw) as List<dynamic>;
            final legacy = list
                .map(
                  (e) => ConversationSessionModel.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList();

            for (final s in legacy) {
              await db.upsertSyllabotSession(
                SyllabotSessionsCompanion(
                  id: Value(s.id),
                  userId: Value(s.userId),
                  title: Value(s.title),
                  socraticMode: Value(s.socraticMode),
                  createdAt: Value(s.createdAt),
                  updatedAt: Value(s.updatedAt),
                ),
              );
            }
            await _storage.deletePreference(key: _sessionsKey);
            return legacy;
          }
        }
      } on Object catch (_) {}
    }

    try {
      if (_storage != null) {
        final raw = _storage.getPreference(key: _sessionsKey);
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          return list
              .map(
                (e) => ConversationSessionModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList();
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

    final db = _database;
    if (db != null) {
      try {
        await db.upsertSyllabotSession(
          SyllabotSessionsCompanion(
            id: Value(session.id),
            userId: Value(session.userId),
            title: Value(session.title),
            socraticMode: Value(session.socraticMode),
            createdAt: Value(session.createdAt),
            updatedAt: Value(session.updatedAt),
          ),
        );
        return;
      } on Object catch (_) {}
    }

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

    final db = _database;
    if (db != null) {
      try {
        await db.deleteSyllabotSessionById(sessionId);
        await db.deleteSyllabotMessagesForSession(sessionId);
      } on Object catch (_) {}
    }

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
    final db = _database;
    if (db != null) {
      try {
        final entries = await db.getSyllabotMessagesForSession(sessionId);
        if (entries.isNotEmpty) {
          return entries.map((e) {
            var latex = const <String>[];
            if (e.latexSnippets != null && e.latexSnippets!.isNotEmpty) {
              try {
                latex = (jsonDecode(e.latexSnippets!) as List<dynamic>)
                    .map((x) => x.toString())
                    .toList();
              } catch (_) {}
            }
            return ChatMessageModel(
              id: e.id,
              sessionId: e.sessionId,
              userId: e.userId,
              sender: e.sender,
              text: e.textContent,
              createdAt: e.createdAt,
              latexSnippets: latex,
              engineType: e.engineType,
              tokensCount: e.tokensCount,
            );
          }).toList();
        }

        // Migrate from storage if available
        if (_storage != null) {
          final raw = _storage.getPreference(key: '$_messageKeyPrefix$sessionId');
          if (raw != null && raw.isNotEmpty) {
            final list = jsonDecode(raw) as List<dynamic>;
            final parsed = list
                .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
                .toList();

            for (final m in parsed) {
              await db.upsertSyllabotMessage(
                SyllabotMessagesCompanion(
                  id: Value(m.id),
                  sessionId: Value(m.sessionId),
                  userId: Value(m.userId),
                  sender: Value(m.sender),
                  textContent: Value(m.text),
                  latexSnippets: Value(
                    m.latexSnippets.isNotEmpty ? jsonEncode(m.latexSnippets) : null,
                  ),
                  engineType: Value(m.engineType),
                  tokensCount: Value(m.tokensCount),
                  createdAt: Value(m.createdAt),
                ),
              );
            }
            await _storage.deletePreference(key: '$_messageKeyPrefix$sessionId');
            return parsed;
          }
        }
      } on Object catch (_) {}
    }

    try {
      if (_storage != null) {
        final raw = _storage.getPreference(key: '$_messageKeyPrefix$sessionId');
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          return list
              .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } on Object catch (_) {}

    return _messageCache[sessionId] ?? [];
  }

  @override
  Future<void> cacheMessage(ChatMessageEntity message) async {
    final model = ChatMessageModel.fromEntity(message);
    _messageCache.putIfAbsent(message.sessionId, () => []).add(model);

    final db = _database;
    if (db != null) {
      try {
        await db.upsertSyllabotMessage(
          SyllabotMessagesCompanion(
            id: Value(model.id),
            sessionId: Value(model.sessionId),
            userId: Value(model.userId),
            sender: Value(model.sender),
            textContent: Value(model.text),
            latexSnippets: Value(
              model.latexSnippets.isNotEmpty
                  ? jsonEncode(model.latexSnippets)
                  : null,
            ),
            engineType: Value(model.engineType),
            tokensCount: Value(model.tokensCount),
            createdAt: Value(model.createdAt),
          ),
        );
        return;
      } on Object catch (_) {}
    }

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
    final db = _database;
    if (db != null) {
      try {
        await db.deleteExpiredSyllabotMessages(cutoff);
      } on Object catch (_) {}
    }

    for (final key in List.of(_messageCache.keys)) {
      _messageCache[key]?.removeWhere((m) => m.createdAt.isBefore(cutoff));
      if (_messageCache[key]?.isEmpty ?? false) {
        _messageCache.remove(key);
      }
    }
  }
}

