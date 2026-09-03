import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/conversation_session_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

/// Contract defining all Syllabot AI operations, streaming, and generation.
abstract class SyllabotRepository {
  /// Streams tokens in real-time using remote Supabase SSE or local engine.
  Stream<String> streamResponse({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType preferredEngine,
    List<ChatMessageEntity> contextHistory = const [],
  });

  /// Retrieves all chat sessions for the authenticated user.
  Future<Either<Failure, List<ConversationSessionEntity>>> getChatSessions();

  /// Creates or retrieves a chat session.
  Future<Either<Failure, ConversationSessionEntity>> createChatSession({
    required String title,
    required SocraticMode socraticMode,
    String? id,
    bool isOffline = false,
  });

  /// Persists a message to the local offline cache.
  Future<void> cacheMessage(ChatMessageEntity message);

  /// Retrieves the message history for a specific session.
  Future<Either<Failure, List<ChatMessageEntity>>> getSessionMessages({
    required String sessionId,
  });

  /// Deletes a specific chat session.
  Future<Either<Failure, void>> deleteChatSession({
    required String sessionId,
  });

  /// Clears all chat sessions for the user.
  Future<Either<Failure, void>> clearAllChatSessions();

  /// Extracts key concepts from conversation into a Spaced Repetition Deck.
  Future<Either<Failure, DeckEntity>> generateDeckFromChat({
    required String sessionId,
    required String deckTitle,
    required String courseCode,
    List<ChatMessageEntity> messages = const [],
  });

  /// Purges expired local on-device message caches.
  Future<Either<Failure, void>> purgeExpiredAiCache();
}
