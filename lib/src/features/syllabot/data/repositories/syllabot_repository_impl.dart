import 'dart:async';
import 'package:dio/dio.dart';
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
              String errorMsg;
              if (err is DioException) {
                final data = err.response?.data;
                if (data is Map) {
                  errorMsg =
                      data['message']?.toString() ??
                      data['error']?.toString() ??
                      err.message ??
                      'Network connection error';
                } else {
                  errorMsg = err.message ?? err.toString();
                }
              } else {
                errorMsg = err.toString().replaceFirst('Exception: ', '');
              }
              controller.addError(errorMsg);
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
      final localModels = await _local.getCachedSessions();
      try {
        final remoteModels = await _remote.getChatSessions();
        final remoteIds = remoteModels.map((m) => m.id).toSet();

        // Auto-upload offline-created sessions to remote
        for (final local in localModels) {
          if (!remoteIds.contains(local.id) && UuidUtils.isValidUuid(local.id)) {
            try {
              final created = await _remote.createChatSession(
                title: local.title,
                socraticMode: SocraticMode.values.firstWhere(
                  (m) => m.nameString == local.socraticMode,
                  orElse: () => SocraticMode.stepByStep,
                ),
                id: local.id,
              );
              remoteModels.add(created);
            } on Object catch (_) {}
          }
        }

        if (remoteModels.isNotEmpty) {
          final entities = remoteModels.map((m) => m.toEntity()).toList();
          for (final model in remoteModels) {
            await _local.saveSession(model);
          }
          return entities;
        }
      } on Object catch (_) {}

      // Fall back to persistent local storage sessions
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
      final sessionId =
          (id != null && id.isNotEmpty && UuidUtils.isValidUuid(id))
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
    if (message.engineType != ExecutionEngineType.localOnDevice) {
      unawaited(_remote.saveChatMessage(message));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getSessionMessages({
    required String sessionId,
  }) {
    return Future<List<ChatMessageEntity>>.sync(() async {
      try {
        final remote = await _remote.getSessionMessages(sessionId: sessionId);
        if (remote.isNotEmpty) {
          for (final m in remote) {
            unawaited(_local.cacheMessage(m.toEntity()));
          }
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
      final deckId = UuidUtils.generate();
      final cards = <FlashcardEntity>[];
      final flashcardModels = <FlashcardModel>[];
      final seenQuestions = <String>{};

      // 1. Construct complete, structured dialogue transcript including BOTH Student prompts and AI responses
      final fullTranscriptBuffer = StringBuffer();
      final aiResponses = <String>[];
      final qaPairs = <Map<String, String>>[];

      String? lastUserPrompt;

      for (final m in messages) {
        final text = m.text.trim();
        if (text.isEmpty) continue;

        if (m.sender == MessageSender.syllabot) {
          aiResponses.add(text);
          fullTranscriptBuffer.writeln('[Syllabot (AI Tutor)]:\n$text\n');
          if (lastUserPrompt != null && lastUserPrompt.isNotEmpty) {
            qaPairs.add({'user': lastUserPrompt, 'ai': text});
          }
        } else {
          lastUserPrompt = text;
          fullTranscriptBuffer.writeln('[Student]:\n$text\n');
        }
      }

      final fullTranscript = fullTranscriptBuffer.toString().trim();

      // Dynamically scale target card count based on total messages & transcript depth (range: 15 to 50 cards)
      final targetCount = (messages.length * 2.5).round().clamp(15, 50);

      // 2. Pure Backend AI Synthesis: Route complete conversation history through Backend Cloud AI
      if (fullTranscript.isNotEmpty) {
        try {
          final router = _studyEngineRouter ?? StudyEngineRouter();
          final studyPack = await router.generateCloudStudyPack(
            topic: deckTitle,
            count: targetCount,
            sourceText:
                'Full Interactive Study Dialogue (Student Questions + AI Tutor Responses):\n\n'
                '$fullTranscript\n\n'
                'CRITICAL FLASHCARD SYNTHESIS INSTRUCTIONS:\n'
                '1. Analyze the ENTIRE conversation history above from the initial student query to the final exchange.\n'
                '2. Identify ALL distinct topics, questions, techniques, strategies, definitions, formulas, and concepts discussed across the ENTIRE conversation.\n'
                '3. Generate at least $targetCount comprehensive active-recall flashcards covering EVERY phase of the discussion.\n'
                '4. Ensure no key insight, step, strategy, or question from ANY message is left out.\n'
                '5. Formulate clear, self-contained questions on the "front" (e.g. "What is the 5-Minute Rule for pre-work stress?") and clear, actionable explanations on the "back".',
          );

          if (studyPack.cards.isNotEmpty) {
            for (final genCard in studyPack.cards) {
              final frontText = genCard.front.trim();
              final backText = genCard.back.trim();

              final isGenericMock =
                  frontText.contains('Concept Rule') ||
                  frontText.startsWith('Cloud Concept') ||
                  frontText.startsWith('On-Device Concept') ||
                  backText.contains(r'\int_{-\infty}^{\infty}') ||
                  backText.contains(r'\nabla^2 \psi');

              final normQ = frontText.toLowerCase().replaceAll(
                RegExp('[^a-z0-9]'),
                '',
              );
              if (frontText.isNotEmpty &&
                  backText.isNotEmpty &&
                  !isGenericMock &&
                  !seenQuestions.contains(normQ)) {
                seenQuestions.add(normQ);
                final cardId = UuidUtils.generate();
                final cardEntity = FlashcardEntity(
                  id: cardId,
                  deckId: deckId,
                  front: frontText.endsWith('?') ? frontText : '$frontText?',
                  back:
                      genCard.explanation.isNotEmpty &&
                          !backText.contains(genCard.explanation)
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
          // Fall back to multi-turn semantic extraction
        }
      }

      // 3. Fallback: Multi-Turn Semantic Extraction across ALL messages & Q&A pairs
      if (cards.length < targetCount && (aiResponses.isNotEmpty || qaPairs.isNotEmpty)) {
        // 3a. Direct Student Question -> AI Response Pair extraction
        for (final pair in qaPairs) {
          if (cards.length >= 50) break;
          final qText = pair['user']!;
          final aText = pair['ai']!;

          if (qText.length < 10 || qText.toLowerCase().startsWith('well') || qText.toLowerCase().startsWith('oh thank')) {
            continue;
          }

          final question = qText.endsWith('?') ? qText : '$qText?';
          final normQ = question.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
          if (!seenQuestions.contains(normQ)) {
            seenQuestions.add(normQ);
            final cardId = UuidUtils.generate();
            final card = FlashcardEntity(
              id: cardId,
              deckId: deckId,
              front: question,
              back: aText.length > 800 ? '${aText.substring(0, 800)}...' : aText,
              sourceTopic: deckTitle,
              nextDueDate: DateTime.now().add(const Duration(days: 1)),
            );
            cards.add(card);
            flashcardModels.add(FlashcardModel.fromEntity(card));
          }
        }

        // 3b. Bullet points with bold concepts: - **Concept**: Explanation
        for (final resp in aiResponses) {
          if (cards.length >= 50) break;

          final bulletRegex = RegExp(
            r'^\s*[-*•]\s+\*\*([^*:\n]{2,60})\*\*\s*[:\-–]?\s*(.+)$',
            multiLine: true,
          );
          for (final match in bulletRegex.allMatches(resp)) {
            if (cards.length >= 50) break;
            final concept = match.group(1)!.trim();
            final detail = match.group(2)!.trim();
            if (detail.length < 15) continue;

            final question = 'What is the definition and core application of "$concept"?';
            final normQ = question.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
            if (!seenQuestions.contains(normQ)) {
              seenQuestions.add(normQ);
              final cardId = UuidUtils.generate();
              final card = FlashcardEntity(
                id: cardId,
                deckId: deckId,
                front: question,
                back: detail,
                sourceTopic: concept,
                nextDueDate: DateTime.now().add(const Duration(days: 1)),
              );
              cards.add(card);
              flashcardModels.add(FlashcardModel.fromEntity(card));
            }
          }

          // 3c. Numbered lists with bold concepts: 1. **Step/Concept**: Explanation
          final numberedRegex = RegExp(
            r'^\s*\d+[\.\)]\s+\*\*([^*:\n]{2,60})\*\*\s*[:\-–]?\s*(.+)$',
            multiLine: true,
          );
          for (final match in numberedRegex.allMatches(resp)) {
            if (cards.length >= 50) break;
            final concept = match.group(1)!.trim();
            final detail = match.group(2)!.trim();
            if (detail.length < 15) continue;

            final question = 'Explain "$concept" and its step-by-step role:';
            final normQ = question.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
            if (!seenQuestions.contains(normQ)) {
              seenQuestions.add(normQ);
              final cardId = UuidUtils.generate();
              final card = FlashcardEntity(
                id: cardId,
                deckId: deckId,
                front: question,
                back: detail,
                sourceTopic: concept,
                nextDueDate: DateTime.now().add(const Duration(days: 1)),
              );
              cards.add(card);
              flashcardModels.add(FlashcardModel.fromEntity(card));
            }
          }

          // 3d. Section headers with descriptive paragraphs
          final sectionRegex = RegExp(
            r'^(?:#{1,4}\s+|\*\*)([A-Z0-9][a-zA-Z0-9\s,\-:\?]{3,60})(?:\*\*)?:?\s*$',
            multiLine: true,
          );
          final sectionMatches = sectionRegex.allMatches(resp).toList();
          for (var i = 0; i < sectionMatches.length; i++) {
            if (cards.length >= 50) break;
            final sectionTitle = sectionMatches[i].group(1)!.trim();
            final start = sectionMatches[i].end;
            final end = (i + 1 < sectionMatches.length)
                ? sectionMatches[i + 1].start
                : resp.length;
            final sectionBody = resp.substring(start, end).trim();

            if (sectionBody.length < 30) continue;

            final lowerTitle = sectionTitle.toLowerCase();
            String question;
            if (lowerTitle.contains('theorem') || lowerTitle.contains('law')) {
              question = 'State and explain the "$sectionTitle":';
            } else if (lowerTitle.contains('step') || lowerTitle.contains('strategy')) {
              question = 'What are the key steps and techniques for "$sectionTitle"?';
            } else if (lowerTitle.contains('formula') || lowerTitle.contains('equation')) {
              question = 'What mathematical formulation defines "$sectionTitle"?';
            } else if (lowerTitle.contains('rule') || lowerTitle.contains('principle')) {
              question = 'What core rules or principles govern "$sectionTitle"?';
            } else if (lowerTitle.contains('question') || lowerTitle.contains('category')) {
              question = 'What are the key questions/categories for "$sectionTitle"?';
            } else {
              question = 'Explain the key principles and insights for "$sectionTitle":';
            }

            final normQ = question.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
            if (!seenQuestions.contains(normQ)) {
              seenQuestions.add(normQ);
              final cardId = UuidUtils.generate();
              final card = FlashcardEntity(
                id: cardId,
                deckId: deckId,
                front: question,
                back: sectionBody.length > 800
                    ? '${sectionBody.substring(0, 800)}...'
                    : sectionBody,
                sourceTopic: sectionTitle,
                nextDueDate: DateTime.now().add(const Duration(days: 1)),
              );
              cards.add(card);
              flashcardModels.add(FlashcardModel.fromEntity(card));
            }
          }
        }
      }

      // 4. Absolute Fallback if cards list is still empty
      if (cards.isEmpty) {
        final fallbackBack = aiResponses.isNotEmpty
            ? aiResponses.first
            : 'Study deck generated from Syllabot AI dialogue on $deckTitle';
        final cardId = UuidUtils.generate();
        final cardEntity = FlashcardEntity(
          id: cardId,
          deckId: deckId,
          front: 'What are the principal insights explained for $deckTitle?',
          back: fallbackBack.length > 500
              ? '${fallbackBack.substring(0, 500)}...'
              : fallbackBack,
          sourceTopic: deckTitle,
          nextDueDate: DateTime.now().add(const Duration(days: 1)),
        );
        cards.add(cardEntity);
        flashcardModels.add(FlashcardModel.fromEntity(cardEntity));
      }

      final deckEntity = DeckEntity(
        id: deckId,
        title: deckTitle,
        subject: courseCode,
        courseCode: courseCode,
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
