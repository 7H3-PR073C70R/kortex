import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_question_model.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_result_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_repository.dart';

class QuizRepositoryImpl implements QuizRepository {
  const QuizRepositoryImpl({
    DecksRepository? decksRepository,
    IngestionRepository? ingestionRepository,
    PastQuestionsRepository? pastQuestionsRepository,
    StudyEngineRouter? studyEngineRouter,
    Dio? dio,
    LocalStorageService? localStorageService,
    UserStorageService? userStorageService,
    UserActivityService? userActivityService,
  })  : _decksRepository = decksRepository,
        _ingestionRepository = ingestionRepository,
        _pastQuestionsRepository = pastQuestionsRepository,
        _studyEngineRouter = studyEngineRouter,
        _dio = dio,
        _localStorageService = localStorageService,
        _userStorageService = userStorageService,
        _userActivityService = userActivityService;

  final DecksRepository? _decksRepository;
  final IngestionRepository? _ingestionRepository;
  final PastQuestionsRepository? _pastQuestionsRepository;
  final StudyEngineRouter? _studyEngineRouter;
  final Dio? _dio;
  final LocalStorageService? _localStorageService;
  final UserStorageService? _userStorageService;
  final UserActivityService? _userActivityService;

  static const String cbtSubmissionsStorageKey =
      'kortex_cbt_test_submissions';

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

  PastQuestionsRepository? get _effectivePastQuestionsRepo =>
      _pastQuestionsRepository ??
      (locator.isRegistered<PastQuestionsRepository>()
          ? locator<PastQuestionsRepository>()
          : null);

  StudyEngineRouter get _effectiveEngineRouter =>
      _studyEngineRouter ??
      (locator.isRegistered<StudyEngineRouter>()
          ? locator<StudyEngineRouter>()
          : StudyEngineRouter());

  Dio get _effectiveDio =>
      _dio ?? (locator.isRegistered<Dio>() ? locator<Dio>() : Dio());

  LocalStorageService? get _effectiveLocalStorage =>
      _localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  UserStorageService? get _effectiveUserStorage =>
      _userStorageService ??
      (locator.isRegistered<UserStorageService>()
          ? locator<UserStorageService>()
          : null);

  UserActivityService? get _effectiveUserActivity =>
      _userActivityService ??
      (locator.isRegistered<UserActivityService>()
          ? locator<UserActivityService>()
          : null);

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

    if (deckCards.isEmpty) {
      final isExam = deckId.toLowerCase().startsWith('exam') ||
          deckId.toLowerCase().startsWith('cbt_') ||
          (deckTitle != null &&
              (deckTitle.toLowerCase().contains('exam') ||
                  deckTitle.toLowerCase().contains('simulator') ||
                  deckTitle.toLowerCase().contains('mock')));

      if (_effectivePastQuestionsRepo != null) {
        ExamCategory? matchedCat;
        final query = '${deckTitle ?? ''} $deckId'.toLowerCase();
        for (final cat in ExamCategory.values) {
          if (query.contains(cat.name.toLowerCase()) ||
              query.contains(cat.code.toLowerCase())) {
            matchedCat = cat;
            break;
          }
        }

        try {
          final pqResult = await _effectivePastQuestionsRepo!.getPastQuestions(
            examCategory: matchedCat,
            searchQuery: matchedCat == null ? (deckTitle ?? deckId) : null,
          );
          final pastQuestions = pqResult.fold(
            (f) => <PastQuestionEntity>[],
            (q) => q,
          );

          if (pastQuestions.isNotEmpty) {
            final shuffled = List<PastQuestionEntity>.from(pastQuestions)
              ..shuffle();
            return shuffled
                .take(min(questionCount, pastQuestions.length))
                .map(QuizQuestionEntity.fromPastQuestion)
                .toList();
          }
        } on Object catch (pqErr) {
          debugPrint('[QuizRepository] Error loading past questions: $pqErr');
        }
      }

      if (isExam) {
        return _synthesizeExamSimulatorQuestions(
          examTitle: deckTitle ?? 'Exam Simulator',
          examId: deckId,
          count: questionCount,
        );
      }

      throw const ServerException(
        message:
            'Cannot generate a quiz from an empty deck. Please add flashcards to this deck first.',
      );
    }

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

    // Fallback: direct dynamic synthesis from cards
    final synthesized = _synthesizeQuestionsFromCards(
      cards: deckCards,
      deckTitle: deckTitle,
      count: questionCount,
    );
    if (synthesized.isNotEmpty) return synthesized;

