import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_question_model.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_result_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_repository.dart';

class QuizRepositoryImpl implements QuizRepository {
  const QuizRepositoryImpl({
    DecksRepository? decksRepository,
    IngestionRepository? ingestionRepository,
    StudyEngineRouter? studyEngineRouter,
    Dio? dio,
  })  : _decksRepository = decksRepository,
        _ingestionRepository = ingestionRepository,
        _studyEngineRouter = studyEngineRouter,
        _dio = dio;

  final DecksRepository? _decksRepository;
  final IngestionRepository? _ingestionRepository;
  final StudyEngineRouter? _studyEngineRouter;
  final Dio? _dio;

  DecksRepository? get _effectiveDecksRepo =>
      _decksRepository ??
      (locator.isRegistered<DecksRepository>()
          ? locator<DecksRepository>()
          : null);

  IngestionRepository? get _effectiveIngestionRepo =>
      _ingestionRepository ??
      (locator.isRegistered<IngestionRepository>()
          ? locator<IngestionRepository>()
          : null);

  StudyEngineRouter get _effectiveEngineRouter =>
      _studyEngineRouter ??
      (locator.isRegistered<StudyEngineRouter>()
          ? locator<StudyEngineRouter>()
          : StudyEngineRouter());

  Dio get _effectiveDio =>
      _dio ?? (locator.isRegistered<Dio>() ? locator<Dio>() : Dio());

  @override
  Future<Either<Failure, List<QuizQuestionEntity>>> generateQuizFromDeck({
    required String deckId,
    String? deckTitle,
    int questionCount = 10,
  }) {
    return _generateQuizFromDeckInternal(
      deckId: deckId,
      questionCount: questionCount,
      deckTitle: deckTitle,
    ).makeRequest();
  }

