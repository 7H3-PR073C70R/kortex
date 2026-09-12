import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/performance_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/millionaire_tiering_engine.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/generate_quiz_from_deck_use_case.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/submit_quiz_answers_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';

class QuizSessionCubit extends Cubit<QuizSessionState> {
  QuizSessionCubit({
    required GenerateQuizFromDeckUseCase generateQuizUseCase,
    required SubmitQuizAnswersUseCase submitQuizUseCase,
    DecksRepository? decksRepository,
    CardSyncQueue? cardSyncQueue,
    MillionaireTieringEngine? tieringEngine,
  }) : _generateQuizUseCase = generateQuizUseCase,
       _submitQuizUseCase = submitQuizUseCase,
       _decksRepository = decksRepository ??
           (locator.isRegistered<DecksRepository>()
               ? locator<DecksRepository>()
               : null),
       _cardSyncQueue = cardSyncQueue ??
           (locator.isRegistered<CardSyncQueue>()
               ? locator<CardSyncQueue>()
               : null),
       _tieringEngine = tieringEngine ?? const MillionaireTieringEngine(),
       super(const QuizSessionState());

  final GenerateQuizFromDeckUseCase _generateQuizUseCase;
  final SubmitQuizAnswersUseCase _submitQuizUseCase;
  final DecksRepository? _decksRepository;
  final CardSyncQueue? _cardSyncQueue;
  final MillionaireTieringEngine _tieringEngine;
  List<QuizQuestionEntity> _reserveQuestions = [];
  Timer? _timer;

  /// Starts a new quiz session from a deck.
  Future<void> startQuizFromDeck({
    required String deckId,
    String? deckTitle,
    int questionCount = 10,
    int? durationMinutes,
    AssessmentMode assessmentMode = AssessmentMode.discoveryMode,
  }) async {
    _timer?.cancel();
    emit(
      state.copyWith(
        status: QuizSessionStatus.loading,
        quizTitle: deckTitle ?? 'Practice Quiz',
        durationMinutes: assessmentMode == AssessmentMode.millionaireMode
            ? null
            : durationMinutes,
        flaggedQuestionIds: const {},
        assessmentMode: assessmentMode,
        millionaireScope: assessmentMode == AssessmentMode.millionaireMode
            ? MillionaireScope.courseTied
            : null,
      ),
    );

    final result = await _generateQuizUseCase(
      deckId: deckId,
      deckTitle: deckTitle,
      questionCount: assessmentMode == AssessmentMode.millionaireMode ? 15 : questionCount,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: QuizSessionStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (questions) {
        final sanitized = _sanitizeQuestions(questions);
        final finalQuestions = assessmentMode == AssessmentMode.millionaireMode
            ? _tieringEngine.tierQuestions(questions: sanitized)
            : sanitized;
        if (assessmentMode == AssessmentMode.millionaireMode) {
          final tieredIds = finalQuestions.map((q) => q.id).toSet();
          _reserveQuestions = sanitized.where((q) => !tieredIds.contains(q.id)).toList();
        }
        emit(
          state.copyWith(
            status: QuizSessionStatus.inProgress,
            questions: finalQuestions,
            currentIndex: 0,
            elapsedSeconds: 0,
            currentTier: 1,
            bankedTier: 0,
            speedBonusXp: 0,
            questionStartTimeSeconds: 0,
            hasSecondChance: true,
            isSecondChanceActive: false,
            isWalkedAway: false,
            millionaireScope: assessmentMode == AssessmentMode.millionaireMode
                ? MillionaireScope.courseTied
                : null,
            availableLifelines: const {
              LifelineType.fiftyFifty: true,
              LifelineType.aiClue: true,
              LifelineType.askAudience: true,
              LifelineType.skipSwap: true,
            },
            eliminatedOptionIndices: const {},
          ),
        );
        _startTimer();
      },
    );
  }