    throw const ServerException(
      message: 'Failed to synthesize quiz questions from the provided deck cards.',
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
      final docsResult = await _effectiveIngestionRepo?.fetchUserDocuments();
      final docs = docsResult?.fold(
        (failure) => null,
        (list) => list,
      );

      final matching = docs?.where((d) => d.id == documentId).firstOrNull;
      if (matching == null) {
        throw ServerException(
          message: 'Unable to locate document "$documentId" for quiz generation.',
        );
      }

      final documentTitle = matching.filename;
      final documentContent =
          'Document: ${matching.filename}, type: ${matching.fileType}';

      final packResult = await _effectiveEngineRouter.processDirectAsset(
        assetId: documentId,
        content: documentContent,
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
      if (err is ServerException || err is StateError) rethrow;
    }

    throw const ServerException(
      message: 'Failed to generate quiz questions from this document. Please ensure the document contains readable study material.',
    );
  }

  @override
  Future<Either<Failure, QuizResultEntity>> submitQuizAnswers({
    required String quizTitle,
    required List<QuizQuestionEntity> questions,
    required int durationSeconds,
  }) {
    return Future<QuizResultEntity>.sync(() async {
      final total = questions.length;
      final correctCount = questions.where((q) => q.isCorrect).length;
      final scorePercent =
          total > 0 ? ((correctCount / total) * 100).round() : 0;
      final completedAt = DateTime.now();

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

      final weakSubtopics = weaknesses
          .where((w) => w.accuracy < 0.75)
          .map((w) => w.subTopic)
          .toList();

      final resultModel = QuizResultModel(
        id: 'quiz-res-${completedAt.millisecondsSinceEpoch}',
        quizTitle: quizTitle,
        totalQuestions: total,
        correctAnswers: correctCount,
        durationSeconds: durationSeconds,
        weaknesses: weaknesses,
        completedAt: completedAt,
      );

      // 1. Persist to LocalStorageService for robust offline availability
      try {
        final storage = _effectiveLocalStorage;
        if (storage != null) {
          final existingJson =
              storage.getPreference(key: cbtSubmissionsStorageKey);
          final submissionsList =
              (existingJson != null && existingJson.isNotEmpty
                  ? (jsonDecode(existingJson) as List<dynamic>)
                  : <dynamic>[])
                ..add(resultModel.toJson());
          // Keep up to 200 persistent CBT submissions
          if (submissionsList.length > 200) {
            submissionsList.removeRange(0, submissionsList.length - 200);
          }
          await storage.savePreference(
            key: cbtSubmissionsStorageKey,
            data: jsonEncode(submissionsList),
          );
        }
      } on Object catch (localErr) {
        debugPrint(
          '[QuizRepository] Failed to persist quiz result locally: $localErr',
        );
      }

      // 2. Record learning activity in UserActivityService
      try {
        final activity = _effectiveUserActivity;
        if (activity != null) {
          await activity.recordStudySession(
            cardsReviewed: total,
            durationSeconds: durationSeconds,
            retentionScore:
                total > 0 ? (correctCount / total).clamp(0.0, 1.0) : 0.0,
            masteredCards: correctCount,
          );
        }
      } on Object catch (activityErr) {
        debugPrint(
          '[QuizRepository] Failed to record user activity: $activityErr',
        );
      }

      // 3. Persist to Remote Database table public.quizzes
      try {
        final userStorage = _effectiveUserStorage;
        final token = userStorage?.getToken();
        final userId = userStorage?.getUserId();
        final authHeader = token != null && token.isNotEmpty
            ? 'Bearer $token'
            : 'Bearer ${AppEnv.apiKey}';

        final payload = <String, dynamic>{
          'title': quizTitle,
          'total_questions': total,
          'correct_answers': correctCount,
          'score_percent': scorePercent,
          'duration_seconds': durationSeconds,
          'weak_subtopics': weakSubtopics,
          'completed_at': completedAt.toUtc().toIso8601String(),
        };
        if (userId != null && userId.isNotEmpty) {
          payload['user_id'] = userId;
        }

        await _effectiveDio.post<dynamic>(
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.quizzes}',
          data: payload,
          options: Options(
            headers: {
              'apikey': AppEnv.apiKey,
              'Authorization': authHeader,
              'Prefer': 'return=representation',
            },
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
      } on Object catch (remoteErr) {
        debugPrint(
          '[QuizRepository] Remote quiz submission sync postponed/failed: $remoteErr',
        );
      }

      return resultModel;
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
                c.back.trim().toLowerCase() != correctAnswer.toLowerCase(),
          )
          .map((c) => c.back.trim())
          .toSet()
          .toList();

      final options = <String>[correctAnswer];
      for (final distractor in otherBacks) {
        if (options.length >= 4) break;
        options.add(distractor);
      }

      if (options.length < 4) {
        final semanticDistractors = _generateSemanticDistractors(
          correctAnswer: correctAnswer,
          prompt: card.front.trim(),
          topic: card.sourceTopic ?? deckTitle,
          count: 4 - options.length,
        );
        for (final distractor in semanticDistractors) {
          if (options.length >= 4) break;
          if (!options.contains(distractor)) {
            options.add(distractor);
          }
        }
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

  List<QuizQuestionModel> _synthesizeExamSimulatorQuestions({
    required String examTitle,
    required String examId,
    int count = 10,
  }) {
    final cleanTitle =
        examTitle.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    final questions = <QuizQuestionModel>[];

    final coreCompetencies = [
      (
        'Fundamental Principles',
        'Which core principle is most critical to master in $cleanTitle?',
        'Foundational domain comprehension and rigorous systematic application',
        [
          'Superficial memorization of edge cases without principles',
          'Random sampling of unrelated tertiary concepts',
          'Disregarding theoretical underpinnings in favor of guesswork',
        ],
        'High-yield exam performance depends on deep conceptual mastery rather than rote memorization.',
      ),
      (
        'Analytical Problem Solving',
        'When evaluating complex problem sets in $cleanTitle, what is the optimal first step?',
        'Deconstruct the problem into constituent requirements and verify boundary conditions',
        [
          'Jump directly to conclusion based on first impression',
          'Ignore question constraints and apply generic assumptions',
          'Calculate outputs before defining variables or given constraints',
        ],
        'Systematic decomposition ensures all constraints are accounted for before synthesis.',
      ),
      (
        'Critical Verification',
        'In high-stakes examination settings for $cleanTitle, how should results be verified?',
        'Dimensional analysis, reverse-verification, and sanity checking against baseline thresholds',
        [
          'Assuming the first computed value is always error-free',
          'Skipping validation to preserve testing time regardless of margin',
          'Changing answers at random without systematic evaluation',
        ],
        'Reverse verification and dimensional consistency catch common examination traps.',
      ),
      (
        'Standard Methodology',
        'What characterizes a standard rigorous methodology when approaching $cleanTitle assessments?',
        'Evidence-based reasoning adhering to established standardized rubrics and guidelines',
        [
          'Unsubstantiated intuitive speculation',
          'Disregarding established conventions for proprietary shortcuts',
          'Inconsistent notation and unreferenced formulas',
        ],
        'Standardized examinations strictly score based on established rubrics and methodology.',
      ),
      (
        'Error Minimization',
        'Which technique is most effective for mitigating common cognitive traps in $cleanTitle?',
        'Active elimination of demonstrably false distractors prior to selecting the target answer',
        [
          'Selecting the option with the most complex vocabulary regardless of fit',
          'Relying solely on visual symmetry of answer keys',
          'Ignoring negative qualifiers like NOT or EXCEPT in prompts',
        ],
        'Process of elimination actively isolates distractors with deceptive wording.',
      ),
    ];

    for (var i = 0; i < count; i++) {
      final comp = coreCompetencies[i % coreCompetencies.length];
      final options = [comp.$3, ...comp.$4]..shuffle(Random(i * 17));

      questions.add(
        QuizQuestionModel(
          id: 'sim-${examId.replaceAll(RegExp('[^a-zA-Z0-9]'), '_')}-$i',
          prompt: i < coreCompetencies.length
              ? comp.$2
              : '[$cleanTitle Simulator - Q${i + 1}] ${comp.$2}',
          type: QuizQuestionType.multipleChoice,
          options: options,
          correctAnswer: comp.$3,
          explanation: comp.$5,
          subTopic: comp.$1,
        ),
      );
    }
    return questions;
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
                c.back.trim().toLowerCase() != correctAnswer.toLowerCase(),
          )
          .map((c) => c.back.trim())
          .toSet()
          .toList();

      final options = <String>[correctAnswer];
      for (final distractor in otherBacks) {
        if (options.length >= 4) break;
        options.add(distractor);
      }

      if (options.length < 4) {
        final semanticDistractors = _generateSemanticDistractors(
          correctAnswer: correctAnswer,
          prompt: card.front.trim(),
          topic: card.tags.firstOrNull ?? topic,
          count: 4 - options.length,
        );
        for (final distractor in semanticDistractors) {
          if (options.length >= 4) break;
          if (!options.contains(distractor)) {
            options.add(distractor);
          }
        }
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

  /// Synthesizes semantically grounded, domain-relevant distractors for MCQ choices
  /// when peer flashcards in the set are fewer than 4. Replaces generic placeholder strings.
  List<String> _generateSemanticDistractors({
    required String correctAnswer,
    required String prompt,
    required int count,
    String? topic,
  }) {
    if (count <= 0) return const [];

    final normalizedTopic = (topic ?? '').toLowerCase();
    final normalizedPrompt = prompt.toLowerCase();
    final normalizedAns = correctAnswer.toLowerCase();

    final List<String> domainPool;
    if (normalizedTopic.contains('bio') ||
        normalizedTopic.contains('med') ||
        normalizedTopic.contains('cell') ||
        normalizedPrompt.contains('cell') ||
        normalizedPrompt.contains('organ') ||
        normalizedPrompt.contains('protein')) {
      domainPool = [
        'Passive diffusion regulated by transmembrane concentration gradient',
        'Post-transcriptional modification within the eukaryotic cell nucleus',
        'Enzymatic inhibition via allosteric binding and conformation shift',
        'Membrane repolarization via voltage-gated potassium ion efflux',
        'Signal transduction pathway mediated by cyclic AMP second messengers',
        'Active transport catalyzed by transmembrane ATPase pumps',
        'Phosphorylation cascade initiated by transmembrane receptor kinases',
      ];
    } else if (normalizedTopic.contains('phys') ||
        normalizedTopic.contains('chem') ||
        normalizedTopic.contains('thermo') ||
        normalizedTopic.contains('force') ||
        normalizedPrompt.contains('energy') ||
        normalizedPrompt.contains('law') ||
        normalizedPrompt.contains('motion')) {
      domainPool = [
        'Conservation of angular momentum in an isolated reference frame',
        'Second law of thermodynamics operating in non-equilibrium states',
        'Rate of change of kinetic energy with respect to spatial displacement',
        'Adiabatic expansion occurring strictly without thermal dissipation',
        'Dynamic equilibrium condition governed by Le Chatelier principle',
        'Wave packet dispersion through an anisotropic transmission medium',
        'Induced electromotive force opposing the change in magnetic flux',
      ];
    } else if (normalizedTopic.contains('math') ||
        normalizedTopic.contains('calc') ||
        normalizedTopic.contains('comp') ||
        normalizedTopic.contains('code') ||
        normalizedTopic.contains('data') ||
        normalizedPrompt.contains('function') ||
        normalizedPrompt.contains('matrix') ||
        normalizedPrompt.contains('derivative')) {
      domainPool = [
        'Logarithmic traversal over a balanced binary search tree',
        'Deterministic finite-state automaton transition under input tape',
        'Idempotent transactional mutation with linearizable consistency',
        'Asynchronous non-blocking event loop dispatch with bounded priority queue',
        'Polynomial-time reduction to an equivalent canonical decision problem',
        'Orthogonal projection onto the invariant subspace of the transformation',
        'Uniform convergence of sequence governed by the Cauchy criterion',
      ];
    } else if (normalizedTopic.contains('econ') ||
        normalizedTopic.contains('bus') ||
        normalizedTopic.contains('fin') ||
        normalizedTopic.contains('law') ||
        normalizedPrompt.contains('market') ||
        normalizedPrompt.contains('cost') ||
        normalizedPrompt.contains('price')) {
      domainPool = [
        'Diminishing marginal returns in a competitive market equilibrium',
        'Statutory interpretation adhering strictly to the literal rule',
        'Opportunity cost of capital allocation under budget constraints',
        'Institutional checks and balances within decentralized governance',
        'Inelastic consumer demand curve with monotonic substitution',
        'Counter-cyclical fiscal stimulus dampened by interest rate volatility',
      ];
    } else {
      domainPool = [
        'Inverse relationship where the dependent variable decreases monotonically',
        'Static equilibrium maintained without external energy dissipation',
        'Complementary state governed strictly by initial boundary conditions',
        'Dynamic steady-state observed predominantly in open thermodynamic systems',
        'Differential rate of change evaluated at asymptotic boundary limits',
        'Homogeneous distribution across the entire domain of observation',
      ];
    }

    final pool = domainPool
        .where(
          (d) =>
              d.toLowerCase() != normalizedAns &&
              d.toLowerCase() != normalizedPrompt,
        )
        .toList();

    final rand = Random((prompt.hashCode ^ correctAnswer.hashCode).abs());
    pool.shuffle(rand);

    final selected = <String>[];
    for (final distractor in pool) {
      if (selected.length >= count) break;
      if (!selected.contains(distractor)) {
        selected.add(distractor);
      }
    }

    var idx = 1;
    while (selected.length < count) {
      final fallback =
          'Contrasting condition $idx: inverted boundary state without external perturbation';
      if (!selected.contains(fallback)) {
        selected.add(fallback);
      }
      idx++;
    }

    return selected;
  }
}
