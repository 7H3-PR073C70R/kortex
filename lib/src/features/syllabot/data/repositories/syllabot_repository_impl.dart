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
      final seenQuestions = <String>{};
      var cardIndex = 0;

      // 1. Scan entire chat and collect strictly AI assistant responses (exclude user prompts)
      final aiResponses = messages
          .where((m) => m.sender == MessageSender.syllabot)
          .map((m) => m.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final aiTranscript = aiResponses.join('\n\n---\n\n');

      // 2. AI Synthesis: Route AI explanations through StudyEngineRouter (Cloud or Local GGUF)
      if (aiTranscript.isNotEmpty) {
        try {
          final router = _studyEngineRouter ?? StudyEngineRouter();
          final studyPack = await router.generateStudyPack(
            topic: deckTitle,
            count: 10,
            sourceText: 'AI Study Explanations for "$deckTitle":\n\n$aiTranscript\n\n'
                'Synthesize unique, concept-specific flashcards from the above AI explanations. '
                'Formulate distinct questions and in-depth answers. Do not duplicate questions.',
          );

          if (studyPack.cards.isNotEmpty) {
            for (final genCard in studyPack.cards) {
              final frontText = genCard.front.trim();
              final backText = genCard.back.trim();

              final isGenericMock = frontText.contains('Concept Rule') ||
                  frontText.startsWith('Cloud Concept') ||
                  frontText.startsWith('On-Device Concept') ||
                  backText.contains(r'\int_{-\infty}^{\infty}') ||
                  backText.contains(r'\nabla^2 \psi');

              final normQ = frontText.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
              if (frontText.isNotEmpty &&
                  backText.isNotEmpty &&
                  !isGenericMock &&
                  !seenQuestions.contains(normQ)) {
                seenQuestions.add(normQ);
                final cardId = 'card_${sessionId}_${cardIndex++}';
                final cardEntity = FlashcardEntity(
                  id: cardId,
                  deckId: 'deck_$sessionId',
                  front: frontText.endsWith('?') ? frontText : '$frontText?',
                  back: genCard.explanation.isNotEmpty && !backText.contains(genCard.explanation)
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
          // Fall back to semantic AI response extraction
        }
      }

      // 3. In-depth Semantic AI Extraction: Parse unique conceptual Q&As strictly from AI content
      if (cards.length < 5 && aiResponses.isNotEmpty) {
        for (final resp in aiResponses) {
          // 3a. Bullet points with bold concepts: - **Concept**: Explanation
          final bulletRegex = RegExp(
            r'^\s*[-*•]\s+\*\*([^*:\n]{2,60})\*\*\s*[:\-–]?\s*(.+)$',
            multiLine: true,
          );
          for (final match in bulletRegex.allMatches(resp)) {
            if (cards.length >= 15) break;
            final concept = match.group(1)!.trim();
            final detail = match.group(2)!.trim();
            if (detail.length < 15) continue;

            final question = 'What is the definition and role of "$concept" in $deckTitle?';
            final normQ = question.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
            if (!seenQuestions.contains(normQ)) {
              seenQuestions.add(normQ);
              final cardId = 'card_${sessionId}_${cardIndex++}';
              final card = FlashcardEntity(
                id: cardId,
                deckId: 'deck_$sessionId',
                front: question,
                back: detail,
                sourceTopic: deckTitle,
                nextDueDate: DateTime.now().add(const Duration(days: 1)),
              );
              cards.add(card);
              flashcardModels.add(FlashcardModel.fromEntity(card));
            }
          }

          // 3b. Numbered lists with bold concepts: 1. **Step/Concept**: Explanation
          final numberedRegex = RegExp(
            r'^\s*\d+[\.\)]\s+\*\*([^*:\n]{2,60})\*\*\s*[:\-–]?\s*(.+)$',
            multiLine: true,
          );
          for (final match in numberedRegex.allMatches(resp)) {
            if (cards.length >= 15) break;
            final concept = match.group(1)!.trim();
            final detail = match.group(2)!.trim();
            if (detail.length < 15) continue;

            final question = 'How does "$concept" apply to the study of $deckTitle?';
            final normQ = question.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
            if (!seenQuestions.contains(normQ)) {
              seenQuestions.add(normQ);
              final cardId = 'card_${sessionId}_${cardIndex++}';
              final card = FlashcardEntity(
                id: cardId,
                deckId: 'deck_$sessionId',
                front: question,
                back: detail,
                sourceTopic: deckTitle,
                nextDueDate: DateTime.now().add(const Duration(days: 1)),
              );
              cards.add(card);
              flashcardModels.add(FlashcardModel.fromEntity(card));
            }
          }

          // 3c. Section headers with descriptive paragraphs
          final sectionRegex = RegExp(
            r'^(?:#{1,4}\s+|\*\*)([A-Z][a-zA-Z0-9\s,\-]{3,50})(?:\*\*)?:?\s*$',
            multiLine: true,
          );
          final sectionMatches = sectionRegex.allMatches(resp).toList();
          for (var i = 0; i < sectionMatches.length; i++) {
            if (cards.length >= 15) break;
            final sectionTitle = sectionMatches[i].group(1)!.trim();
            final start = sectionMatches[i].end;
            final end = (i + 1 < sectionMatches.length) ? sectionMatches[i + 1].start : resp.length;
            final sectionBody = resp.substring(start, end).trim();

            if (sectionBody.length < 30) continue;

            final lowerTitle = sectionTitle.toLowerCase();
            String question;
            if (lowerTitle.contains('theorem') || lowerTitle.contains('law')) {
              question = 'State and explain the "$sectionTitle" for $deckTitle:';
            } else if (lowerTitle.contains('proof') || lowerTitle.contains('derivation')) {
              question = 'What are the key steps in the derivation for "$sectionTitle"?';
            } else if (lowerTitle.contains('formula') || lowerTitle.contains('equation')) {
              question = 'What mathematical formulation defines "$sectionTitle"?';
            } else if (lowerTitle.contains('summary') || lowerTitle.contains('conclusion')) {
              question = 'What are the core conclusions reached regarding "$sectionTitle"?';
            } else {
              question = 'In $deckTitle, how is "$sectionTitle" structured and explained?';
            }

            final normQ = question.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
            if (!seenQuestions.contains(normQ)) {
              seenQuestions.add(normQ);
              final cardId = 'card_${sessionId}_${cardIndex++}';
              final card = FlashcardEntity(
                id: cardId,
                deckId: 'deck_$sessionId',
                front: question,
                back: sectionBody.length > 500 ? '${sectionBody.substring(0, 500)}...' : sectionBody,
                sourceTopic: deckTitle,
                nextDueDate: DateTime.now().add(const Duration(days: 1)),
              );
              cards.add(card);
              flashcardModels.add(FlashcardModel.fromEntity(card));
            }
          }

          // 3d. Mathematical formulas with context
          final formulaRegex = RegExp(r'(\$\$.*?\$\$|\\\[.*?\\\])', dotAll: true);
          final formulaMatches = formulaRegex.allMatches(resp);
          for (final fMatch in formulaMatches) {
            if (cards.length >= 15) break;
            final formula = fMatch.group(1)!.trim();
            final cardId = 'card_${sessionId}_${cardIndex++}';
            final question = 'What is the governing equation for "$deckTitle" in this context?';
            final normQ = question.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
            if (!seenQuestions.contains(normQ)) {
              seenQuestions.add(normQ);
              final card = FlashcardEntity(
                id: cardId,
                deckId: 'deck_$sessionId',
                front: question,
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
      }

      // 4. Fallback if still empty (use AI response summary, never user prompt)
      if (cards.isEmpty) {
        final fallbackBack = aiResponses.isNotEmpty
            ? aiResponses.first
            : 'Study deck generated from Syllabot AI responses on $deckTitle';
        final cardId = 'card_${sessionId}_0';
        final cardEntity = FlashcardEntity(
          id: cardId,
          deckId: 'deck_$sessionId',
          front: 'What are the principal insights explained for $deckTitle?',
          back: fallbackBack.length > 400 ? '${fallbackBack.substring(0, 400)}...' : fallbackBack,
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
