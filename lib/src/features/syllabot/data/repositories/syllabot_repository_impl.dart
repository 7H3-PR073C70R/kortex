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
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
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
    StudyEngineRouter? studyEngineRouter,
  }) : _remote = remoteDataSource,
       _local = localDataSource,
       _decksRemoteDataSource = decksRemoteDataSource,
       _studyEngineRouter = studyEngineRouter;

  final SyllabotRemoteDataSource _remote;
  final SyllabotLocalDataSource _local;
  final DecksRemoteDataSource? _decksRemoteDataSource;
  final StudyEngineRouter? _studyEngineRouter;

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

      // 1. Build cohesive dialogue transcript incorporating whole-chat context
      final transcriptBuffer = StringBuffer();
      final userPrompts = <String>[];
      for (final msg in messages) {
        final role = msg.sender == MessageSender.user ? 'User' : 'Assistant';
        final text = msg.text.trim();
        if (text.isNotEmpty) {
          if (msg.sender == MessageSender.user) {
            userPrompts.add(text);
          }
          transcriptBuffer.writeln('$role: $text\n');
        }
      }
      final fullTranscript = transcriptBuffer.toString().trim();

      // 2. AI Synthesis: Route whole-chat context through StudyEngineRouter (Cloud or Local GGUF)
      if (fullTranscript.isNotEmpty) {
        try {
          final router = _studyEngineRouter ?? StudyEngineRouter();
          final studyPack = await router.generateStudyPack(
            topic: deckTitle,
            count: 10,
            sourceText: fullTranscript,
          );

          if (studyPack.cards.isNotEmpty) {
            for (final genCard in studyPack.cards) {
              final frontText = genCard.front.trim();
              final backText = genCard.back.trim();
              if (frontText.isNotEmpty && backText.isNotEmpty && !frontText.contains('Concept Rule')) {
                final cardId = 'card_${sessionId}_${cardIndex++}';
                final cardEntity = FlashcardEntity(
                  id: cardId,
                  deckId: 'deck_$sessionId',
                  front: frontText.endsWith('?') ? frontText : '$frontText?',
                  back: genCard.explanation.isNotEmpty
                      ? '$backText\n\n${genCard.explanation}'
                      : backText,
                  sourceTopic: deckTitle,
                  nextDueDate: DateTime.now().add(const Duration(days: 1)),
                );
                cards.add(cardEntity);
                flashcardModels.add(FlashcardModel.fromEntity(cardEntity));
              }
            }
          }
        } on Object catch (_) {
          // If network / offline isolate fails, continue to deep academic heuristic parsing
        }
      }

      // 3. Deep Academic Extraction: Parse whole transcript into structured concept questions
      if (cards.isEmpty && messages.isNotEmpty) {
        final syllabotMessages = messages
            .where((m) => m.sender == MessageSender.syllabot)
            .map((m) => m.text.trim())
            .toList();

        // 3a. Primary User Topic Question
        if (userPrompts.isNotEmpty && syllabotMessages.isNotEmpty) {
          final mainPrompt = userPrompts.first;
          final mainResponse = syllabotMessages.first;

          String mainQuestion;
          if (mainPrompt.toLowerCase().startsWith('what') ||
              mainPrompt.toLowerCase().startsWith('how') ||
              mainPrompt.toLowerCase().startsWith('why') ||
              mainPrompt.toLowerCase().startsWith('prove')) {
            mainQuestion = mainPrompt.endsWith('?') ? mainPrompt : '$mainPrompt?';
          } else {
            mainQuestion = 'How do you explain and apply $mainPrompt?';
          }

          final mainCardId = 'card_${sessionId}_${cardIndex++}';
          final mainCard = FlashcardEntity(
            id: mainCardId,
            deckId: 'deck_$sessionId',
            front: mainQuestion,
            back: mainResponse.length > 350
                ? '${mainResponse.substring(0, 350)}...'
                : mainResponse,
            sourceTopic: deckTitle,
            nextDueDate: DateTime.now().add(const Duration(days: 1)),
          );
          cards.add(mainCard);
          flashcardModels.add(FlashcardModel.fromEntity(mainCard));
        }

        // 3b. Deep Section & Formula Extraction from Assistant Responses
        for (final resp in syllabotMessages) {
          // Section header detection (e.g. "Theorem Statement", "Proof Steps", "Historical Context")
          final sectionRegex = RegExp(
            r'^(?:#{1,3}\s+|\*\*)?([A-Z][a-zA-Z0-9\s]{2,40})(?:\*\*)?:?\s*$',
            multiLine: true,
          );
          final matches = sectionRegex.allMatches(resp).toList();

          for (var i = 0; i < matches.length; i++) {
            if (cards.length >= 12) break;
            final sectionTitle = matches[i].group(1)!.trim();
            final startPos = matches[i].end;
            final endPos = (i + 1 < matches.length) ? matches[i + 1].start : resp.length;
            final sectionContent = resp.substring(startPos, endPos).trim();

            if (sectionContent.length < 25) continue;

            String question;
            final lowerTitle = sectionTitle.toLowerCase();
            if (lowerTitle.contains('theorem') || lowerTitle.contains('statement')) {
              question = 'What is the formal theorem statement for $deckTitle?';
            } else if (lowerTitle.contains('proof') || lowerTitle.contains('step') || lowerTitle.contains('derivation')) {
              question = 'What are the essential steps to prove or derive $deckTitle?';
            } else if (lowerTitle.contains('history') || lowerTitle.contains('context') || lowerTitle.contains('background')) {
              question = 'What is the historical context and significance of $deckTitle?';
            } else if (lowerTitle.contains('formula') || lowerTitle.contains('mathematical') || lowerTitle.contains('equation')) {
              question = 'What is the mathematical formulation of $deckTitle?';
            } else if (lowerTitle.contains('condition') || lowerTitle.contains('rule') || lowerTitle.contains('property')) {
              question = 'What are the key conditions and properties associated with $sectionTitle?';
            } else {
              question = 'Regarding $deckTitle, how is $sectionTitle explained?';
            }

            final cardId = 'card_${sessionId}_${cardIndex++}';
            final card = FlashcardEntity(
              id: cardId,
              deckId: 'deck_$sessionId',
              front: question,
              back: sectionContent.length > 400
                  ? '${sectionContent.substring(0, 400)}...'
                  : sectionContent,
              sourceTopic: deckTitle,
              nextDueDate: DateTime.now().add(const Duration(days: 1)),
            );
            cards.add(card);
            flashcardModels.add(FlashcardModel.fromEntity(card));
          }

          // Mathematical formula block extraction
          final formulaRegex = RegExp(r'(\$\$.*?\$\$|\\\[.*?\\\])', dotAll: true);
          final formulaMatches = formulaRegex.allMatches(resp);
          for (final fMatch in formulaMatches) {
            if (cards.length >= 12) break;
            final formula = fMatch.group(1)!.trim();
            final cardId = 'card_${sessionId}_${cardIndex++}';
            final card = FlashcardEntity(
              id: cardId,
              deckId: 'deck_$sessionId',
              front: 'What is the governing equation and formula for $deckTitle?',
              back: formula,
              backLatex: formula.replaceAll(RegExp(r'^\$\$|\$\$$|^\\\[|\\\]$'), '').trim(),
              sourceTopic: deckTitle,
              nextDueDate: DateTime.now().add(const Duration(days: 1)),
            );
            cards.add(card);
            flashcardModels.add(FlashcardModel.fromEntity(card));
          }
        }
      }

      // 4. Fallback if still empty
      if (cards.isEmpty) {
        final cardId = 'card_${sessionId}_0';
        final cardEntity = FlashcardEntity(
          id: cardId,
          deckId: 'deck_$sessionId',
          front: 'What are the core insights and takeaways regarding $deckTitle?',
          back: messages.isNotEmpty
              ? messages.last.text
              : 'Comprehensive study material for $deckTitle',
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