  /// Starts a live quiz/CBT exam session directly from past questions.
  void startQuizFromPastQuestions({
    required String title,
    required List<QuizQuestionEntity> questions,
    int? durationMinutes,
    AssessmentMode assessmentMode = AssessmentMode.discoveryMode,
    MillionaireScope? millionaireScope,
  }) {
    _timer?.cancel();
    final sanitized = _sanitizeQuestions(questions);
    final finalQuestions = assessmentMode == AssessmentMode.millionaireMode
        ? sanitized.take(12).toList()
        : sanitized;
    if (assessmentMode == AssessmentMode.millionaireMode && sanitized.length > finalQuestions.length) {
      final tieredIds = finalQuestions.map((q) => q.id).toSet();
      _reserveQuestions = sanitized.where((q) => !tieredIds.contains(q.id)).toList();
    }
    emit(
      state.copyWith(
        status: QuizSessionStatus.inProgress,
        quizTitle: title,
        questions: finalQuestions,
        currentIndex: 0,
        elapsedSeconds: 0,
        durationMinutes: assessmentMode == AssessmentMode.millionaireMode ? null : durationMinutes,
        flaggedQuestionIds: const {},
        assessmentMode: assessmentMode,
        millionaireScope: millionaireScope,
        currentTier: 1,
        bankedTier: 0,
        speedBonusXp: 0,
        questionStartTimeSeconds: 0,
        hasSecondChance: true,
        isSecondChanceActive: false,
        isWalkedAway: false,
        isSoftFailed: false,
        availableLifelines: const {
          LifelineType.fiftyFifty: true,
          LifelineType.aiClue: true,
          LifelineType.askAudience: true,
          LifelineType.skipSwap: true,
        },
        eliminatedOptionIndices: const {},
      ),
    );
    _startTimer();
  }

  /// Starts a gamified "Who Wants to Be a Millionaire" ascent quiz mode.
  void startMillionaireQuiz({
    required String title,
    required List<QuizQuestionEntity> questions,
    MillionaireScope scope = MillionaireScope.courseTied,
  }) {
    final sanitized = _sanitizeQuestions(questions);
    final tiered = _tieringEngine.tierQuestions(questions: sanitized);
    final tieredIds = tiered.map((q) => q.id).toSet();
    _reserveQuestions = sanitized.where((q) => !tieredIds.contains(q.id)).toList();
    startQuizFromPastQuestions(
      title: title,
      questions: tiered,
      assessmentMode: AssessmentMode.millionaireMode,
      millionaireScope: scope,
    );
  }

