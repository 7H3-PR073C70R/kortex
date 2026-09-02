import 'dart:async';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_local_data_source.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/conversation_session_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/syllabot_repository.dart';

class SyllabotRepositoryImpl implements SyllabotRepository {
  SyllabotRepositoryImpl({
    required SyllabotRemoteDataSource remoteDataSource,
    required SyllabotLocalDataSource localDataSource,
  })  : _remote = remoteDataSource,
        _local = localDataSource;

  final SyllabotRemoteDataSource _remote;
  final SyllabotLocalDataSource _local;

  @override
  Stream<String> streamResponse({
    required String prompt,
    required String sessionId,
    required SocraticMode socraticMode,
    required ExecutionEngineType preferredEngine,
    List<ChatMessageEntity> contextHistory = const [],
  }) {
    if (preferredEngine == ExecutionEngineType.localOnDevice) {
      return _local.generateOfflineResponse(
        prompt: prompt,
        socraticMode: socraticMode,
      );
    }

    // Cloud engine with transparent stream error propagation
    final controller = StreamController<String>();

    _remote
        .streamResponse(
          prompt: prompt,
          sessionId: sessionId,
          socraticMode: socraticMode,
          engine: preferredEngine,
          contextHistory: contextHistory,
        )
        .listen(
          controller.add,
          onError: (Object err) {
            if (!controller.isClosed) {
              controller.addError(
                'Unable to reach Cloud Neural Engine. '
                'Check internet or switch to Offline LLM.',
              );
            }
          },
          onDone: () => unawaited(controller.close()),
          cancelOnError: true,
        );

    return controller.stream;
  }

  @override
  Future<Either<Failure, List<ConversationSessionEntity>>> getChatSessions() {
    return _remote
        .getChatSessions()
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, ConversationSessionEntity>> createChatSession({
    required String title,
    required SocraticMode socraticMode,
  }) {
    return _remote
        .createChatSession(
          title: title,
          socraticMode: socraticMode,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getSessionMessages({
    required String sessionId,
  }) {
    return Future<List<ChatMessageEntity>>.sync(() async {
      final remote = await _remote.getSessionMessages(sessionId: sessionId);
      if (remote.isNotEmpty) {
        return remote.map((m) => m.toEntity()).toList();
      }
      // Fall back to local cache
      final cached = await _local.getCachedMessages(sessionId: sessionId);
      return cached.map((m) => m.toEntity()).toList();
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> deleteChatSession({
    required String sessionId,
  }) {
    return _remote.deleteSession(sessionId: sessionId).makeRequest();
  }

  @override
  Future<Either<Failure, void>> clearAllChatSessions() {
    return Future<void>.sync(() async {
      final sessions = await _remote.getChatSessions();
      await Future.wait(
        sessions.map((s) => _remote.deleteSession(sessionId: s.id)),
      );
    }).makeRequest();
  }

  @override
  Future<Either<Failure, DeckEntity>> generateDeckFromChat({
    required String sessionId,
    required String deckTitle,
    required String courseCode,
    List<ChatMessageEntity> messages = const [],
  }) {
    return Future<DeckEntity>.sync(() {
      // Extract key formulas and concept lines from Syllabot responses
      final syllabotMessages = messages
          .where((m) => m.sender == MessageSender.syllabot)
          .toList();

      final cards = <FlashcardEntity>[];
      var cardIndex = 0;

      for (final msg in syllabotMessages) {
        final lines = msg.text.split('\n').where((l) => l.trim().isNotEmpty);
        for (final line in lines) {
          if (line.contains(r'$$') ||
              line.startsWith('**') ||
              line.contains(':')) {
            if (cardIndex >= 20) break; // Cap at 20 cards
            cards.add(
              FlashcardEntity(
                id: 'gen_${sessionId}_$cardIndex',
                deckId: 'gen_$sessionId',
                front: 'Key Concept ${cardIndex + 1}',
                back: line.replaceAll(RegExp(r'\*+'), '').trim(),
                nextDueDate: DateTime.now().add(const Duration(days: 1)),
              ),
            );
            cardIndex++;
          }
        }
      }

      final prefix =
          sessionId.substring(0, sessionId.length > 8 ? 8 : sessionId.length);
      return DeckEntity(
        id: 'gen_$prefix',
        title: deckTitle,
        subject: courseCode,
        totalCards: cards.length,
        dueCards: cards.where((c) => c.isDueToday).length,
        masteryRate: 0,
        category: 'AI Generated',
        description: 'Auto-generated from Syllabot conversation',
        cards: cards,
      );
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> purgeExpiredAiCache() {
    return _local.clearExpiredCache().makeRequest();
  }
}
