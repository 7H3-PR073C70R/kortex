import 'dart:async';
import 'package:kortex/src/core/error/failure.dart';
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

    // Cloud engine with transparent local fallback on error
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
          onError: (_) {
            // Graceful fallback to on-device LLM
            _local
                .generateOfflineResponse(
                  prompt: prompt,
                  socraticMode: socraticMode,
                )
                .listen(
                  controller.add,
                  onDone: controller.close,
                  onError: controller.addError,
                );
          },
          onDone: controller.close,
        );

    return controller.stream;
  }

  @override
  Future<Either<Failure, List<ConversationSessionEntity>>>
      getChatSessions() async {
    try {
      final models = await _remote.getChatSessions();
      return Right(models.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConversationSessionEntity>> createChatSession({
    required String title,
    required SocraticMode socraticMode,
  }) async {
    try {
      final model = await _remote.createChatSession(
        title: title,
        socraticMode: socraticMode,
      );
      return Right(model.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getSessionMessages({
    required String sessionId,
  }) async {
    try {
      final remote = await _remote.getSessionMessages(sessionId: sessionId);
      if (remote.isNotEmpty) {
        return Right(remote.map((m) => m.toEntity()).toList());
      }
      // Fall back to local cache
      final cached = await _local.getCachedMessages(sessionId: sessionId);
      return Right(cached.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteChatSession({
    required String sessionId,
  }) async {
    try {
      await _remote.deleteSession(sessionId: sessionId);
      return const Right(null);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearAllChatSessions() async {
    try {
      final sessions = await _remote.getChatSessions();
      await Future.wait(
        sessions.map((s) => _remote.deleteSession(sessionId: s.id)),
      );
      return const Right(null);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DeckEntity>> generateDeckFromChat({
    required String sessionId,
    required String deckTitle,
    required String courseCode,
    List<ChatMessageEntity> messages = const [],
  }) async {
    try {
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
      final deck = DeckEntity(
        id: 'gen_$prefix',
        title: deckTitle,
        subject: courseCode,
        totalCards: cards.length,
        dueCards: cards.length,
        masteryRate: 0,
        category: 'AI Generated',
        description: 'Auto-generated from Syllabot conversation',
        cards: cards,
      );

      return Right(deck);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> purgeExpiredAiCache() async {
    try {
      await _local.clearExpiredCache();
      return const Right(null);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