  /// Starts the Global Free-Play "Daily Dopamine Arcade" cross-subject climb.
  /// Pulls questions across all user decks and curates a 12-tier ascent.
  Future<void> startMillionaireArcade() async {
    _timer?.cancel();
    emit(
      state.copyWith(
        status: QuizSessionStatus.loading,
        quizTitle: 'Daily Dopamine Arcade',
        assessmentMode: AssessmentMode.millionaireMode,
        millionaireScope: MillionaireScope.globalArcade,
      ),
    );

    try {
      final decksResult = await _decksRepository?.getUserDecks();
      final decks = decksResult?.fold((l) => null, (r) => r) ?? [];

      final candidateCards = <FlashcardEntity>[];
      for (final deck in decks.take(5)) {
        final cardsResult = await _decksRepository?.getDeckCards(deck.id);
        final cards = cardsResult?.fold((l) => null, (r) => r) ?? [];
        candidateCards.addAll(cards);
      }

      if (candidateCards.isNotEmpty) {
        candidateCards.shuffle();
        final questions = <QuizQuestionEntity>[];
        for (var i = 0; i < candidateCards.length; i++) {
          final card = candidateCards[i];
          final cleanAnswer = QuizContentSanitizer.cleanOptionText(card.back);
          if (cleanAnswer.isEmpty) continue;
          final explanation = QuizContentSanitizer.extractExplanation(card.back) ??
              'Correct answer: $cleanAnswer';
          final cleanPrompt = QuizContentSanitizer.cleanPrompt(card.front);
          final cleanSubTopic = QuizContentSanitizer.cleanSubTopic(
            card.sourceTopic,
          );

          final otherAnswers = candidateCards
              .where((c) => c.id != card.id && c.back.trim().isNotEmpty)
              .map((c) => QuizContentSanitizer.cleanOptionText(c.back))
              .where((ans) =>
                  ans.isNotEmpty &&
                  ans.toLowerCase() != cleanAnswer.toLowerCase())
              .toSet()
              .toList()
            ..shuffle();

          final options = <String>[cleanAnswer, ...otherAnswers.take(3)]
            ..shuffle();

          if (options.length >= 2) {
            questions.add(
              QuizQuestionEntity(
                id: 'arcade_${card.id}_$i',
                prompt: cleanPrompt.endsWith('?')
                    ? cleanPrompt
                    : 'What matches the definition: "$cleanPrompt"?',
                type: QuizQuestionType.multipleChoice,
                options: options,
                correctAnswer: cleanAnswer,
                explanation: explanation,
                subTopic: cleanSubTopic,
              ),
            );
          }
          if (questions.length >= 18) break;
        }

        if (questions.length >= 6) {
          final tiered = _tieringEngine.tierQuestions(
            questions: questions,
          );
          startMillionaireQuiz(
            title: 'Daily Dopamine Arcade',
            questions: tiered,
            scope: MillionaireScope.globalArcade,
          );
          return;
        }
      }
    } on Object catch (_) {}

    final fallback = _generateFallbackArcadeQuestions();
    startMillionaireQuiz(
      title: 'Daily Dopamine Arcade',
      questions: fallback,
      scope: MillionaireScope.globalArcade,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == QuizSessionStatus.inProgress ||
          state.status == QuizSessionStatus.questionAnswered) {
        final newElapsed = state.elapsedSeconds + 1;
        emit(state.copyWith(elapsedSeconds: newElapsed));

        // Auto-submit when countdown expires in timed CBT exam
        if (state.durationMinutes != null &&
            newElapsed >= (state.durationMinutes! * 60)) {
          _timer?.cancel();
          unawaited(submitQuiz());
        }
      }
    });
  }

  /// Toggles the flagged status of the current question.
  void toggleFlagCurrentQuestion() {
    final current = state.currentQuestion;
    if (current == null) return;
    toggleFlagQuestion(current.id);
  }

  /// Toggles the flagged status of a specific question for candidate review.
  void toggleFlagQuestion(String questionId) {
    final updatedFlags = Set<String>.from(state.flaggedQuestionIds);
    if (updatedFlags.contains(questionId)) {
      updatedFlags.remove(questionId);
    } else {
      updatedFlags.add(questionId);
    }
    emit(state.copyWith(flaggedQuestionIds: updatedFlags));
  }

  /// Sets the assessment mode (discovery / practice vs strict exam simulation).
  void setAssessmentMode(AssessmentMode mode) {
    emit(state.copyWith(assessmentMode: mode));
  }

  /// Reveals a pedagogical Socratic hint for the active question without penalizing score.
  void revealHint() {
    if (!state.isHintRevealed) {
      emit(
        state.copyWith(
          isHintRevealed: true,
          hintsUsedCount: state.hintsUsedCount + 1,
        ),
      );
    }
  }

  /// Uses an ADHD-friendly lifeline in Millionaire mode.
  void useLifeline(LifelineType lifeline) {
    if (state.assessmentMode != AssessmentMode.millionaireMode) return;
    if (!state.isLifelineAvailable(lifeline)) return;
    if (state.currentQuestion == null) return;

    final updatedLifelines = Map<LifelineType, bool>.from(state.availableLifelines);
    updatedLifelines[lifeline] = false;

    AppFeedback.lifeline();

    switch (lifeline) {
      case LifelineType.fiftyFifty:
        final current = state.currentQuestion!;
        final cleanCorrect = QuizContentSanitizer.cleanOptionText(current.correctAnswer).toLowerCase();
        final correctIndex = current.options.indexWhere(
          (opt) => QuizContentSanitizer.cleanOptionText(opt).toLowerCase() == cleanCorrect,
        );

        final incorrectIndices = <int>[];
        for (var i = 0; i < current.options.length; i++) {
          if (i != correctIndex) {
            incorrectIndices.add(i);
          }
        }
        incorrectIndices.shuffle();
        final eliminated = incorrectIndices.take(2).toSet();

        emit(
          state.copyWith(
            availableLifelines: updatedLifelines,
            eliminatedOptionIndices: eliminated,
          ),
        );

      case LifelineType.aiClue:
        final current = state.currentQuestion!;
        final clue = current.explanation.isNotEmpty
            ? current.explanation
            : 'Focus on the foundational principle of "${current.prompt}". Eliminate options with extreme absolutes.';
        emit(
          state.copyWith(
            availableLifelines: updatedLifelines,
            activeClueText: clue,
            hintsUsedCount: state.hintsUsedCount + 1,
          ),
        );

      case LifelineType.askAudience:
        final current = state.currentQuestion!;
        final cleanCorrect = QuizContentSanitizer.cleanOptionText(current.correctAnswer).toLowerCase();
        final correctIndex = current.options.indexWhere(
          (opt) => QuizContentSanitizer.cleanOptionText(opt).toLowerCase() == cleanCorrect,
        );

        final letters = ['A', 'B', 'C', 'D'];
        final distribution = <String, int>{};
        final optCount = current.options.length.clamp(2, 4);

        // Confidence adjusts realistically based on tier (easier tiers have stronger consensus)
        final correctPct = (82 - (state.currentTier * 2)).clamp(56, 85);
        var remaining = 100 - correctPct;

        final rand = math.Random();
        final incorrectShares = <int>[];
        for (var i = 0; i < optCount - 1; i++) {
          if (i == optCount - 2) {
            incorrectShares.add(remaining);
          } else {
            final share = rand.nextInt((remaining / 2).ceil() + 1);
            incorrectShares.add(share);
            remaining -= share;
          }
        }
        incorrectShares.shuffle();

        var incorrectIdx = 0;
        for (var i = 0; i < optCount; i++) {
          final letter = i < letters.length ? letters[i] : 'Opt ${i + 1}';
          if (i == correctIndex) {
            distribution[letter] = correctPct;
          } else {
            distribution[letter] = incorrectShares[incorrectIdx++];
          }
        }

        emit(
          state.copyWith(
            availableLifelines: updatedLifelines,
            audienceDistribution: distribution,
          ),
        );

      case LifelineType.skipSwap:
        final current = state.currentQuestion;
        if (current == null) return;
        final QuizQuestionEntity replacement;
        if (_reserveQuestions.isNotEmpty) {
          replacement = _reserveQuestions.removeAt(0);
        } else {
          replacement = _generateReplacementQuestion(current, state.currentTier);
        }

        final updatedQuestions = List<QuizQuestionEntity>.from(state.questions);
        updatedQuestions[state.currentIndex] = replacement;

        emit(
          state.copyWith(
            availableLifelines: updatedLifelines,
            questions: updatedQuestions,
            eliminatedOptionIndices: const {},
            clearActiveClue: true,
            clearAudienceDistribution: true,
            isHintRevealed: false,
            questionStartTimeSeconds: state.elapsedSeconds,
            status: QuizSessionStatus.inProgress,
          ),
        );
    }
  }

  /// Generates a curriculum-aligned replacement question when skipSwap lifeline is invoked.
  QuizQuestionEntity _generateReplacementQuestion(QuizQuestionEntity current, int tier) {
    final subTopic = current.subTopic.trim().isNotEmpty ? current.subTopic : 'Core Curriculum';
    final cleanPrompt = current.prompt.replaceAll('?', '').split('\n').first.trim();
    final subjectFocus = cleanPrompt.length > 35 ? '${cleanPrompt.substring(0, 32)}...' : cleanPrompt;

    return QuizQuestionEntity(
      id: 'swap_${current.id}_${DateTime.now().millisecondsSinceEpoch}',
      prompt: 'Alternative Tier $tier Challenge ($subTopic): Which foundational principle governs $subjectFocus?',
      type: QuizQuestionType.multipleChoice,
      options: const [
        'Active Recall & Spaced Retrieval',
        'Direct Structural Synthesis',
        'Iterative Heuristic Verification',
        'Contextual Variable Isolation',
      ],
      correctAnswer: 'Active Recall & Spaced Retrieval',
      explanation: 'In $subTopic, active recall and spaced retrieval establish durable neural retention.',
      subTopic: subTopic,
    );
  }

  /// Walks away from the Millionaire ascent, securing current banked or tier XP.
  Future<void> walkAwayAndBank() async {
    if (state.assessmentMode != AssessmentMode.millionaireMode) return;
    AppFeedback.celebration();
    emit(state.copyWith(isWalkedAway: true));
    await submitQuiz();
  }

  /// Consumes second chance revival after an incorrect answer in Millionaire mode.
  void useSecondChance() {
    if (!state.hasSecondChance || !state.isSecondChanceActive) return;
    AppFeedback.light();

    final current = state.currentQuestion;
    var updatedList = state.questions;
    final updatedEliminated = Set<int>.from(state.eliminatedOptionIndices);

    if (current != null) {
      if (current.userSelectedAnswer != null) {
        final wrongIdx = current.options.indexOf(current.userSelectedAnswer!);
        if (wrongIdx != -1) {
          updatedEliminated.add(wrongIdx);
        }
      }
      final resetQuestion = current.copyWith(
        isAnswered: false,
        isCorrect: false,
        clearUserSelectedAnswer: true,
      );
      final listCopy = List<QuizQuestionEntity>.from(state.questions);
      listCopy[state.currentIndex] = resetQuestion;
      updatedList = listCopy;
    }

    emit(
      state.copyWith(
        hasSecondChance: false,
        isSecondChanceActive: false,
        status: QuizSessionStatus.inProgress,
        questions: updatedList,
        eliminatedOptionIndices: updatedEliminated,
      ),
    );
  }

  /// Jumps directly to any question by index in the CBT question palette.
  void jumpToQuestion(int index) {
    if (index < 0 || index >= state.questions.length) return;
    if (state.assessmentMode == AssessmentMode.millionaireMode && state.isSoftFailed) {
      return;
    }
    final targetQuestion = state.questions[index];
    final tier = index + 1;

    emit(
      state.copyWith(
        currentIndex: index,
        currentTier: tier,
        isHintRevealed: false,
        clearActiveClue: true,
        clearAudienceDistribution: true,
        eliminatedOptionIndices: const {},
        questionStartTimeSeconds: state.elapsedSeconds,
        status: state.status == QuizSessionStatus.loading ||
                state.status == QuizSessionStatus.completed
            ? state.status
            : (targetQuestion.isAnswered
                ? QuizSessionStatus.questionAnswered
                : QuizSessionStatus.inProgress),
      ),
    );
  }

  /// Navigates to the previous question.
  void previousQuestion() {
    if (state.canGoPrevious) {
      jumpToQuestion(state.currentIndex - 1);
    }
  }

  /// Selects an answer option for the current question.
  void selectOption(String option) {
    if (state.currentQuestion == null) return;
    if (state.currentQuestion!.isAnswered) return;

    final current = state.currentQuestion!;
    final cleanCorrect = QuizContentSanitizer.cleanOptionText(current.correctAnswer).toLowerCase();
    final cleanSelected = QuizContentSanitizer.cleanOptionText(option).toLowerCase();
    final isCorrect = cleanCorrect == cleanSelected;

    final updatedQuestion = current.copyWith(
      userSelectedAnswer: option,
      isAnswered: true,
      isCorrect: isCorrect,
    );

    final updatedList = List<QuizQuestionEntity>.from(state.questions);
    updatedList[state.currentIndex] = updatedQuestion;

    if (state.assessmentMode == AssessmentMode.millionaireMode) {
      if (isCorrect) {
        AppFeedback.celebration();
        final timeTaken = state.elapsedSeconds - state.questionStartTimeSeconds;
        final speedBonus = (timeTaken <= 10 && timeTaken >= 0) ? 50 : 0;
        final isCheckpoint = QuizSessionState.safeCheckpointTiers.contains(state.currentTier);
        final newBanked = isCheckpoint && state.currentTier > state.bankedTier
            ? state.currentTier
            : state.bankedTier;

        emit(
          state.copyWith(
            status: QuizSessionStatus.questionAnswered,
            questions: updatedList,
            bankedTier: newBanked,
            speedBonusXp: state.speedBonusXp + speedBonus,
          ),
        );

        if (state.isLastQuestion) {
          unawaited(submitQuiz());
        }
      } else {
        AppFeedback.incorrect();
        _flagMissedCardToFsrs(current.id);

        if (state.hasSecondChance) {
          emit(
            state.copyWith(
              status: QuizSessionStatus.questionAnswered,
              questions: updatedList,
              isSecondChanceActive: true,
            ),
          );
        } else {
          // Soft-fail: drops back to safe banked checkpoint without resetting to zero!
          emit(
            state.copyWith(
              status: QuizSessionStatus.questionAnswered,
              questions: updatedList,
              currentTier: state.bankedTier,
              isSoftFailed: true,
            ),
          );
        }
      }
      return;
    }

    if (state.assessmentMode == AssessmentMode.discoveryMode) {
      if (isCorrect) {
        AppFeedback.correct();
      } else {
        AppFeedback.incorrect();
      }
    } else {
      AppFeedback.selection();
    }

    emit(
      state.copyWith(
        status: QuizSessionStatus.questionAnswered,
        questions: updatedList,
      ),
    );
  }

  /// Advances to the next question.
  void nextQuestion() {
    if (state.isLastQuestion) return;
    if (state.assessmentMode == AssessmentMode.millionaireMode && state.isSoftFailed) {
      return;
    }

    jumpToQuestion(state.currentIndex + 1);
  }

  /// Submits all completed answers and computes result with topic weaknesses.
  Future<void> submitQuiz() async {
    _timer?.cancel();
    emit(state.copyWith(status: QuizSessionStatus.loading));

    final result = await _submitQuizUseCase(
      quizTitle: state.quizTitle,
      questions: state.questions,
      durationSeconds: state.elapsedSeconds,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: QuizSessionStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (quizResult) {
        // Telemetry: Mock exam score submission trace & Crashlytics metrics
        try {
          final crashlytics = locator<CrashlyticsService>();
          unawaited(
            crashlytics.log(
              'Mock exam / Quiz submitted: "${quizResult.quizTitle}", '
              'score=${quizResult.correctAnswers}/${quizResult.totalQuestions}, '
              'percentage=${quizResult.scorePercent}%',
            ),
          );
          unawaited(
            crashlytics.setCustomKey(
              'last_quiz_title',
              quizResult.quizTitle,
            ),
          );
          unawaited(
            crashlytics.setCustomKey(
              'last_quiz_score',
              quizResult.scorePercent,
            ),
          );

          final performance = locator<PerformanceService>();
          final trace = performance.newTrace('mock_exam_submission')
            ..putAttribute('quiz_title', quizResult.quizTitle)
            ..setMetric('total_questions', quizResult.totalQuestions)
            ..setMetric('correct_answers', quizResult.correctAnswers)
            ..setMetric('duration_seconds', quizResult.durationSeconds);
          unawaited(trace.start().then((_) => trace.stop()));
        } on Object catch (_) {}

        // Live UI state refresh for Auth streak and Dashboard
        try {
          locator<AuthBloc>().add(const AuthStreakIncremented());
        } on Object catch (_) {}
        try {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        } on Object catch (_) {}

        emit(
          state.copyWith(
            status: QuizSessionStatus.completed,
            result: quizResult,
          ),
        );
      },
    );
  }

  void _flagMissedCardToFsrs(String cardId) {
    final queue = _cardSyncQueue;
    if (queue == null) return;
    try {
      var resolvedCardId = cardId;
      if (cardId.startsWith('arcade_')) {
        final parts = cardId.split('_');
        if (parts.length >= 3) {
          resolvedCardId = parts.sublist(1, parts.length - 1).join('_');
        }
      }
      final now = DateTime.now().toUtc();
      final log = FsrsReviewLog(
        id: UuidUtils.generate(),
        transactionUuid: UuidUtils.generate(),
        cardId: resolvedCardId,
        rating: FsrsRating.again,
        stability: 0,
        difficulty: 0,
        elapsedDays: 0,
        scheduledDays: 1,
        reviewedAtUtc: now,
        reviewedAtEpoch: now.millisecondsSinceEpoch,
        state: FsrsCardState.learning,
      );
      unawaited(queue.enqueueReview(log));
    } on Object catch (_) {}
  }

  List<QuizQuestionEntity> _generateFallbackArcadeQuestions() {
    return const [
      QuizQuestionEntity(
        id: 'arcade_fallback_1',
        prompt: 'What learning technique involves reviewing information at expanding intervals?',
        type: QuizQuestionType.multipleChoice,
        options: ['Spaced Repetition', 'Cramming', 'Passive Reading', 'Highlighting'],
        correctAnswer: 'Spaced Repetition',
        explanation: 'Spaced repetition exploits the psychological spacing effect to maximize long-term memory retention.',
        subTopic: 'Learning Science',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_2',
        prompt: 'Which neurotransmitter plays the central role in motivation, reward prediction, and ADHD focus?',
        type: QuizQuestionType.multipleChoice,
        options: ['Dopamine', 'Serotonin', 'Melatonin', 'GABA'],
        correctAnswer: 'Dopamine',
        explanation: 'Dopamine pathways regulate executive attention, reward circuits, and goal-directed behavior.',
        subTopic: 'Neuroscience',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_3',
        prompt: 'What cognitive strategy breaks large, intimidating volumes of information into smaller units?',
        type: QuizQuestionType.multipleChoice,
        options: ['Chunking', 'Shadowing', 'Priming', 'Slicing'],
        correctAnswer: 'Chunking',
        explanation: 'Chunking reduces working memory overload by grouping individual bits into cohesive semantic units.',
        subTopic: 'Cognitive Psychology',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_4',
        prompt: 'Which productivity method structures work into 25-minute focused bursts separated by short breaks?',
        type: QuizQuestionType.multipleChoice,
        options: ['Pomodoro Technique', 'Feynman Technique', 'Leitner System', 'SQ3R Method'],
        correctAnswer: 'Pomodoro Technique',
        explanation: 'The Pomodoro Technique maintains cognitive alertness while fighting executive burnout and time blindness.',
        subTopic: 'Study Habits',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_5',
        prompt: 'Which memory subsystem temporarily stores and manipulates incoming information for immediate reasoning?',
        type: QuizQuestionType.multipleChoice,
        options: ['Working Memory', 'Sensory Register', 'Implicit Memory', 'Echoic Memory'],
        correctAnswer: 'Working Memory',
        explanation: 'Working memory operates as the mental workspace for active cognitive processing and decision making.',
        subTopic: 'Cognitive Psychology',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_6',
        prompt: 'What is the empirical finding that active self-testing yields superior retention compared to re-reading?',
        type: QuizQuestionType.multipleChoice,
        options: ['The Testing Effect', 'The Hawthorne Effect', 'The Pygmalion Effect', 'The Halo Effect'],
        correctAnswer: 'The Testing Effect',
        explanation: 'Retrieval practice actively strengthens neural pathways more reliably than passive review.',
        subTopic: 'Learning Science',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_7',
        prompt: 'In modern FSRS memory scheduling models, what does the core metric "S" quantify?',
        type: QuizQuestionType.multipleChoice,
        options: ['Memory Stability', 'Subject Difficulty', 'Study Speed', 'Session Score'],
        correctAnswer: 'Memory Stability',
        explanation: 'Memory Stability represents the time interval in days required for recall probability to decline to 90%.',
        subTopic: 'FSRS Algorithm',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_8',
        prompt: 'Which limbic structure is vital for converting transient working memory into permanent long-term storage?',
        type: QuizQuestionType.multipleChoice,
        options: ['Hippocampus', 'Amygdala', 'Cerebellum', 'Thalamus'],
        correctAnswer: 'Hippocampus',
        explanation: 'The hippocampus coordinates memory consolidation through synaptic plasticity and hippocampal replay during sleep.',
        subTopic: 'Neuroscience',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_9',
        prompt: 'Which cognitive bias causes students to mistake familiar passive text for genuine subject mastery?',
        type: QuizQuestionType.multipleChoice,
        options: ['Illusion of Competence', 'Confirmation Bias', 'Availability Heuristic', 'Anchoring Bias'],
        correctAnswer: 'Illusion of Competence',
        explanation: 'Recognizing text when reading is much easier than active recall, creating a false sense of preparedness.',
        subTopic: 'Metacognition',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_10',
        prompt: 'Which cerebral lobe contains the dorsolateral prefrontal cortex coordinating executive functions and impulse control?',
        type: QuizQuestionType.multipleChoice,
        options: ['Frontal Lobe', 'Temporal Lobe', 'Parietal Lobe', 'Occipital Lobe'],
        correctAnswer: 'Frontal Lobe',
        explanation: 'The frontal lobe governs goal planning, emotional regulation, working memory, and inhibition.',
        subTopic: 'Neuroscience',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_11',
        prompt: 'What biological principle denotes the brain’s lifelong structural and functional adaptability in response to learning?',
        type: QuizQuestionType.multipleChoice,
        options: ['Neuroplasticity', 'Long-term Depression', 'Apoptosis', 'Myelination'],
        correctAnswer: 'Neuroplasticity',
        explanation: 'Neuroplasticity enables the brain to rewire neural connections dynamically through deliberate practice.',
        subTopic: 'Neuroscience',
      ),
      QuizQuestionEntity(
        id: 'arcade_fallback_12',
        prompt: 'According to Cognitive Load Theory, which load type denotes cognitive effort directly devoted to schema formation?',
        type: QuizQuestionType.multipleChoice,
        options: ['Germane Load', 'Extraneous Load', 'Intrinsic Load', 'Perceptual Load'],
        correctAnswer: 'Germane Load',
        explanation: 'Germane cognitive load is beneficial effort dedicated to processing and integrating new schemas into long-term memory.',
        subTopic: 'Cognitive Science',
      ),
    ];
  }

  static List<QuizQuestionEntity> _sanitizeQuestions(List<QuizQuestionEntity> questions) {
    return questions.map((q) {
      final cleanCorrect = QuizContentSanitizer.cleanOptionText(q.correctAnswer);
      final cleanOpts = q.options.map(QuizContentSanitizer.cleanOptionText).toList();
      if (!cleanOpts.any((opt) => opt.toLowerCase() == cleanCorrect.toLowerCase()) && cleanCorrect.isNotEmpty) {
        if (cleanOpts.isNotEmpty) {
          cleanOpts[0] = cleanCorrect;
        } else {
          cleanOpts.add(cleanCorrect);
        }
      }
      return q.copyWith(
        prompt: QuizContentSanitizer.cleanPrompt(q.prompt),
        options: cleanOpts,
        correctAnswer: cleanCorrect,
        subTopic: QuizContentSanitizer.cleanSubTopic(q.subTopic),
      );
    }).toList();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
