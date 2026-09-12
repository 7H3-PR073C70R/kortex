import 'dart:async';
import 'dart:math';

import 'package:kortex/src/core/networking/realtime/realtime_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';

/// Realtime Phoenix-style WebSocket & Broadcast Channel Client for 1v1 Quiz Duels (QZ-13).
class QuizDuelWebSocketClient {
  QuizDuelWebSocketClient({
    RealtimeClient? realtimeClient,
    Random? random,
  })  : _realtimeClient = realtimeClient ?? RealtimeClient.instance,
        _random = random ?? Random();

  final RealtimeClient _realtimeClient;
  final Random _random;

  /// Supabase Realtime client reference
  RealtimeClient get realtimeClient => _realtimeClient;

  final Map<String, StreamController<QuizDuelMatch>> _matchControllers = {};
  final Map<String, QuizDuelMatch> _activeMatches = {};
  final Map<String, Timer> _roundTimers = {};
  final Map<String, Timer> _aiActionTimers = {};

  /// Points configuration
  static const int baseCorrectPoints = 100;
  static const int maxSpeedBonus = 50;
  static const int defaultQuestionTimeSeconds = 15;

  /// Default fallback past questions when starting a duel
  static List<QuizQuestionEntity> getDefaultDuelQuestions(String subject, String examBoard) {
    return [
      const QuizQuestionEntity(
        id: 'duel_q_1',
        prompt: 'What is the SI unit of electric potential difference?',
        type: QuizQuestionType.multipleChoice,
        options: ['Ampere', 'Volt', 'Ohm', 'Joule'],
        correctAnswer: 'Volt',
        explanation: 'The SI unit of electric potential difference (voltage) is the Volt (V), defined as one joule per coulomb.',
        subTopic: 'Current Electricity',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_2',
        prompt: r'Evaluate the integral: \(\int 2x\,dx\)',
        type: QuizQuestionType.multipleChoice,
        options: [r'\(2x^2 + C\)', r'\(x^2 + C\)', r'\(x + C\)', r'\(2 + C\)'],
        correctAnswer: r'\(x^2 + C\)',
        explanation: r'Integrating \(2x\) with respect to \(x\) gives \(2 \cdot \frac{x^2}{2} + C = x^2 + C\).',
        subTopic: 'Calculus',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_3',
        prompt: 'Which organelle is known as the powerhouse of the cell?',
        type: QuizQuestionType.multipleChoice,
        options: ['Ribosome', 'Golgi apparatus', 'Mitochondria', 'Nucleus'],
        correctAnswer: 'Mitochondria',
        explanation: 'Mitochondria generate most of the chemical energy needed to power biochemical reactions via ATP synthesis.',
        subTopic: 'Cell Biology',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_4',
        prompt: 'In economics, what happens when demand exceeds supply?',
        type: QuizQuestionType.multipleChoice,
        options: ['Price falls', 'Price rises', 'Supply shifts left', 'Equilibrium unchanged'],
        correctAnswer: 'Price rises',
        explanation: 'Excess demand creates upward price pressure until a new market equilibrium is established.',
        subTopic: 'Price Theory',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_5',
        prompt: 'Which law states that energy cannot be created or destroyed?',
        type: QuizQuestionType.multipleChoice,
        options: [
          'First Law of Thermodynamics',
          'Second Law of Thermodynamics',
          "Newton's Third Law",
          "Hooke's Law"
        ],
        correctAnswer: 'First Law of Thermodynamics',
        explanation: 'The Law of Conservation of Energy (First Law of Thermodynamics) states energy can only change forms.',
        subTopic: 'Thermodynamics',
      ),
    ];
  }

  /// Finds or creates a duel match room.
  Future<QuizDuelMatch> findOrCreateDuel({
    required String subject,
    required String examBoard,
    required String userId,
    required String displayName,
    required String avatarUrl,
    List<QuizQuestionEntity>? customQuestions,
  }) async {
    final duelId = 'duel_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
    final questions = (customQuestions != null && customQuestions.isNotEmpty)
        ? customQuestions
        : getDefaultDuelQuestions(subject, examBoard);

    final player1 = QuizDuelParticipant(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isReady: true,
      eloRating: 1250,
    );

    // Initial match in matching state
    final match = QuizDuelMatch(
      duelId: duelId,
      subject: subject,
      examBoard: examBoard,
      questions: questions,
      player1: player1,
      createdAt: DateTime.now(),
    );

    _activeMatches[duelId] = match;
    _getOrCreateController(duelId).add(match);

    // Schedule AI Peer match after brief matching delay (1.2s)
    Timer(const Duration(milliseconds: 1200), () {
      if (_activeMatches[duelId]?.status == QuizDuelStatus.matching) {
        _simulateMatchFoundWithAi(duelId);
      }
    });

    return match;
  }

