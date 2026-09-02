import 'package:kortex/src/features/syllabot/data/models/chat_message_model.dart';
import 'package:kortex/src/features/syllabot/data/models/conversation_session_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

/// Interface for on-device / local data source (offline LLM and local cache).
abstract class SyllabotLocalDataSource {
  /// Returns a streaming response from the on-device LLM engine.
  Stream<String> generateOfflineResponse({
    required String prompt,
    required SocraticMode socraticMode,
  });

  /// Retrieves cached sessions from local storage for offline viewing.
  Future<List<ConversationSessionModel>> getCachedSessions();

  /// Persists a session to local storage.
  Future<void> saveSession(ConversationSessionModel session);

  /// Deletes a cached session from local storage.
  Future<void> deleteSession(String sessionId);

  /// Retrieves cached messages from local storage for offline viewing.
  Future<List<ChatMessageModel>> getCachedMessages({required String sessionId});

  /// Persists a message to the local message cache.
  Future<void> cacheMessage(ChatMessageEntity message);

  /// Clears expired cache entries older than [maxAgeInDays] days.
  Future<void> clearExpiredCache({int maxAgeInDays = 30});
}
