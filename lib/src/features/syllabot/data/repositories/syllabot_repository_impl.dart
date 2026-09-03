import 'dart:async';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_local_data_source.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/data/models/conversation_session_model.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/conversation_session_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/syllabot_repository.dart';

class SyllabotRepositoryImpl implements SyllabotRepository {
  SyllabotRepositoryImpl({
    required SyllabotRemoteDataSource remoteDataSource,
    required SyllabotLocalDataSource localDataSource,
    DecksRemoteDataSource? decksRemoteDataSource,
  }) : _remote = remoteDataSource,
       _local = localDataSource,
       _decksRemoteDataSource = decksRemoteDataSource;

  final SyllabotRemoteDataSource _remote;
  final SyllabotLocalDataSource _local;
  final DecksRemoteDataSource? _decksRemoteDataSource;

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
        contextHistory: contextHistory,
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
    return Future<List<ConversationSessionEntity>>.sync(() async {
      try {
        final remoteModels = await _remote.getChatSessions();
        if (remoteModels.isNotEmpty) {
          final entities = remoteModels.map((m) => m.toEntity()).toList();
          for (final model in remoteModels) {
            await _local.saveSession(model);
          }
          return entities;
        }
      } on Object catch (_) {}

      // Fall back to persistent local storage sessions
      final localModels = await _local.getCachedSessions();
      return localModels.map((m) => m.toEntity()).toList();
    }).makeRequest();
  }

  @override
  Future<Either<Failure, ConversationSessionEntity>> createChatSession({
    required String title,
    required SocraticMode socraticMode,
    String? id,
    bool isOffline = false,
  }) {
    return Future<ConversationSessionEntity>.sync(() async {
      final sessionId = (id != null && id.isNotEmpty && UuidUtils.isValidUuid(id))
          ? id
          : UuidUtils.generate();
      ConversationSessionModel? createdModel;
      if (!isOffline) {
        try {
          createdModel = await _remote.createChatSession(
            title: title,
            socraticMode: socraticMode,
            id: sessionId,
          );
        } on Object catch (_) {}
      }

      createdModel ??= ConversationSessionModel(
        id: sessionId,
        userId: '',
        title: title,
        socraticMode: socraticMode.nameString,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _local.saveSession(createdModel);
      return createdModel.toEntity();
    }).makeRequest();
  }

  @override
  Future<void> cacheMessage(ChatMessageEntity message) async {
    await _local.cacheMessage(message);
  }

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getSessionMessages({
    required String sessionId,
  }) {
    return Future<List<ChatMessageEntity>>.sync(() async {
      try {
        final remote = await _remote.getSessionMessages(sessionId: sessionId);
        if (remote.isNotEmpty) {
          return remote.map((m) => m.toEntity()).toList();
        }
      } on Object catch (_) {}

      // Fall back to local cache
      final cached = await _local.getCachedMessages(sessionId: sessionId);
      return cached.map((m) => m.toEntity()).toList();
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> deleteChatSession({
    required String sessionId,
  }) {
    return Future<void>.sync(() async {
      try {
        await _remote.deleteSession(sessionId: sessionId);
      } on Object catch (_) {}
      await _local.deleteSession(sessionId);
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> clearAllChatSessions() {
    return Future<void>.sync(() async {
      try {
        final sessions = await _remote.getChatSessions();
        await Future.wait(
          sessions.map((s) => _remote.deleteSession(sessionId: s.id)),
        );
      } on Object catch (_) {}
      final localSessions = await _local.getCachedSessions();
      await Future.wait(
        localSessions.map((s) => _local.deleteSession(s.id)),
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
    return Future<DeckEntity>.sync(() async {
      final cards = <FlashcardEntity>[];
      final flashcardModels = <FlashcardModel>[];
      var cardIndex = 0;

      // Extract questions from user prompts and answers from Syllabot responses
      final userPrompts = messages
          .where((m) => m.sender == MessageSender.user)
          .map((m) => m.text.trim())
          .toList();

      final syllabotMessages = messages
          .where((m) => m.sender == MessageSender.syllabot)
          .toList();

      if (userPrompts.isNotEmpty && syllabotMessages.isNotEmpty) {
        for (var i = 0; i < syllabotMessages.length; i++) {
          final prompt = i < userPrompts.length ? userPrompts[i] : deckTitle;
          final response = syllabotMessages[i].text;

          // Add primary concept card
          final cardId = 'card_${sessionId}_${cardIndex++}';
          final cardEntity = FlashcardEntity(
            id: cardId,
            deckId: 'deck_$sessionId',
            front:
                prompt.startsWith('What') ||
                    prompt.startsWith('How') ||
                    prompt.startsWith('Prove')
                ? prompt
                : 'Explain $prompt',
            back: response.length > 300
                ? '${response.substring(0, 300)}...'
                : response,
            sourceTopic: deckTitle,
            nextDueDate: DateTime.now().add(const Duration(days: 1)),
          );
          cards.add(cardEntity);
          flashcardModels.add(FlashcardModel.fromEntity(cardEntity));

          // Also extract discrete sub-formulas or step bullets
          final lines = response.split('\n').where((l) => l.trim().isNotEmpty);
          for (final line in lines) {
            if (line.contains(r'$$') ||
                (line.startsWith('**Step') && line.contains(':'))) {
              if (cards.length >= 15) break;
              final cleanLine = line.replaceAll(RegExp(r'\*+'), '').trim();
              final subCardId = 'card_${sessionId}_${cardIndex++}';
              final subCard = FlashcardEntity(
                id: subCardId,
                deckId: 'deck_$sessionId',
                front: '$deckTitle: Concept Rule',
                back: cleanLine,
                sourceTopic: deckTitle,
                nextDueDate: DateTime.now().add(const Duration(days: 1)),
              );
              cards.add(subCard);
              flashcardModels.add(FlashcardModel.fromEntity(subCard));
            }
          }
        }
      }

      // If no cards were generated, generate a fallback comprehensive study card
      if (cards.isEmpty) {
        final cardId = 'card_${sessionId}_0';
        final cardEntity = FlashcardEntity(
          id: cardId,
          deckId: 'deck_$sessionId',
          front: deckTitle,
          back: messages.isNotEmpty
              ? messages.last.text
              : 'Study Notes for $deckTitle',
          sourceTopic: deckTitle,
          nextDueDate: DateTime.now().add(const Duration(days: 1)),
        );
        cards.add(cardEntity);
        flashcardModels.add(FlashcardModel.fromEntity(cardEntity));
      }

      final deckId = 'deck_$sessionId';
      final deckEntity = DeckEntity(
        id: deckId,
        title: deckTitle,
        subject: courseCode,
        totalCards: cards.length,
        dueCards: cards.where((c) => c.isDueToday).length,
        masteryRate: 0,
        category: 'AI Generated',
        description: 'Auto-generated from Syllabot study dialogue',
        cards: cards,
      );

      // Persist to local cache and Supabase database!
      if (_decksRemoteDataSource != null) {
        await _decksRemoteDataSource.saveGeneratedDeck(
          deck: DeckModel.fromEntity(deckEntity),
          cards: flashcardModels,
        );
      }

      return deckEntity;
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> purgeExpiredAiCache() {
    return _local.clearExpiredCache().makeRequest();
  }
}