  void _simulateMatchFoundWithAi(String duelId) {
    final current = _activeMatches[duelId];
    if (current == null) return;

    final aiNames = ['Syllabot Scholar', 'Ada Lovelace ⚡', 'Kortex Rival', 'Newton Mind'];
    final aiAvatars = ['🧠', '🚀', '⚡', '🏆'];
    final pick = _random.nextInt(aiNames.length);

    final player2 = QuizDuelParticipant(
      userId: 'ai_bot_${_random.nextInt(9999)}',
      displayName: aiNames[pick],
      avatarUrl: aiAvatars[pick],
      isReady: true,
      isAiOpponent: true,
      eloRating: 1200 + _random.nextInt(150),
    );

    final updated = current.copyWith(
      player2: player2,
      status: QuizDuelStatus.countdown,
    );

    _updateMatch(duelId, updated);

    // After 2.5s countdown, start round 1
    Timer(const Duration(milliseconds: 2500), () {
      _startRound(duelId, 0);
    });
  }

  /// Manually starts a round (used for testing or immediate starts).
  void forceStartRound(String duelId, [int questionIndex = 0]) {
    _startRound(duelId, questionIndex);
  }

  void _startRound(String duelId, int questionIndex) {
    final current = _activeMatches[duelId];
    if (current == null || questionIndex >= current.questions.length) {
      _finalizeMatch(duelId);
      return;
    }

    final p1 = current.player1.copyWith(
      currentQuestionIndex: questionIndex,
    );
    final p2 = current.player2?.copyWith(
      currentQuestionIndex: questionIndex,
    );

    final updated = current.copyWith(
      currentQuestionIndex: questionIndex,
      status: QuizDuelStatus.inRound,
      player1: p1,
      player2: p2,
    );

    _updateMatch(duelId, updated);

    // Schedule AI answer simulation
    if (p2 != null && p2.isAiOpponent) {
      _scheduleAiAnswer(duelId, questionIndex);
    }

    // Schedule round timeout
    _roundTimers[duelId]?.cancel();
    _roundTimers[duelId] = Timer(Duration(seconds: current.durationPerQuestionSeconds), () {
      _onRoundTimeExpired(duelId, questionIndex);
    });
  }

  void _scheduleAiAnswer(String duelId, int questionIndex) {
    _aiActionTimers[duelId]?.cancel();
    final delayMs = 3000 + _random.nextInt(4500); // 3s to 7.5s
    _aiActionTimers[duelId] = Timer(Duration(milliseconds: delayMs), () {
      final current = _activeMatches[duelId];
      if (current == null ||
          current.status != QuizDuelStatus.inRound ||
          current.currentQuestionIndex != questionIndex) {
        return;
      }

      final q = current.currentQuestion;
      if (q == null) return;

      final correctIndex = q.options.indexOf(q.correctAnswer);
      final validCorrectIdx = correctIndex >= 0 ? correctIndex : 0;

      // 80% chance of correct answer for AI
      final willBeCorrect = _random.nextDouble() < 0.80;
      final selectedOption = willBeCorrect
          ? validCorrectIdx
          : (validCorrectIdx + 1) % q.options.length;

      unawaited(
        submitDuelAnswer(
          duelId: duelId,
          userId: current.player2!.userId,
          questionIndex: questionIndex,
          optionIndex: selectedOption,
          responseTimeMs: delayMs,
        ),
      );
    });
  }

