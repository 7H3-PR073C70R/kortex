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
    Duration? matchmakingTimeout,
  }) : _realtimeClient = realtimeClient ?? RealtimeClient.instance,
       _random = random ?? Random(),
       matchmakingTimeout = matchmakingTimeout ?? defaultMatchmakingTimeout;
  static const Duration defaultMatchmakingTimeout = Duration(minutes: 2);
  final Duration matchmakingTimeout;

  final RealtimeClient _realtimeClient;
  final Random _random;

  /// Supabase Realtime client reference
  RealtimeClient get realtimeClient => _realtimeClient;

  final Map<String, StreamController<QuizDuelMatch>> _matchControllers = {};
  final Map<String, QuizDuelMatch> _activeMatches = {};
  final Map<String, Timer> _roundTimers = {};
  final Map<String, Timer> _aiActionTimers = {};
  final Map<String, Timer> _matchingTimers = {};

  /// Points configuration
  static const int baseCorrectPoints = 100;
  static const int maxSpeedBonus = 50;
  static const int defaultQuestionTimeSeconds = 15;

  /// Default fallback past questions when starting a duel
  static List<QuizQuestionEntity> getDefaultDuelQuestions(
    String subject,
    String examBoard, {
    int count = 10,
  }) {
    final bank = [
      const QuizQuestionEntity(
        id: 'duel_q_1',
        prompt: 'What is the SI unit of electric potential difference?',
        type: QuizQuestionType.multipleChoice,
        options: ['Ampere', 'Volt', 'Ohm', 'Joule'],
        correctAnswer: 'Volt',
        explanation:
            'The SI unit of electric potential difference (voltage) is the Volt (V), defined as one joule per coulomb.',
        subTopic: 'Current Electricity',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_2',
        prompt: r'Evaluate the integral: \(\int 2x\,dx\)',
        type: QuizQuestionType.multipleChoice,
        options: [r'\(2x^2 + C\)', r'\(x^2 + C\)', r'\(x + C\)', r'\(2 + C\)'],
        correctAnswer: r'\(x^2 + C\)',
        explanation:
            r'Integrating \(2x\) with respect to \(x\) gives \(2 \cdot \frac{x^2}{2} + C = x^2 + C\).',
        subTopic: 'Calculus',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_3',
        prompt: 'Which organelle is known as the powerhouse of the cell?',
        type: QuizQuestionType.multipleChoice,
        options: ['Ribosome', 'Golgi apparatus', 'Mitochondria', 'Nucleus'],
        correctAnswer: 'Mitochondria',
        explanation:
            'Mitochondria generate most of the chemical energy needed to power biochemical reactions via ATP synthesis.',
        subTopic: 'Cell Biology',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_4',
        prompt: 'In economics, what happens when demand exceeds supply?',
        type: QuizQuestionType.multipleChoice,
        options: [
          'Price falls',
          'Price rises',
          'Supply shifts left',
          'Equilibrium unchanged',
        ],
        correctAnswer: 'Price rises',
        explanation:
            'Excess demand creates upward price pressure until a new market equilibrium is established.',
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
          "Hooke's Law",
        ],
        correctAnswer: 'First Law of Thermodynamics',
        explanation:
            'The Law of Conservation of Energy (First Law of Thermodynamics) states energy can only change forms.',
        subTopic: 'Thermodynamics',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_6',
        prompt:
            'In Computer Science, what is the average time complexity of searching in a Balanced Binary Search Tree (AVL/Red-Black)?',
        type: QuizQuestionType.multipleChoice,
        options: [
          r'\(O(1)\)',
          r'\(O(\log n)\)',
          r'\(O(n)\)',
          r'\(O(n \log n)\)',
        ],
        correctAnswer: r'\(O(\log n)\)',
        explanation:
            'Balanced BST operations divide the search space in half at each step, yielding logarithmic time O(log n).',
        subTopic: 'Data Structures & Algorithms',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_7',
        prompt:
            'Which gas is released during photosynthesis when water molecules are split in the light reaction?',
        type: QuizQuestionType.multipleChoice,
        options: ['Carbon dioxide', 'Oxygen', 'Nitrogen', 'Methane'],
        correctAnswer: 'Oxygen',
        explanation:
            'Photolysis of water in the thylakoid membrane during the light-dependent reactions produces oxygen gas.',
        subTopic: 'Biochemistry & Botany',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_8',
        prompt: r'What is the derivative of \(f(x) = \sin(3x)\)?',
        type: QuizQuestionType.multipleChoice,
        options: [
          r'\(3\cos(3x)\)',
          r'\(-\cos(3x)\)',
          r'\(3\sin(3x)\)',
          r'\(-3\cos(3x)\)',
        ],
        correctAnswer: r'\(3\cos(3x)\)',
        explanation:
            r'Applying the chain rule: \(\frac{d}{dx}[\sin(3x)] = \cos(3x) \cdot 3 = 3\cos(3x)\).',
        subTopic: 'Calculus',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_9',
        prompt: 'What is the pH of a neutral aqueous solution at 25°C?',
        type: QuizQuestionType.multipleChoice,
        options: ['0', '7', '14', '10'],
        correctAnswer: '7',
        explanation:
            'At 25°C, pure neutral water has equal hydronium and hydroxide concentrations of 10^-7 M, corresponding to pH 7.',
        subTopic: 'Physical Chemistry',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_10',
        prompt:
            'Which legal principle states that no one can be judged twice for the same offense?',
        type: QuizQuestionType.multipleChoice,
        options: [
          'Double Jeopardy',
          'Habeas Corpus',
          'Mens Rea',
          'Stare Decisis',
        ],
        correctAnswer: 'Double Jeopardy',
        explanation:
            'The doctrine against double jeopardy prevents an accused person from being tried again on the same or similar charges and on the same facts.',
        subTopic: 'Jurisprudence & Constitutional Law',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_11',
        prompt:
            'Which normal human organ filters blood and produces urine as a byproduct?',
        type: QuizQuestionType.multipleChoice,
        options: ['Liver', 'Kidney', 'Pancreas', 'Spleen'],
        correctAnswer: 'Kidney',
        explanation:
            'The nephrons inside the kidneys filter metabolic waste from the bloodstream to form urine.',
        subTopic: 'Human Anatomy & Physiology',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_12',
        prompt:
            'Which acceleration is experienced by an object in uniform circular motion with velocity v and radius r?',
        type: QuizQuestionType.multipleChoice,
        options: [
          r'\(a = \frac{v^2}{r}\)',
          r'\(a = v \cdot r\)',
          r'\(a = \frac{r}{v^2}\)',
          r'\(a = \frac{1}{2}vr\)',
        ],
        correctAnswer: r'\(a = \frac{v^2}{r}\)',
        explanation:
            r'Centripetal acceleration is directed toward the center of curvature and equals \(v^2 / r\).',
        subTopic: 'Mechanics',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_13',
        prompt: 'In macroeconomics, what does GDP stand for?',
        type: QuizQuestionType.multipleChoice,
        options: [
          'Gross Domestic Product',
          'General Development Price',
          'Global Domestic Performance',
          'Government Debt Percentage',
        ],
        correctAnswer: 'Gross Domestic Product',
        explanation:
            'Gross Domestic Product (GDP) is the total monetary or market value of all finished goods and services produced within a country.',
        subTopic: 'Macroeconomics',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_14',
        prompt:
            'Which type of bond is formed by the sharing of electron pairs between atoms?',
        type: QuizQuestionType.multipleChoice,
        options: [
          'Ionic bond',
          'Covalent bond',
          'Hydrogen bond',
          'Metallic bond',
        ],
        correctAnswer: 'Covalent bond',
        explanation:
            'A covalent bond consists of the mutual sharing of one or more pairs of electrons between two non-metallic atoms.',
        subTopic: 'Chemical Bonding',
      ),
      const QuizQuestionEntity(
        id: 'duel_q_15',
        prompt:
            'Which of the following is a fundamental principle of Object-Oriented Programming (OOP)?',
        type: QuizQuestionType.multipleChoice,
        options: ['Encapsulation', 'Compilation', 'Paging', 'Quantization'],
        correctAnswer: 'Encapsulation',
        explanation:
            'The four core pillars of OOP are Encapsulation, Abstraction, Inheritance, and Polymorphism.',
        subTopic: 'Software Engineering',
      ),
    ];

    return bank.take(count.clamp(1, bank.length)).toList();
  }

  /// Finds or creates a duel match room.
  /// Looks for real human opponent first; if none is found after 2 minutes, falls back to AI.
  Future<QuizDuelMatch> findOrCreateDuel({
    required String subject,
    required String examBoard,
    required String userId,
    required String displayName,
    required String avatarUrl,
    int questionCount = 10,
    List<QuizQuestionEntity>? customQuestions,
  }) async {
    // 1. Check if another real player is already waiting in matchmaking for this track/subject
    QuizDuelMatch? existingMatch;
    for (final m in _activeMatches.values) {
      if (m.status == QuizDuelStatus.matching &&
          m.subject.trim().toLowerCase() == subject.trim().toLowerCase() &&
          m.examBoard.trim().toLowerCase() == examBoard.trim().toLowerCase() &&
          m.player1.userId != userId &&
          m.player2 == null) {
        existingMatch = m;
        break;
      }
    }

    if (existingMatch != null) {
      final player2 = QuizDuelParticipant(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isReady: true,
        eloRating: 1250,
      );

      _matchingTimers[existingMatch.duelId]?.cancel();

      final matched = existingMatch.copyWith(
        player2: player2,
        status: QuizDuelStatus.countdown,
      );

      _updateMatch(existingMatch.duelId, matched);

      // Start round 1 after 2.5s countdown
      Timer(const Duration(milliseconds: 2500), () {
        _startRound(existingMatch!.duelId, 0);
      });

      return matched;
    }

    // 2. No open room found: Create new match and wait for real opponent for 2 minutes
    final duelId =
        'duel_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
    final questions = (customQuestions != null && customQuestions.isNotEmpty)
        ? customQuestions
        : getDefaultDuelQuestions(subject, examBoard, count: questionCount);

    final player1 = QuizDuelParticipant(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isReady: true,
      eloRating: 1250,
    );

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

    // Schedule AI match if no real player joins within matchmakingTimeout (default 2 minutes)
    _matchingTimers[duelId]?.cancel();
    _matchingTimers[duelId] = Timer(matchmakingTimeout, () {
      if (_activeMatches[duelId]?.status == QuizDuelStatus.matching) {
        simulateMatchFoundWithAi(duelId);
      }
    });

    return match;
  }

  /// Immediately pairs with an AI opponent if the user chooses not to wait out the 2-minute search.
  void simulateMatchFoundWithAi(String duelId) {
    final current = _activeMatches[duelId];
    if (current == null || current.status != QuizDuelStatus.matching) return;

    _matchingTimers[duelId]?.cancel();

    final aiNames = [
      'Syllabot Scholar',
      'Ada Lovelace ⚡',
      'Kortex Rival',
      'Newton Mind',
      'Curie Intellect',
    ];
    final aiAvatars = ['🧠', '🚀', '⚡', '🏆', '💡'];
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
    _roundTimers[duelId] = Timer(
      Duration(seconds: current.durationPerQuestionSeconds),
      () {
        _onRoundTimeExpired(duelId, questionIndex);
      },
    );
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
    final speedBonus = isCorrect
        ? ((remainingMs / timeLimitMs) * maxSpeedBonus).round()
        : 0;
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
    if (current == null || current.currentQuestionIndex != questionIndex) {
      return;
    }

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
  Stream<QuizDuelMatch> streamDuel(String duelId) async* {
    final current = _activeMatches[duelId];
    if (current != null) {
      yield current;
    }
    final ctrl = _getOrCreateController(duelId);
    yield* ctrl.stream;
  }

  /// Leaves or terminates a duel match.
  Future<void> leaveDuel({
    required String duelId,
    required String userId,
  }) async {
    _matchingTimers[duelId]?.cancel();
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
    for (final timer in _matchingTimers.values) {
      timer.cancel();
    }
    _matchingTimers.clear();
    for (final timer in _roundTimers.values) {
      timer.cancel();
    }
    _roundTimers.clear();
    for (final timer in _aiActionTimers.values) {
      timer.cancel();
    }
    _aiActionTimers.clear();
    for (final ctrl in _matchControllers.values) {
      unawaited(ctrl.close());
    }
    _matchControllers.clear();
    _activeMatches.clear();
  }
}
