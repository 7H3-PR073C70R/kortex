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
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
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
  }) : _decksRepository = decksRepository,
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

  static const String cbtSubmissionsStorageKey = 'kortex_cbt_test_submissions';

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
            final options =
                (map['options'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final correctIdx = map['correct_index'] as int? ?? 0;
            final correctAns =
                map['correct_answer'] as String? ??
                (correctIdx < options.length
                    ? options[correctIdx]
                    : (options.isNotEmpty ? options.first : ''));

            return QuizQuestionModel(
              id:
                  map['id'] as String? ??
                  'q-${DateTime.now().microsecondsSinceEpoch}',
              prompt: (map['question'] ?? map['prompt'] ?? '') as String,
              type: QuizQuestionType.multipleChoice,
              options: options,
              correctAnswer: correctAns,
              explanation: (map['explanation'] as String?) ?? '',
              subTopic:
                  (map['sub_topic'] as String?) ??
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
    final deckCards =
        cardsResult?.fold(
          (failure) => <FlashcardEntity>[],
          (cards) => cards,
        ) ??
        <FlashcardEntity>[];

    if (deckCards.isEmpty) {
      final isExam =
          deckId.toLowerCase().startsWith('exam') ||
          deckId.toLowerCase().startsWith('cbt_') ||
          (deckTitle != null &&
              (deckTitle.toLowerCase().contains('exam') ||
                  deckTitle.toLowerCase().contains('simulator') ||
                  deckTitle.toLowerCase().contains('mock')));

      if (_effectivePastQuestionsRepo != null) {
        final rawTitle = deckTitle ?? '';
        final cleanSubject = rawTitle
            .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
            .replaceAll(
              RegExp(
                r'\s+(Final Exam|Exam|Mock|Midterm|Simulator|Paper)\b',
                caseSensitive: false,
              ),
              '',
            )
            .trim();

        ExamCategory? matchedCat;
        final combined = '$rawTitle $deckId'.toLowerCase();
        for (final cat in ExamCategory.values) {
          if (combined.contains(cat.name.toLowerCase()) ||
              combined.contains(cat.code.toLowerCase())) {
            matchedCat = cat;
            break;
          }
        }

        try {
          final pqResult = await _effectivePastQuestionsRepo!.getPastQuestions(
            examCategory: matchedCat,
            subject: cleanSubject.isNotEmpty ? cleanSubject : null,
            searchQuery: cleanSubject.isNotEmpty ? cleanSubject : null,
          );
          var pastQuestions = pqResult.fold(
            (f) => <PastQuestionEntity>[],
            (q) => q,
          );

          if (pastQuestions.isEmpty && cleanSubject.isNotEmpty) {
            final fallbackResult =
                await _effectivePastQuestionsRepo!.getPastQuestions(
                  searchQuery: cleanSubject,
                );
            pastQuestions = fallbackResult.fold(
              (f) => <PastQuestionEntity>[],
              (q) => q,
            );
          }

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
      message:
          'Failed to synthesize quiz questions from the provided deck cards.',
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
            final options =
                (map['options'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final correctIdx = map['correct_index'] as int? ?? 0;
            final correctAns =
                map['correct_answer'] as String? ??
                (correctIdx < options.length
                    ? options[correctIdx]
                    : (options.isNotEmpty ? options.first : ''));

            return QuizQuestionModel(
              id:
                  map['id'] as String? ??
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
          message:
              'Unable to locate document "$documentId" for quiz generation.',
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
      message:
          'Failed to generate quiz questions from this document. Please ensure the document contains readable study material.',
    );
  }

  @override
  Future<Either<Failure, QuizResultEntity>> submitQuizAnswers({
    required String quizTitle,
    required List<QuizQuestionEntity> questions,
    required int durationSeconds,
  }) {
    return Future<QuizResultEntity>.sync(() async {
      // Defensive grading: normalize and verify question correctness in case questions
      // arrived from an un-graded exam simulation session
      final gradedQuestions = questions.map((q) {
        if (q.isCorrect) return q;
        if (q.userSelectedAnswer != null &&
            q.userSelectedAnswer!.trim().isNotEmpty) {
          final cleanCorrect = QuizContentSanitizer.cleanOptionText(
            q.correctAnswer,
          ).trim().toLowerCase();
          final cleanSelected = QuizContentSanitizer.cleanOptionText(
            q.userSelectedAnswer!,
          ).trim().toLowerCase();
          if (cleanCorrect == cleanSelected ||
              q.userSelectedAnswer!.trim().toLowerCase() ==
                  q.correctAnswer.trim().toLowerCase()) {
            return q.copyWith(isCorrect: true);
          }
        }
        return q;
      }).toList();

      final total = gradedQuestions.length;
      final correctCount = gradedQuestions.where((q) => q.isCorrect).length;
      final scorePercent = total > 0
          ? ((correctCount / total) * 100).round()
          : 0;
      final completedAt = DateTime.now();

      final topicGroups = <String, List<QuizQuestionEntity>>{};
      for (final q in gradedQuestions) {
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
          final existingJson = storage.getPreference(
            key: cbtSubmissionsStorageKey,
          );
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
            retentionScore: total > 0
                ? (correctCount / total).clamp(0.0, 1.0)
                : 0.0,
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
      final correctAnswer = QuizContentSanitizer.cleanOptionText(card.back);
      if (correctAnswer.isEmpty) continue;
      final cleanPrompt = QuizContentSanitizer.cleanPrompt(card.front);
      final cleanSubTopic = QuizContentSanitizer.cleanSubTopic(
        card.sourceTopic ?? deckTitle,
        defaultTopic: 'Flashcard Concept',
      );
      final explanation =
          QuizContentSanitizer.extractExplanation(card.back) ??
          'Concept: "$cleanPrompt" corresponds to "$correctAnswer".';

      final otherBacks = cards
          .where(
            (c) => c.id != card.id && c.back.trim().isNotEmpty,
          )
          .map((c) => QuizContentSanitizer.cleanOptionText(c.back))
          .where(
            (ans) =>
                ans.isNotEmpty &&
                ans.toLowerCase() != correctAnswer.toLowerCase(),
          )
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
          prompt: cleanPrompt,
          topic: cleanSubTopic,
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
          prompt: cleanPrompt.endsWith('?')
              ? cleanPrompt
              : 'What concept or definition corresponds to: "$cleanPrompt"?',
          type: QuizQuestionType.multipleChoice,
          options: options,
          correctAnswer: correctAnswer,
          explanation: explanation,
          subTopic: cleanSubTopic,
          latexFormula:
              card.frontLatex ??
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
    final cleanTitle = examTitle
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(
          RegExp(
            r'\s+(Final Exam|Exam|Mock|Midterm|Simulator|Paper)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final lower = cleanTitle.toLowerCase();
    final questions = <QuizQuestionModel>[];

    List<(String, String, String, List<String>, String)> bank;

    if (lower.contains('agric') || lower.contains('crop') || lower.contains('soil') || lower.contains('agr')) {
      bank = [
        (
          'Soil Science',
          'Which soil constituent is most critical for maximizing water-holding capacity and cation exchange in agricultural soils?',
          'Humus (decomposed organic matter)',
          [
            'Coarse silica sand',
            'Crushed feldspar granules',
            'Inorganic gypsum crystals',
          ],
          'Humus is colloidal organic material with a very high specific surface area, providing abundant cation exchange sites and vastly improving moisture retention.',
        ),
        (
          'Livestock Pathology',
          'In poultry management, which viral pathogen is characterized by torticollis (twisted neck), respiratory distress, and high mortality?',
          'Newcastle Disease (Avian Paramyxovirus)',
          [
            'Avian Coccidiosis',
            'Fowl Typhoid (Salmonella gallinarum)',
            'Infectious Bursal Disease (Gumboro)',
          ],
          'Newcastle disease is an acute avian paramyxoviral infection producing distinctive nervous signs (torticollis) and enteritis, controlled via Lasota/Komarov vaccinations.',
        ),
        (
          'Crop Agronomy',
          'Which cultural husbandry practice prevents greening and solanine toxic alkaloid formation in root and tuber crops?',
          'Earthing up (mounding loose soil around tuber bases)',
          [
            'Early vegetative vine pruning',
            'Vertical bamboo trellis staking',
            'Application of high-nitrogen foliar sprays',
          ],
          'Earthing up shields developing underground tubers from sunlight exposure, preventing the formation of bitter, toxic solanine alkaloids.',
        ),
        (
          'Animal Physiology',
          'What is the specialized function of the gizzard (ventriculus) in the avian digestive tract?',
          'Mechanical grinding and maceration of whole grains using ingested grit',
          [
            'Enzymatic proteolysis through gastric hydrochloric acid',
            'Bacterial fermentation of coarse cellulose fibers',
            'Primary absorption of volatile fatty acids into hepatic portal circulation',
          ],
          'Because poultry lack dentition, the muscular gizzard utilizes swallowed stones (grit) to mechanically crush tough seed coats and grains.',
        ),
        (
          'Agricultural Economics',
          'In farm enterprise accounting, what does asset depreciation represent?',
          'Annual decline in monetary value of fixed capital assets due to wear, tear, and obsolescence',
          [
            'Net cash proceeds received from harvested crop commodities',
            'Compulsory insurance premium paid for livestock indemnity',
            'Aggregate variable operational expenditures for seasonal labor',
          ],
          'Depreciation quantifies the scheduled diminution of capital value across tractors, implements, and structures across their economic life cycle.',
        ),
        (
          'Parasitology',
          'Which parasite life cycle requires freshwater snails (genus Lymnaea) as intermediate hosts, causing liver rot in ruminants?',
          'Fasciola gigantica (Liver Fluke)',
          [
            'Haemonchus contortus',
            'Taenia saginata',
            'Ascaris lumbricoides',
          ],
          'Fasciola miracidia penetrate amphibious Lymnaea snails to develop into infective cercariae that encyst onto pasture vegetation.',
        ),
        (
          'Irrigation Engineering',
          'Which irrigation system achieves the highest water-use efficiency by delivering moisture directly to plant root zones?',
          'Drip (trickle / micro) irrigation',
          [
            'Continuous furrow basin flooding',
            'Border strip surface gravity spreading',
            'High-pressure rotary impact sprinkler',
          ],
          'Drip irrigation drastically minimizes evaporation and weed germination by conveying calibrated moisture directly to localized rhizosphere zones.',
        ),
        (
          'Integrated Pest Management',
          'In IPM, what defines the Economic Threshold Level (ETL)?',
          'Pest density at which intervention measures must be executed to prevent reaching the Economic Injury Level',
          [
            'Absolute zero pest presence across all farm hectares',
            'The pest density that causes complete defoliation',
            'The legal limit of chemical pesticide residues on market produce',
          ],
          'The Economic Threshold is the critical alert density where the cost of control is justified before damage surpasses economic loss.',
        ),
        (
          'Crop Breeding',
          'In Mendelian genetics, what is the expected phenotypic ratio in the F2 generation of a monohybrid cross with complete dominance?',
          '3 : 1',
          ['9 : 3 : 3 : 1', '1 : 2 : 1', '1 : 1'],
          'A cross between heterozygous parents (Bb x Bb) generates offspring with 3 dominant phenotypes to 1 recessive phenotype.',
        ),
        (
          'Agricultural Extension',
          'Which extension methodology is considered most persuasive when introducing high-yielding hybrid crop cultivars to rural farmers?',
          'Method and Result Demonstration plots',
          [
            'Mass-market radio audio broadcasts',
            'Distribution of technical monochrome flyers',
            'Telephone SMS automated advisory notices',
          ],
          'Farmers adopt innovations most reliably when they observe side-by-side comparative yield results grown directly under local agro-ecological conditions.',
        ),
      ];
    } else if (lower.contains('math') || lower.contains('mth') || lower.contains('calc') || lower.contains('stat')) {
      bank = [
        (
          'Calculus',
          'What is the derivative of f(x) = ln(3x^2 + 5)?',
          '6x / (3x^2 + 5)',
          ['3x / (3x^2 + 5)', '6x(3x^2 + 5)', '1 / (6x)'],
          "By the chain rule, d/dx[ln(u)] = u'/u. Here u = 3x^2 + 5, so u' = 6x, yielding 6x / (3x^2 + 5).",
        ),
        (
          'Algebra',
          'If the roots of the quadratic equation 2x^2 - 8x + k = 0 are real and equal, what is the value of k?',
          '8',
          ['4', '16', '2'],
          'Equal roots occur when the discriminant b^2 - 4ac = 0. (-8)^2 - 4(2)(k) = 64 - 8k = 0 => k = 8.',
        ),
        (
          'Trigonometry',
          'Simplify: sin(2theta) / (1 + cos(2theta)).',
          'tan(theta)',
          ['cot(theta)', 'sin(theta)', 'cos(theta)'],
          'sin(2theta) = 2sin(theta)cos(theta) and 1 + cos(2theta) = 2cos^2(theta). Dividing yields sin(theta)/cos(theta) = tan(theta).',
        ),
        (
          'Probability',
          'Two fair six-sided dice are rolled simultaneously. What is the probability that the sum of the dice equals 7?',
          '1/6',
          ['1/12', '5/36', '7/36'],
          'The favorable pairs are (1,6), (2,5), (3,4), (4,3), (5,2), (6,1) which gives 6 outcomes out of 36 total, so 6/36 = 1/6.',
        ),
        (
          'Coordinate Geometry',
          'What is the equation of the line perpendicular to 2x - 3y = 6 and passing through (0, 4)?',
          '3x + 2y = 8',
          ['2x + 3y = 12', '3x - 2y = -8', '2x - 3y = -12'],
          'The given slope is 2/3. The perpendicular slope is -3/2. y - 4 = (-3/2)(x - 0) => 2y - 8 = -3x => 3x + 2y = 8.',
        ),
      ];
    } else if (lower.contains('bio') || lower.contains('genet') || lower.contains('botany') || lower.contains('zool')) {
      bank = [
        (
          'Cell Biology',
          'During which phase of aerobic cellular respiration is the largest quantity of ATP synthesized via oxidative phosphorylation?',
          'Electron Transport Chain and Chemiosmosis',
          [
            'Glycolysis in the cytosol',
            'Citric Acid (Krebs) Cycle in the mitochondrial matrix',
            'Pyruvate oxidation into Acetyl-CoA',
          ],
          'The electron transport chain utilizes the proton motive force through ATP synthase to generate 28–34 ATP per glucose molecule.',
        ),
        (
          'Genetics',
          'Which molecular mechanism ensures precise semiconservative replication of double-stranded DNA?',
          'Complementary base pairing guided by DNA Polymerase III',
          [
            'Non-specific ribonucleic annealing',
            'Random purine polymerization',
            'Post-transcriptional alternative splicing',
          ],
          'DNA Polymerase synthesizes daughter strands according to Watson-Crick base-pairing (A-T, G-C) using parental templates.',
        ),
        (
          'Ecology',
          'What term describes the symbiotic association between leguminous plant roots and Rhizobium nitrogen-fixing bacteria?',
          'Mutualism',
          ['Commensalism', 'Parasitism', 'Amensalism'],
          'Both species benefit: the plant gains fixed nitrates, while the bacteria receive organic sugars and protection.',
        ),
        (
          'Physiology',
          'Which human endocrine hormone directly stimulates the reabsorption of water in kidney collecting ducts to concentrate urine?',
          'Antidiuretic Hormone (Vasopressin)',
          ['Aldosterone', 'Atrial Natriuretic Peptide', 'Glucagon'],
          'ADH binds to basolateral receptors, prompting aquaporin-2 channel insertion into apical membranes of collecting duct cells.',
        ),
        (
          'Plant Physiology',
          'In C3 photosynthesis, which enzyme catalyzes the initial carbon dioxide fixation with Ribulose-1,5-bisphosphate?',
          'RuBisCO (Ribulose-1,5-bisphosphate carboxylase-oxygenase)',
          ['PEP carboxylase', 'ATP synthase', 'Pyruvate kinase'],
          'RuBisCO is the primary carbon-fixing enzyme in the stroma of chloroplasts during the Calvin-Benson cycle.',
        ),
      ];
    } else if (lower.contains('chem') || lower.contains('chm')) {
      bank = [
        (
          'Physical Chemistry',
          "According to Le Chatelier's principle, what occurs when pressure is increased in the equilibrium system N2(g) + 3H2(g) <=> 2NH3(g)?",
          'Equilibrium shifts forward (to the right) toward ammonia production',
          [
            'Equilibrium shifts backward to produce more reactants',
            'The equilibrium constant Keq increases tenfold',
            'Reaction rate drops to zero permanently',
          ],
          'Increasing pressure shifts equilibrium toward the side with fewer moles of gas (from 4 moles of reactants to 2 moles of product).',
        ),
        (
          'Organic Chemistry',
          'Which functional group is formed by the acid-catalyzed reaction between a carboxylic acid and a primary alcohol?',
          'Ester',
          ['Ether', 'Aldehyde', 'Ketone'],
          'Fischer esterification couples an organic carboxylic acid with an alcohol to yield an ester and water.',
        ),
        (
          'Electrochemistry',
          'In an electrochemical galvanic cell, what chemical process occurs consistently at the anode?',
          'Oxidation (loss of electrons)',
          [
            'Reduction (gain of electrons)',
            'Precipitation of insoluble salts',
            'Protonation of electrolyte solvent',
          ],
          'By definition across all electrochemical cells, oxidation consistently takes place at the anode (An Ox).',
        ),
        (
          'Inorganic Chemistry',
          'What happens to the first ionization energy of elements as you move from left to right across a period in the periodic table?',
          'It generally increases due to increasing effective nuclear charge (Zeff)',
          [
            'It decreases monotonically because of atomic radii expansion',
            'It remains identical across all main group elements',
            'It drops to zero for transition metal blocks',
          ],
          'Across a period, nuclear charge increases with minimal shielding change, drawing valence electrons tighter and requiring more energy to remove.',
        ),
        (
          'Stoichiometry',
          'What volume of carbon dioxide at STP (standard temperature and pressure) is generated by the complete thermal decomposition of 100g of pure CaCO3 (Molar Mass = 100 g/mol)?',
          '22.4 dm^3 (liters)',
          ['11.2 dm^3', '44.8 dm^3', '2.24 dm^3'],
          '100g of CaCO3 is 1 mol. The reaction CaCO3 -> CaO + CO2 produces 1 mol of CO2, occupying 22.4 dm^3 at STP.',
        ),
      ];
    } else if (lower.contains('phys') || lower.contains('phy')) {
      bank = [
        (
          'Mechanics',
          'A stone is dropped from rest from the top of a 80m cliff. Assuming g = 10 m/s^2 and neglecting air resistance, what is its velocity just before impact?',
          '40 m/s',
          ['20 m/s', '80 m/s', '16 m/s'],
          'v^2 = u^2 + 2gs => v^2 = 0 + 2(10)(80) = 1600 => v = 40 m/s.',
        ),
        (
          'Electricity',
          'Three resistors of 6 ohms, 3 ohms, and 2 ohms are connected in parallel. What is the equivalent resistance of this network?',
          '1 ohm',
          ['11 ohms', '3 ohms', '0.5 ohms'],
          '1/Req = 1/6 + 1/3 + 1/2 = 1/6 + 2/6 + 3/6 = 6/6 = 1 => Req = 1 ohm.',
        ),
        (
          'Thermodynamics',
          'Which thermodynamic law states that absolute zero temperature cannot be attained in a finite number of physical processes?',
          'Third Law of Thermodynamics',
          [
            'First Law of Thermodynamics',
            'Second Law of Thermodynamics',
            'Zeroth Law of Thermodynamics',
          ],
          'The third law specifies that the entropy of a perfect crystal approaches zero as temperature reaches absolute zero, making it asymptotically unreachable.',
        ),
        (
          'Optics',
          'What phenomenon accounts for the propagation of light signals through flexible optical fiber cables without substantial signal leakage?',
          'Total Internal Reflection',
          ['Diffraction', 'Polarization', 'Interference'],
          'When light travels from dense core to less dense cladding at an angle exceeding the critical angle, total internal reflection occurs.',
        ),
        (
          'Modern Physics',
          "In Einstein's photoelectric effect equation, what does the threshold frequency (f0) represent?",
          'Minimum frequency of incident radiation required to liberate photoelectrons from a metal surface',
          [
            'The frequency at which all emitted electrons achieve speed of light',
            'The frequency where light undergoes destructive interference',
            'The frequency producing maximum photon wavelength',
          ],
          'Photons with energy below the work function hf0 cannot eject electrons regardless of beam intensity.',
        ),
      ];
    } else if (lower.contains('econ') || lower.contains('commerc')) {
      bank = [
        (
          'Microeconomics',
          'When the price elasticity of demand for a commodity is perfectly inelastic (|Ed| = 0), what does the demand curve look like?',
          'A vertical straight line parallel to the price axis',
          [
            'A horizontal straight line parallel to the quantity axis',
            'A rectangular hyperbola',
            'An upward-sloping linear curve',
          ],
          'Perfect inelasticty indicates quantity demanded remains invariant regardless of price fluctuations.',
        ),
        (
          'Macroeconomics',
          'Which monetary policy instrument would a central bank deploy to combat severe demand-pull inflation?',
          'Raise the monetary policy benchmark interest rate (cash reserve ratio)',
          [
            'Lower the policy rate to encourage credit expansion',
            'Purchase commercial treasury bills in open market operations',
            'Increase direct budget deficit government expenditure',
          ],
          'Increasing benchmark interest rates raises the cost of borrowing, cooling money supply and dampening excess aggregate demand.',
        ),
        (
          'Market Structures',
          'Which characteristic distinguishes a monopolistically competitive market from a perfectly competitive market?',
          'Product differentiation through branding, quality, or packaging',
          [
            'Barriers preventing any new firm from entering the industry',
            'A single seller dominating all industry output',
            'Perfect price discrimination for individual consumers',
          ],
          'Monopolistic competition involves numerous sellers offering close but differentiated substitutes.',
        ),
        (
          'National Accounting',
          'What is the formula to calculate Gross Domestic Product (GDP) using the expenditure approach?',
          'GDP = C + I + G + (X - M)',
          [
            'GDP = C + S + T',
            'GDP = Wages + Rent + Interest + Profit',
            'GDP = Total Capital Output - Foreign Debt',
          ],
          'Expenditure GDP measures consumption (C), gross private investment (I), government spending (G), and net exports (X - M).',
        ),
      ];
    } else {
      // General dynamic academic competencies tailored to course subject
      bank = [
        (
          'Theoretical Foundations',
          'In advanced $cleanTitle study, which conceptual premise provides the baseline framework for modern analysis?',
          'Rigorous empirical validation grounded in peer-reviewed first principles',
          [
            'Subjective anecdotal conjecture without verifiable controls',
            'Arbitrary historical conventions devoid of systemic evaluation',
            'Uncalibrated intuition disregarding established analytical models',
          ],
          'Academic scholarship in $cleanTitle requires systematic empirical proof, falsifiable hypotheses, and methodological rigor.',
        ),
        (
          'Systematic Methodology',
          'When diagnosing complex multifaceted problem sets in $cleanTitle, what is the standard recommended first step?',
          'Deconstruct given criteria into verified parameters and establish boundary limits',
          [
            'Speculate immediate solutions without reviewing constraints',
            'Bypass diagnostic verification in favor of generic approximations',
            'Discard anomalous variables that challenge premature assumptions',
          ],
          'Structured parameter decomposition isolates independent variables and prevents cognitive bias in high-level assessments.',
        ),
        (
          'Quality Verification',
          'How are conclusions rigorously evaluated against error margins in standardized $cleanTitle examinations?',
          'Multi-angle cross-verification, dimensional consistency checks, and comparative tolerance benchmarks',
          [
            'Accepting initial calculations without redundant sanity validation',
            'Altering outputs at random without methodological rationale',
            'Assuming standard textbook constants are variable based on preference',
          ],
          'Rigorous cross-checking detects dimensional errors, arithmetic drift, and distractor traps common to formal academic testing.',
        ),
        (
          'Applied Synthesis',
          'What distinguishes professional mastery from novice performance when applying $cleanTitle to real-world scenarios?',
          'Synthesizing disparate principles into coherent, scalable, and reproducible solutions under constraints',
          [
            'Fragmented recall of isolated terminology without integration',
            'Over-reliance on rote formula substitution without comprehension',
            'Ignoring real-world tolerances and environmental variance',
          ],
          'Excellence in $cleanTitle is characterized by contextual synthesis and the ability to adapt core principles to novel problems.',
        ),
        (
          'Analytical Optimization',
          'When evaluating competing solutions in $cleanTitle, which metric provides the most robust optimization standard?',
          'Maximizing efficacy and accuracy while minimizing systemic resource and cognitive overhead',
          [
            'Selecting arbitrary solutions based solely on historical familiarity',
            'Prioritizing unnecessary complexity to convey superficial depth',
            'Disregarding error propagation across sequential stages',
          ],
          "Optimal domain execution adheres to parsimony (Occam's razor): effective, robust solutions with minimal systemic friction.",
        ),
      ];
    }

    final rand = Random(examId.hashCode ^ cleanTitle.hashCode);
    final selectedIndices = <int>[];
    for (var i = 0; i < count; i++) {
      final index = i < bank.length ? i : rand.nextInt(bank.length);
      selectedIndices.add(index);
    }

    for (var i = 0; i < count; i++) {
      final item = bank[selectedIndices[i] % bank.length];
      final rawOptions = [item.$3, ...item.$4];
      final shuffledOptions = List<String>.from(rawOptions)..shuffle(Random(i * 31 + rand.nextInt(100)));

      questions.add(
        QuizQuestionModel(
          id: 'sim-${examId.replaceAll(RegExp('[^a-zA-Z0-9]'), '_')}-$i',
          prompt: i < bank.length
              ? item.$2
              : '[$cleanTitle Q${i + 1}] ${item.$2}',
          type: QuizQuestionType.multipleChoice,
          options: shuffledOptions,
          correctAnswer: item.$3,
          explanation: item.$5,
          subTopic: item.$1,
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
      final correctAnswer = QuizContentSanitizer.cleanOptionText(card.back);
      if (correctAnswer.isEmpty) continue;
      final cleanPrompt = QuizContentSanitizer.cleanPrompt(card.front);
      final cleanSubTopic = QuizContentSanitizer.cleanSubTopic(
        card.tags.firstOrNull ?? topic,
        defaultTopic: 'AI Concept Analysis',
      );

      final otherBacks = cards
          .where(
            (c) => c.id != card.id && c.back.trim().isNotEmpty,
          )
          .map((c) => QuizContentSanitizer.cleanOptionText(c.back))
          .where(
            (ans) =>
                ans.isNotEmpty &&
                ans.toLowerCase() != correctAnswer.toLowerCase(),
          )
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
          prompt: cleanPrompt,
          topic: cleanSubTopic,
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
          prompt: cleanPrompt.endsWith('?')
              ? cleanPrompt
              : 'Which explanation correctly describes: "$cleanPrompt"?',
          type: QuizQuestionType.multipleChoice,
          options: options,
          correctAnswer: correctAnswer,
          explanation: card.explanation.isNotEmpty
              ? card.explanation
              : 'Verified AI synthesis for "$cleanPrompt".',
          subTopic: cleanSubTopic,
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
