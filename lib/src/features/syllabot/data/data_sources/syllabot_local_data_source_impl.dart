import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_local_data_source.dart';
import 'package:kortex/src/features/syllabot/data/models/chat_message_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

class SyllabotLocalDataSourceImpl implements SyllabotLocalDataSource {
  SyllabotLocalDataSourceImpl(this._llmClient);

  final LocalLlmEngineClient _llmClient;

  // In-memory cache keyed by sessionId for session lifetime.
  final Map<String, List<ChatMessageModel>> _cache = {};

  @override
  Stream<String> generateOfflineResponse({
    required String prompt,
    required SocraticMode socraticMode,
  }) {
    const systemMap = {
      SocraticMode.stepByStep:
          'Walk through this problem step-by-step with clarity.',
      SocraticMode.directAnswer: 'Provide a direct and comprehensive answer.',
      SocraticMode.examSim:
          'Simulate an exam scenario with marks breakdown.',
      SocraticMode.deepResearch:
          'Provide a deep theoretical research overview.',
    };

    return _llmClient.generate(
      prompt: prompt,
      systemInstruction: systemMap[socraticMode] ?? '',
    );
  }

  @override
  Future<List<ChatMessageModel>> getCachedMessages({
    required String sessionId,
  }) async {
    return _cache[sessionId] ?? [];
  }

  @override
  Future<void> cacheMessage(ChatMessageEntity message) async {
    final model = ChatMessageModel.fromEntity(message);
    _cache.putIfAbsent(message.sessionId, () => []).add(model);
  }

  @override
  Future<void> clearExpiredCache({int maxAgeInDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeInDays));
    for (final key in List.of(_cache.keys)) {
      _cache[key]?.removeWhere((m) => m.createdAt.isBefore(cutoff));
      if (_cache[key]?.isEmpty ?? false) {
        _cache.remove(key);
      }
    }
  }
}