  /// Submits an answer for player 1 or player 2.
  Future<void> submitDuelAnswer({
    required String duelId,
    required String userId,
    required int questionIndex,
    required int optionIndex,
    required int responseTimeMs,
  }) async {
    final current = _activeMatches[duelId];
    if (current == null ||
        current.status != QuizDuelStatus.inRound ||
        current.currentQuestionIndex != questionIndex) {
      return;
    }

    final q = current.currentQuestion;
    if (q == null) return;

    final selectedText = (optionIndex >= 0 && optionIndex < q.options.length)
        ? q.options[optionIndex]
        : '';
    final isCorrect = selectedText == q.correctAnswer;
    final timeLimitMs = current.durationPerQuestionSeconds * 1000;
    final remainingMs = max(0, timeLimitMs - responseTimeMs);
    final speedBonus = isCorrect ? ((remainingMs / timeLimitMs) * maxSpeedBonus).round() : 0;
    final earnedPoints = isCorrect ? (baseCorrectPoints + speedBonus) : 0;

    QuizDuelParticipant? updatedP1 = current.player1;
    var updatedP2 = current.player2;

    if (current.player1.userId == userId) {
      final streak = isCorrect ? current.player1.comboStreak + 1 : 0;
      updatedP1 = current.player1.copyWith(
        selectedOptionIndex: optionIndex,
        answeredInMs: responseTimeMs,
        isAnswerCorrect: isCorrect,
        score: current.player1.score + earnedPoints,
        comboStreak: streak,
      );
    } else if (current.player2?.userId == userId) {
      final streak = isCorrect ? current.player2!.comboStreak + 1 : 0;
      updatedP2 = current.player2!.copyWith(
        selectedOptionIndex: optionIndex,
        answeredInMs: responseTimeMs,
        isAnswerCorrect: isCorrect,
        score: current.player2!.score + earnedPoints,
        comboStreak: streak,
      );
    }

    final updated = current.copyWith(
      player1: updatedP1,
      player2: updatedP2,
    );

    _updateMatch(duelId, updated);

    // If both players have answered, conclude round early
    if (updated.player1.selectedOptionIndex != null &&
        updated.player2?.selectedOptionIndex != null) {
      _roundTimers[duelId]?.cancel();
      _concludeRound(duelId, questionIndex);
    }
  }

  void _onRoundTimeExpired(String duelId, int questionIndex) {
    final current = _activeMatches[duelId];
    if (current == null || current.currentQuestionIndex != questionIndex) return;

    _concludeRound(duelId, questionIndex);
  }

  void _concludeRound(String duelId, int questionIndex) {
    final current = _activeMatches[duelId];
    if (current == null) return;

    final updated = current.copyWith(status: QuizDuelStatus.roundSummary);
    _updateMatch(duelId, updated);

    // Show round summary for 2.8s, then proceed to next question
    Timer(const Duration(milliseconds: 2800), () {
      final nextIdx = questionIndex + 1;
      if (nextIdx < current.questions.length) {
        _startRound(duelId, nextIdx);
      } else {
        _finalizeMatch(duelId);
      }
    });
  }

  void _finalizeMatch(String duelId) {
    final current = _activeMatches[duelId];
    if (current == null) return;

    final p1Score = current.player1.score;
    final p2Score = current.player2?.score ?? 0;

    String? winnerId;
    var isDraw = false;

    if (p1Score > p2Score) {
      winnerId = current.player1.userId;
    } else if (p2Score > p1Score && current.player2 != null) {
      winnerId = current.player2!.userId;
    } else {
      isDraw = true;
    }

    final finished = current.copyWith(
      status: QuizDuelStatus.finished,
      winnerUserId: winnerId,
      isDraw: isDraw,
    );

    _updateMatch(duelId, finished);
  }

  /// Sends a real-time reaction emote.
  Future<void> sendDuelEmote({
    required String duelId,
    required String userId,
    required String emote,
  }) async {
    final current = _activeMatches[duelId];
    if (current == null) return;

    final updated = current.copyWith(
      latestEmote: emote,
      latestEmoteSenderId: userId,
    );
    _updateMatch(duelId, updated);
  }

  /// Streams real-time updates for a duel.
  Stream<QuizDuelMatch> streamDuel(String duelId) {
    final ctrl = _getOrCreateController(duelId);
    return ctrl.stream;
  }

  /// Leaves or terminates a duel match.
  Future<void> leaveDuel({required String duelId, required String userId}) async {
    _roundTimers[duelId]?.cancel();
    _aiActionTimers[duelId]?.cancel();
    final current = _activeMatches[duelId];
    if (current != null) {
      final cancelled = current.copyWith(status: QuizDuelStatus.cancelled);
      _updateMatch(duelId, cancelled);
    }
  }

  StreamController<QuizDuelMatch> _getOrCreateController(String duelId) {
    return _matchControllers.putIfAbsent(
      duelId,
      StreamController<QuizDuelMatch>.broadcast,
    );
  }

  void _updateMatch(String duelId, QuizDuelMatch match) {
    _activeMatches[duelId] = match;
    final ctrl = _matchControllers[duelId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(match);
    }
  }

  void dispose() {
    for (final timer in _roundTimers.values) {
      timer.cancel();
    }
    for (final timer in _aiActionTimers.values) {
      timer.cancel();
    }
    for (final ctrl in _matchControllers.values) {
      unawaited(ctrl.close());
    }
    _matchControllers.clear();
    _activeMatches.clear();
  }
}