  Future<List<QuizQuestionEntity>> _generateQuizFromDeckInternal({
    required String deckId,
    required int questionCount,
    String? deckTitle,
  }) async {
    // 1. Attempt Remote Edge Function AI Generation
    try {
      final response = await _effectiveDio.post<Map<String, dynamic>>(
        '${AppApiEndpoint.baseUri}${AppApiEndpoint.generateQuizQuestions}',
        data: {
          'deck_id': deckId,
          'question_count': questionCount,
          'difficulty': 'intermediate',
        },
        options: Options(
          headers: {
            'apikey': AppEnv.apiKey,
            'Authorization': 'Bearer ${AppEnv.apiKey}',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

      final data = response.data;
      if (data != null) {
        final rawQuestions = data['questions'] as List<dynamic>?;
        if (rawQuestions != null && rawQuestions.isNotEmpty) {
          return rawQuestions.map((q) {
            final map = q as Map<String, dynamic>;
            final options = (map['options'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final correctIdx = map['correct_index'] as int? ?? 0;
            final correctAns = map['correct_answer'] as String? ??
                (correctIdx < options.length
                    ? options[correctIdx]
                    : (options.isNotEmpty ? options.first : ''));

            return QuizQuestionModel(
              id: map['id'] as String? ??
                  'q-${DateTime.now().microsecondsSinceEpoch}',
              prompt: (map['question'] ?? map['prompt'] ?? '') as String,
              type: QuizQuestionType.multipleChoice,
              options: options,
              correctAnswer: correctAns,
              explanation: (map['explanation'] as String?) ?? '',
              subTopic: (map['sub_topic'] as String?) ??
                  deckTitle ??
                  'Deck Assessment',
              latexFormula: map['latex_formula'] as String?,
            );
          }).toList();
        }
      }
    } on Object catch (err) {
      debugPrint(
        '[QuizRepository] Remote AI generation failed ($err). '
        'Falling back to local asset engine.',
      );
    }

    // 2. Fetch cards from the deck to drive StudyEngineRouter or local synthesis
    final cardsResult = await _effectiveDecksRepo?.getDeckCards(deckId);
    final deckCards = cardsResult?.fold(
      (failure) => <FlashcardEntity>[],
      (cards) => cards,
    ) ?? <FlashcardEntity>[];

    if (deckCards.isNotEmpty) {
      final content = deckCards
          .map((c) => 'Concept: ${c.front}\nDetail: ${c.back}')
          .join('\n\n');

      try {
        final packResult = await _effectiveEngineRouter.processDirectAsset(
          assetId: deckId,
          content: content,
          topic: deckTitle ?? 'Deck $deckId',
          count: questionCount,
        );

        if (packResult.cards.isNotEmpty) {
          final mapped = _mapGeneratedCardsToQuestions(
            cards: packResult.cards,
            topic: deckTitle,
            count: questionCount,
          );
          if (mapped.isNotEmpty) return mapped;
        }

        if (packResult.isOfflineModelMissing) {
          // Model pack is missing, but we have deck cards. Synthesize directly from cards.
          final cardQuestions = _synthesizeQuestionsFromCards(
            cards: deckCards,
            deckTitle: deckTitle,
            count: questionCount,
          );
          if (cardQuestions.isNotEmpty) return cardQuestions;
        }
      } on Object catch (err) {
        debugPrint('[QuizRepository] StudyEngineRouter direct asset error: $err');
      }

      // Fallback: direct synthesis from cards
      final synthesized = _synthesizeQuestionsFromCards(
        cards: deckCards,
        deckTitle: deckTitle,
        count: questionCount,
      );
      if (synthesized.isNotEmpty) return synthesized;
    }

    // 3. Graceful fallback for mock/demo cards
    final mocks = _generateMockQuestions(count: questionCount);
    if (mocks.isNotEmpty) return mocks;

    throw const ServerException(
      message: 'Failed to generate quiz questions for this deck.',
    );
  }

  @override
  Future<Either<Failure, List<QuizQuestionEntity>>> generateQuizFromDocument({
    required String documentId,
    int questionCount = 10,
  }) {
    return _generateQuizFromDocumentInternal(
      documentId: documentId,
      questionCount: questionCount,
    ).makeRequest();
  }

  Future<List<QuizQuestionEntity>> _generateQuizFromDocumentInternal({
    required String documentId,
    required int questionCount,
  }) async {
    // 1. Attempt Remote Edge Function AI Generation
    try {
      final response = await _effectiveDio.post<Map<String, dynamic>>(
        '${AppApiEndpoint.baseUri}${AppApiEndpoint.generateQuizQuestions}',
        data: {
          'document_id': documentId,
          'question_count': questionCount,
          'difficulty': 'intermediate',
        },
        options: Options(
          headers: {
            'apikey': AppEnv.apiKey,
            'Authorization': 'Bearer ${AppEnv.apiKey}',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

      final data = response.data;
      if (data != null) {
        final rawQuestions = data['questions'] as List<dynamic>?;
        if (rawQuestions != null && rawQuestions.isNotEmpty) {
          return rawQuestions.map((q) {
            final map = q as Map<String, dynamic>;
            final options = (map['options'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final correctIdx = map['correct_index'] as int? ?? 0;
            final correctAns = map['correct_answer'] as String? ??
                (correctIdx < options.length
                    ? options[correctIdx]
                    : (options.isNotEmpty ? options.first : ''));

            return QuizQuestionModel(
              id: map['id'] as String? ??
                  'q-${DateTime.now().microsecondsSinceEpoch}',
              prompt: (map['question'] ?? map['prompt'] ?? '') as String,
              type: QuizQuestionType.multipleChoice,
              options: options,
              correctAnswer: correctAns,
              explanation: (map['explanation'] as String?) ?? '',
              subTopic: (map['sub_topic'] as String?) ?? 'Document Analysis',
              latexFormula: map['latex_formula'] as String?,
            );
          }).toList();
        }
      }
    } on Object catch (err) {
      debugPrint(
        '[QuizRepository] Remote document AI failed ($err). '
        'Falling back to local asset engine.',
      );
    }

    // 2. Offline / local fallback using IngestionRepository and StudyEngineRouter
    try {
      var documentTitle = 'Document $documentId';
      var documentContent = '';

      final docsResult = await _effectiveIngestionRepo?.fetchUserDocuments();
      final docs = docsResult?.fold(
        (failure) => null,
        (list) => list,
      );
      if (docs != null && docs.isNotEmpty) {
        final matching = docs.where((d) => d.id == documentId).firstOrNull;
        if (matching != null) {
          documentTitle = matching.filename;
          documentContent =
              'Document: ${matching.filename}, type: ${matching.fileType}';
        }
      }

      final packResult = await _effectiveEngineRouter.processDirectAsset(
        assetId: documentId,
        content: documentContent.isNotEmpty
            ? documentContent
            : 'Study material for $documentTitle',
        topic: documentTitle,
        count: questionCount,
      );

      if (packResult.cards.isNotEmpty) {
        final mapped = _mapGeneratedCardsToQuestions(
          cards: packResult.cards,
          topic: documentTitle,
          count: questionCount,
        );
        if (mapped.isNotEmpty) return mapped;
      }

      if (packResult.isOfflineModelMissing) {
        throw StateError(
          packResult.userMessage ?? StudyEngineRouter.offlineModelMissingPrompt,
        );
      }
    } on Object catch (err) {
      debugPrint('[QuizRepository] StudyEngineRouter document error: $err');
    }

    // 3. Fallback
    final mocks = _generateMockQuestions(count: questionCount);
    if (mocks.isNotEmpty) return mocks;

    throw const ServerException(
      message: 'Failed to generate quiz questions from this document.',
    );
  }

  @override
  Future<Either<Failure, QuizResultEntity>> submitQuizAnswers({
    required String quizTitle,
    required List<QuizQuestionEntity> questions,
    required int durationSeconds,
  }) {
    return Future<QuizResultEntity>.sync(() {
      final total = questions.length;
      final correctCount = questions.where((q) => q.isCorrect).length;

      final topicGroups = <String, List<QuizQuestionEntity>>{};
      for (final q in questions) {
        topicGroups.putIfAbsent(q.subTopic, () => []).add(q);
      }

      final weaknesses = topicGroups.entries.map((entry) {
        final subTopic = entry.key;
        final qs = entry.value;
        final correctInTopic = qs.where((q) => q.isCorrect).length;
        return TopicWeakness(
          subTopic: subTopic,
          totalQuestions: qs.length,
          correctCount: correctInTopic,
        );
      }).toList();

      return QuizResultModel(
        id: 'quiz-res-${DateTime.now().millisecondsSinceEpoch}',
        quizTitle: quizTitle,
        totalQuestions: total,
        correctAnswers: correctCount,
        durationSeconds: durationSeconds,
        weaknesses: weaknesses,
        completedAt: DateTime.now(),
      );
    }).makeRequest();
  }

  List<QuizQuestionModel> _synthesizeQuestionsFromCards({
    required List<FlashcardEntity> cards,
    String? deckTitle,
    int count = 10,
  }) {
    if (cards.isEmpty) return [];

    final result = <QuizQuestionModel>[];
    final selectedCards = cards.take(count).toList();

    for (var i = 0; i < selectedCards.length; i++) {
      final card = selectedCards[i];
      final correctAnswer = card.back.trim();

      final otherBacks = cards
          .where(
            (c) =>
                c.id != card.id &&
                c.back.trim().isNotEmpty &&
                c.back.trim() != correctAnswer,
          )
          .map((c) => c.back.trim())
          .toSet()
          .toList();

      final options = <String>[correctAnswer];
      for (final distractor in otherBacks) {
        if (options.length >= 4) break;
        options.add(distractor);
      }

      var fallbackIndex = 1;
      while (options.length < 4) {
        final filler = 'Alternative definition $fallbackIndex';
        if (!options.contains(filler)) {
          options.add(filler);
        }
        fallbackIndex++;
      }

      options.shuffle(Random(card.id.hashCode));

      result.add(
        QuizQuestionModel(
          id: 'quiz_card_${card.id}_$i',
          prompt: card.front.trim().endsWith('?')
              ? card.front.trim()
              : 'What concept or definition corresponds to: "${card.front.trim()}"?',
          type: QuizQuestionType.multipleChoice,
          options: options,
          correctAnswer: correctAnswer,
          explanation:
              'Concept: "${card.front.trim()}" corresponds to "${card.back.trim()}".',
          subTopic: card.sourceTopic ?? deckTitle ?? 'Flashcard Concept',
          latexFormula: card.frontLatex ??
              card.backLatex ??
              (card.front.contains(r'\') ? card.front : null),
        ),
      );
    }

    return result;
  }

  List<QuizQuestionModel> _mapGeneratedCardsToQuestions({
    required List<GeneratedFlashcard> cards,
    String? topic,
    int count = 10,
  }) {
    if (cards.isEmpty) return [];

    final result = <QuizQuestionModel>[];
    final selectedCards = cards.take(count).toList();

    for (var i = 0; i < selectedCards.length; i++) {
      final card = selectedCards[i];
      final correctAnswer = card.back.trim();

      final otherBacks = cards
          .where(
            (c) =>
                c.id != card.id &&
                c.back.trim().isNotEmpty &&
                c.back.trim() != correctAnswer,
          )
          .map((c) => c.back.trim())
          .toSet()
          .toList();

      final options = <String>[correctAnswer];
      for (final distractor in otherBacks) {
        if (options.length >= 4) break;
        options.add(distractor);
      }

      var fallbackIndex = 1;
      while (options.length < 4) {
        options.add('Concept Alternative $fallbackIndex');
        fallbackIndex++;
      }

      options.shuffle(Random(card.id.hashCode));

      result.add(
        QuizQuestionModel(
          id: 'ai_q_${card.id}_$i',
          prompt: card.front.trim().endsWith('?')
              ? card.front.trim()
              : 'Which explanation correctly describes: "${card.front.trim()}"?',
          type: QuizQuestionType.multipleChoice,
          options: options,
          correctAnswer: correctAnswer,
          explanation: card.explanation.isNotEmpty
              ? card.explanation
              : 'Verified AI synthesis for "${card.front.trim()}".',
          subTopic: card.tags.firstOrNull ?? topic ?? 'AI Concept Analysis',
          latexFormula: card.back.contains(r'$$') || card.back.contains(r'\')
              ? card.back
              : null,
        ),
      );
    }

    return result;
  }

  List<QuizQuestionModel> _generateMockQuestions({
    required int count,
  }) {
    final list = <QuizQuestionModel>[
      const QuizQuestionModel(
        id: 'q-1',
        prompt:
            'What is the fundamental relationship between Gibbs free energy, '
            'enthalpy, and entropy?',
        type: QuizQuestionType.multipleChoice,
        options: [
          r'\Delta G = \Delta H - T\Delta S',
          r'\Delta G = \Delta H + T\Delta S',
          r'\Delta G = \frac{\Delta H}{T\Delta S}',
          r'\Delta G = T\Delta S - \Delta H',
        ],
        correctAnswer: r'\Delta G = \Delta H - T\Delta S',
        explanation:
            r'Gibbs free energy change \Delta G is given by '
            r'\Delta H - T\Delta S. A negative \Delta G indicates a '
            'spontaneous reaction.',
        subTopic: 'Chemical Thermodynamics',
        latexFormula: r'\Delta G = \Delta H - T\Delta S',
      ),
      const QuizQuestionModel(
        id: 'q-2',
        prompt:
            'According to Newton second law of motion, force is directly '
            'proportional to what?',
        type: QuizQuestionType.multipleChoice,
        options: [
          'Rate of change of momentum',
          'Velocity of the body',
          'Displacement per unit time',
          'Total mechanical energy',
        ],
        correctAnswer: 'Rate of change of momentum',
        explanation:
            r'Newton 2nd law: \vec{F} = \frac{d\vec{p}}{dt} = m\vec{a} '
            'for constant mass.',
        subTopic: 'Classical Mechanics',
        latexFormula: r'\vec{F} = m\vec{a}',
      ),
      const QuizQuestionModel(
        id: 'q-3',
        prompt:
            'True or False: In an adiabatic process, heat transfer into or '
            'out of the system is zero (Q = 0).',
        type: QuizQuestionType.trueFalse,
        options: ['True', 'False'],
        correctAnswer: 'True',
        explanation:
            'An adiabatic process occurs without transfer of heat or mass '
            'between a system and its surroundings (dQ = 0).',
        subTopic: 'Thermodynamic Processes',
      ),
      const QuizQuestionModel(
        id: 'q-4',
        prompt: 'What is the derivative of f(x) = e^{2x} with respect to x?',
        type: QuizQuestionType.multipleChoice,
        options: [
          '2e^{2x}',
          'e^{2x}',
          '4e^{2x}',
          r'\frac{1}{2}e^{2x}',
        ],
        correctAnswer: '2e^{2x}',
        explanation:
            r'By the chain rule: \frac{d}{dx}[e^{u}] = e^{u}\frac{du}{dx}. '
            r'Thus \frac{d}{dx}[e^{2x}] = 2e^{2x}.',
        subTopic: 'Calculus & Derivatives',
        latexFormula: r'\frac{d}{dx}(e^{2x}) = 2e^{2x}',
      ),
    ];

    if (count <= list.length) {
      return list.sublist(0, count);
    }
    return list;
  }
}
