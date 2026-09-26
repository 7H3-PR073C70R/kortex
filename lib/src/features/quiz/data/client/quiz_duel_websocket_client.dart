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

  /// Returns default question bank when dynamic question loading is not active.
  static List<QuizQuestionEntity> getDefaultDuelQuestions(
    String subject,
    String examBoard, {
    int count = 10,
  }) {
    return [
      const QuizQuestionEntity(
        id: 'q1',
        prompt: 'What is the SI unit of electric potential difference?',
        type: QuizQuestionType.multipleChoice,
        options: ['Volt', 'Ampere', 'Ohm', 'Watt'],
        correctAnswer: 'Volt',
        explanation:
            'Voltage or electric potential difference is measured in Volts (V).',
        subTopic: 'Electricity',
      ),
      const QuizQuestionEntity(
        id: 'q2',
        prompt: 'In how many ways can the word MATHEMATICS be arranged?',
        type: QuizQuestionType.multipleChoice,
        options: [
          '11!/(9! 2!)',
          '11!/(9! 2! 2!)',
          '11!/(2! 2! 2!)',
          '11!/(2! 2!)',
        ],
        correctAnswer: '11!/(2! 2! 2!)',
        explanation:
            "MATHEMATICS has 11 letters with 2 M's, 2 A's, and 2 T's.",
        subTopic: 'Permutations',
      ),
    ];
  }
  bool _matchmakingListenerInitialized = false;
  final Set<String> _listenedDuelChannels = {};

  void _initMatchmakingRealtime() {
    if (_matchmakingListenerInitialized) return;
    _matchmakingListenerInitialized = true;

    _realtimeClient
        .watchPresence('realtime:quiz_duel_matchmaking')
        .listen((msg) {
      try {
        final event = msg['event'] as String?;
        final payload = msg['payload'] as Map<String, dynamic>? ?? {};

        if (event == 'broadcast') {
          final inner =
              (payload['payload'] as Map<String, dynamic>?) ?? payload;
          final type = inner['type'] as String?;
          final data = (inner['data'] as Map<String, dynamic>?) ?? inner;

          if (type == 'search') {
            final remoteDuelId = data['duelId'] as String?;
            final remoteUserId = data['userId'] as String?;
            final remoteMatchJson = data['match'] as Map<String, dynamic>?;

            if (remoteDuelId == null || remoteUserId == null) return;

            for (final localMatch in _activeMatches.values.toList()) {
              if (localMatch.status == QuizDuelStatus.matching &&
                  localMatch.player1.userId != remoteUserId &&
                  localMatch.player2 == null &&
                  localMatch.subject.trim().toLowerCase() ==
                      (data['subject'] as String? ?? '').trim().toLowerCase() &&
                  localMatch.examBoard.trim().toLowerCase() ==
                      (data['examBoard'] as String? ?? '').trim().toLowerCase()) {
                // Deterministic host tie-breaker:
                // Compare localDuelId vs remoteDuelId. The smaller duelId lexicographically is the host room.
                // Both clients agree on the exact same host duelId and host question set.
                final isLocalHost =
                    localMatch.duelId.compareTo(remoteDuelId) <= 0;

                final QuizDuelMatch syncedMatch;
                if (isLocalHost) {
                  final remoteP2 = QuizDuelParticipant(
                    userId: remoteUserId,
                    displayName:
                        data['displayName'] as String? ?? 'Scholar',
                    avatarUrl: data['avatarUrl'] as String? ?? '',
                    isReady: true,
                    eloRating: remoteMatchJson != null
                        ? (remoteMatchJson['player1']?['eloRating'] as int? ??
                            1250)
                        : 1250,
                  );

                  syncedMatch = localMatch.copyWith(
                    player2: remoteP2,
                    status: QuizDuelStatus.countdown,
                  );
                } else {
                  final remoteMatch = remoteMatchJson != null
                      ? QuizDuelMatch.fromJson(remoteMatchJson)
                      : QuizDuelMatch(
                          duelId: remoteDuelId,
                          subject: localMatch.subject,
                          examBoard: localMatch.examBoard,
                          questions: localMatch.questions,
                          player1: QuizDuelParticipant(
                            userId: remoteUserId,
                            displayName:
                                data['displayName'] as String? ?? 'Scholar',
                            avatarUrl: data['avatarUrl'] as String? ?? '',
                            isReady: true,
                            eloRating: 1250,
                          ),
                        );

                  final localP2 = QuizDuelParticipant(
                    userId: localMatch.player1.userId,
                    displayName: localMatch.player1.displayName,
                    avatarUrl: localMatch.player1.avatarUrl,
                    isReady: true,
                    eloRating: localMatch.player1.eloRating,
                  );

                  syncedMatch = remoteMatch.copyWith(
                    player2: localP2,
                    status: QuizDuelStatus.countdown,
                  );
                }

                _matchingTimers[localMatch.duelId]?.cancel();
                _matchingTimers[syncedMatch.duelId]?.cancel();

                _activeMatches[syncedMatch.duelId] = syncedMatch;
                _updateMatch(localMatch.duelId, syncedMatch);
                _updateMatch(syncedMatch.duelId, syncedMatch);
                _listenToDuelChannel(syncedMatch.duelId);

                _realtimeClient.broadcastPresence(
                  channelName: 'realtime:quiz_duel_matchmaking',
                  payload: {
                    'type': 'match_joined',
                    'data': {
                      'duelId': syncedMatch.duelId,
                      'matchedUserId': remoteUserId,
                      'player2': syncedMatch.player2?.toJson(),
                      'match': syncedMatch.toJson(),
                    },
                  },
                );

                Timer(const Duration(milliseconds: 3000), () {
                  _startRound(syncedMatch.duelId, 0);
                });
                break;
              }
            }
          } else if (type == 'match_joined') {
            final matchJson = data['match'] as Map<String, dynamic>?;

            if (matchJson != null) {
              final syncedMatch = QuizDuelMatch.fromJson(matchJson);

              for (final localMatch in _activeMatches.values.toList()) {
                if (localMatch.status == QuizDuelStatus.matching &&
                    (localMatch.duelId == syncedMatch.duelId ||
                        localMatch.player1.userId ==
                            syncedMatch.player1.userId ||
                        localMatch.player1.userId ==
                            syncedMatch.player2?.userId)) {
                  _matchingTimers[localMatch.duelId]?.cancel();
                  _matchingTimers[syncedMatch.duelId]?.cancel();

                  _activeMatches[syncedMatch.duelId] = syncedMatch;
                  _updateMatch(localMatch.duelId, syncedMatch);
                  _updateMatch(syncedMatch.duelId, syncedMatch);
                  _listenToDuelChannel(syncedMatch.duelId);

                  Timer(const Duration(milliseconds: 3000), () {
                    if (_activeMatches[syncedMatch.duelId]?.status ==
                        QuizDuelStatus.countdown) {
                      _startRound(syncedMatch.duelId, 0);
                    }
                  });
                  break;
                }
              }
            }
          } else if (type == 'announcement_request') {
            for (final m in _activeMatches.values) {
              if (m.status == QuizDuelStatus.matching && m.player2 == null) {
                _realtimeClient.broadcastPresence(
                  channelName: 'realtime:quiz_duel_matchmaking',
                  payload: {
                    'type': 'search',
                    'data': {
                      'duelId': m.duelId,
                      'subject': m.subject,
                      'examBoard': m.examBoard,
                      'userId': m.player1.userId,
                      'displayName': m.player1.displayName,
                      'avatarUrl': m.player1.avatarUrl,
                      'match': m.toJson(),
                    },
                  },
                );
              }
            }
          }
        }
      } on Exception catch (_) {}
    });
  }

  void _listenToDuelChannel(String duelId) {
    if (_listenedDuelChannels.contains(duelId)) return;
    _listenedDuelChannels.add(duelId);

    final channel = 'realtime:quiz_duel:$duelId';
    _realtimeClient.watchPresence(channel).listen((msg) {
      try {
        final event = msg['event'] as String?;
        final payload = msg['payload'] as Map<String, dynamic>? ?? {};

        if (event == 'broadcast') {
          final inner =
              (payload['payload'] as Map<String, dynamic>?) ?? payload;
          final type = inner['type'] as String?;
          final data = (inner['data'] as Map<String, dynamic>?) ?? inner;

          if (type == 'submit_answer') {
            final userId = data['userId'] as String?;
            final questionIndex = data['questionIndex'] as int? ?? 0;
            final optionIndex = data['optionIndex'] as int? ?? 0;
            final responseTimeMs = data['responseTimeMs'] as int? ?? 1000;
            final earnedPoints = data['earnedPoints'] as int?;

            if (userId != null) {
              _applyDuelAnswerLocally(
                duelId: duelId,
                userId: userId,
                questionIndex: questionIndex,
                optionIndex: optionIndex,
                responseTimeMs: responseTimeMs,
                earnedPointsOverride: earnedPoints,
              );
            }
          } else if (type == 'start_round') {
            final questionIndex = data['questionIndex'] as int? ?? 0;
            _applyStartRoundLocally(duelId, questionIndex);
          } else if (type == 'conclude_round') {
            final questionIndex = data['questionIndex'] as int? ?? 0;
            _concludeRound(duelId, questionIndex);
          } else if (type == 'send_emote') {
            final userId = data['userId'] as String?;
            final emote = data['emote'] as String?;
            final timestamp = data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
            if (userId != null && emote != null) {
              _applyEmoteLocally(duelId: duelId, userId: userId, emote: emote, timestamp: timestamp);
            }
          } else if (type == 'leave_duel') {
            final userId = data['userId'] as String?;
            if (userId != null) {
              _applyLeaveLocally(duelId: duelId, userId: userId);
            }
          }
        }
      } on Exception catch (_) {}
    });
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
    _initMatchmakingRealtime();

    // 1. Check if another real player is already waiting in matchmaking locally
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
      _listenToDuelChannel(existingMatch.duelId);

      _realtimeClient.broadcastPresence(
        channelName: 'realtime:quiz_duel_matchmaking',
        payload: {
          'type': 'match_joined',
          'data': {
            'duelId': existingMatch.duelId,
            'matchedUserId': userId,
            'player2': player2.toJson(),
            'match': matched.toJson(),
          },
        },
      );

      Timer(const Duration(milliseconds: 3000), () {
        _startRound(existingMatch!.duelId, 0);
      });

      return matched;
    }

    // 2. No open room found locally: Create new match and broadcast search event to peers
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
    _listenToDuelChannel(duelId);

    // Broadcast search query over Realtime
    _realtimeClient
      ..broadcastPresence(
        channelName: 'realtime:quiz_duel_matchmaking',
        payload: {
          'type': 'search',
          'data': {
            'duelId': duelId,
            'subject': subject,
            'examBoard': examBoard,
            'userId': userId,
            'displayName': displayName,
            'avatarUrl': avatarUrl,
            'match': match.toJson(),
          },
        },
      )
      ..broadcastPresence(
        channelName: 'realtime:quiz_duel_matchmaking',
        payload: {'type': 'announcement_request'},
      );

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

    final aiPersonalities = [
      ('⚡ Speedy Scholar', '🧠'),
      ('🎯 Calculated Genius', '💡'),
      ('🚀 Formula Prodigy', '🚀'),
      ('👑 Syllabot Rival', '🏆'),
      ('🛡️ Master Duelist', '⚡'),
    ];
    final pick = aiPersonalities[_random.nextInt(aiPersonalities.length)];
    final p1Elo = current.player1.eloRating;
    final aiElo = (p1Elo + (_random.nextInt(101) - 50)).clamp(1000, 2200);

    final player2 = QuizDuelParticipant(
      userId: 'ai_bot_${_random.nextInt(9999)}',
      displayName: pick.$1,
      avatarUrl: pick.$2,
      isReady: true,
      isAiOpponent: true,
      eloRating: aiElo,
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
    _applyStartRoundLocally(duelId, questionIndex);

    _realtimeClient.broadcastPresence(
      channelName: 'realtime:quiz_duel:$duelId',
      payload: {
        'type': 'start_round',
        'data': {
          'duelId': duelId,
          'questionIndex': questionIndex,
        },
      },
    );
  }

  void _applyStartRoundLocally(String duelId, int questionIndex) {
    final current = _activeMatches[duelId];
    if (current == null || questionIndex >= current.questions.length) {
      _finalizeMatch(duelId);
      return;
    }

    if (current.status == QuizDuelStatus.inRound &&
        current.currentQuestionIndex == questionIndex) {
      return;
    }

    final p1 = current.player1.resetForNewRound(
      questionIndex: questionIndex,
    );
    final p2 = current.player2?.resetForNewRound(
      questionIndex: questionIndex,
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

    final current = _activeMatches[duelId];
    final aiParticipant = current?.player2;
    final aiElo = aiParticipant?.eloRating ?? 1200;

    // Accuracy ranges from 65% (Bronze) up to 90% (Legend)
    final accuracy = (0.65 + ((aiElo - 1000) / 1200) * 0.25).clamp(0.60, 0.92);

    // Response time ranges from 700ms - 1500ms for high ELO, 1800ms - 3200ms for lower ELO
    final baseDelayMs = aiElo >= 1500
        ? (600 + _random.nextInt(800))
        : (1500 + _random.nextInt(1500));

    _aiActionTimers[duelId] = Timer(Duration(milliseconds: baseDelayMs), () {
      final activeMatch = _activeMatches[duelId];
      if (activeMatch == null ||
          activeMatch.status != QuizDuelStatus.inRound ||
          activeMatch.currentQuestionIndex != questionIndex) {
        return;
      }

      final q = activeMatch.currentQuestion;
      if (q == null) return;

      final correctIndex = q.options.indexOf(q.correctAnswer);
      final validCorrectIdx = correctIndex >= 0 ? correctIndex : 0;

      final willBeCorrect = _random.nextDouble() < accuracy;
      final selectedOption = willBeCorrect
          ? validCorrectIdx
          : (validCorrectIdx + 1) % q.options.length;

      unawaited(
        submitDuelAnswer(
          duelId: duelId,
          userId: activeMatch.player2!.userId,
          questionIndex: questionIndex,
          optionIndex: selectedOption,
          responseTimeMs: baseDelayMs,
        ),
      );
    });
  }

  void _applyDuelAnswerLocally({
    required String duelId,
    required String userId,
    required int questionIndex,
    required int optionIndex,
    required int responseTimeMs,
    int? earnedPointsOverride,
  }) {
    final current = _activeMatches[duelId];
    if (current == null ||
        current.currentQuestionIndex != questionIndex) {
      return;
    }

    if (current.status != QuizDuelStatus.inRound &&
        current.status != QuizDuelStatus.roundSummary) {
      return;
    }

    final isPlayer1 = current.player1.userId == userId;
    final isPlayer2 = current.player2?.userId == userId;
    if (!isPlayer1 && !isPlayer2) return;

    final targetPlayer = isPlayer1 ? current.player1 : current.player2!;
    if (targetPlayer.selectedOptionIndex != null) {
      // Idempotency: Ignore duplicate submission or broadcast echo for an already answered question
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
    final earnedPoints = earnedPointsOverride ?? (isCorrect ? (baseCorrectPoints + speedBonus) : 0);

    QuizDuelParticipant? updatedP1 = current.player1;
    var updatedP2 = current.player2;

    if (isPlayer1) {
      final streak = isCorrect ? current.player1.comboStreak + 1 : 0;
      updatedP1 = current.player1.copyWith(
        selectedOptionIndex: optionIndex,
        answeredInMs: responseTimeMs,
        isAnswerCorrect: isCorrect,
        score: current.player1.score + earnedPoints,
        comboStreak: streak,
      );
    } else if (isPlayer2) {
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

    // If both players have answered and status is inRound, conclude round early
    if (updated.status == QuizDuelStatus.inRound &&
        updated.player1.selectedOptionIndex != null &&
        updated.player2?.selectedOptionIndex != null) {
      _roundTimers[duelId]?.cancel();
      _concludeRound(duelId, questionIndex);
    }
  }

  /// Submits an answer for player 1 or player 2.
  Future<void> submitDuelAnswer({
    required String duelId,
    required String userId,
    required int questionIndex,
    required int optionIndex,
    required int responseTimeMs,
  }) async {
    final match = _activeMatches[duelId];
    int? earnedPoints;
    if (match != null && match.currentQuestion != null) {
      final q = match.currentQuestion!;
      final selectedText = (optionIndex >= 0 && optionIndex < q.options.length)
          ? q.options[optionIndex]
          : '';
      final isCorrect = selectedText == q.correctAnswer;
      final timeLimitMs = match.durationPerQuestionSeconds * 1000;
      final remainingMs = max(0, timeLimitMs - responseTimeMs);
      final speedBonus = isCorrect
          ? ((remainingMs / timeLimitMs) * maxSpeedBonus).round()
          : 0;
      earnedPoints = isCorrect ? (baseCorrectPoints + speedBonus) : 0;
    }

    _applyDuelAnswerLocally(
      duelId: duelId,
      userId: userId,
      questionIndex: questionIndex,
      optionIndex: optionIndex,
      responseTimeMs: responseTimeMs,
      earnedPointsOverride: earnedPoints,
    );

    _realtimeClient.broadcastPresence(
      channelName: 'realtime:quiz_duel:$duelId',
      payload: {
        'type': 'submit_answer',
        'data': {
          'duelId': duelId,
          'userId': userId,
          'questionIndex': questionIndex,
          'optionIndex': optionIndex,
          'responseTimeMs': responseTimeMs,
          'earnedPoints': ?earnedPoints,
        },
      },
    );
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
    if (current.status == QuizDuelStatus.roundSummary &&
        current.currentQuestionIndex == questionIndex) {
      return;
    }

    final updated = current.copyWith(status: QuizDuelStatus.roundSummary);
    _updateMatch(duelId, updated);

    _realtimeClient.broadcastPresence(
      channelName: 'realtime:quiz_duel:$duelId',
      payload: {
        'type': 'conclude_round',
        'data': {
          'duelId': duelId,
          'questionIndex': questionIndex,
        },
      },
    );

    // Show round summary briefly (800ms for clear visual feedback), then proceed smoothly to next question
    _roundTimers[duelId]?.cancel();
    _roundTimers[duelId] = Timer(const Duration(milliseconds: 800), () {
      final latest = _activeMatches[duelId];
      if (latest == null || latest.currentQuestionIndex != questionIndex) {
        return;
      }
      final nextIdx = questionIndex + 1;
      if (nextIdx < latest.questions.length) {
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

  void _applyEmoteLocally({
    required String duelId,
    required String userId,
    required String emote,
    int? timestamp,
  }) {
    final current = _activeMatches[duelId];
    if (current == null) return;

    final updated = current.copyWith(
      latestEmote: emote,
      latestEmoteSenderId: userId,
      latestEmoteTimestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
    );
    _updateMatch(duelId, updated);
  }

  /// Sends a real-time reaction emote.
  Future<void> sendDuelEmote({
    required String duelId,
    required String userId,
    required String emote,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _applyEmoteLocally(duelId: duelId, userId: userId, emote: emote, timestamp: timestamp);

    _realtimeClient.broadcastPresence(
      channelName: 'realtime:quiz_duel:$duelId',
      payload: {
        'type': 'send_emote',
        'data': {
          'duelId': duelId,
          'userId': userId,
          'emote': emote,
          'timestamp': timestamp,
        },
      },
    );
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

  void _applyLeaveLocally({
    required String duelId,
    required String userId,
  }) {
    _matchingTimers[duelId]?.cancel();
    _roundTimers[duelId]?.cancel();
    _aiActionTimers[duelId]?.cancel();
    final current = _activeMatches[duelId];
    if (current != null) {
      if (current.status == QuizDuelStatus.matching) {
        final cancelled = current.copyWith(status: QuizDuelStatus.cancelled);
        _updateMatch(duelId, cancelled);
      } else if (current.status != QuizDuelStatus.finished) {
        // Active match: player forfeits by leaving. Award victory and bonus points to remaining player.
        final winnerId = current.player1.userId == userId
            ? current.player2?.userId
            : current.player1.userId;

        var p1 = current.player1;
        var p2 = current.player2;

        if (winnerId != null) {
          if (p1.userId == winnerId) {
            p1 = p1.copyWith(
              score: p1.score + 500,
              hasFinished: true,
            );
          } else if (p2?.userId == winnerId) {
            p2 = p2!.copyWith(
              score: p2.score + 500,
              hasFinished: true,
            );
          }
        }

        final finished = current.copyWith(
          player1: p1,
          player2: p2,
          status: QuizDuelStatus.finished,
          winnerUserId: winnerId,
          isDraw: winnerId == null,
          forfeitUserId: userId,
        );
        _updateMatch(duelId, finished);
      }
    }
  }

  /// Leaves or terminates a duel match.
  Future<void> leaveDuel({
    required String duelId,
    required String userId,
  }) async {
    _applyLeaveLocally(duelId: duelId, userId: userId);

    _realtimeClient.broadcastPresence(
      channelName: 'realtime:quiz_duel:$duelId',
      payload: {
        'type': 'leave_duel',
        'data': {
          'duelId': duelId,
          'userId': userId,
        },
      },
    );
  }

  final Map<String, Set<String>> _duelAliases = {};

  void _recordAlias(String aliasId, String canonicalId) {
    if (aliasId == canonicalId) return;
    _duelAliases.putIfAbsent(canonicalId, () => {}).add(aliasId);
    _duelAliases.putIfAbsent(aliasId, () => {}).add(canonicalId);
  }

  StreamController<QuizDuelMatch> _getOrCreateController(String duelId) {
    return _matchControllers.putIfAbsent(
      duelId,
      StreamController<QuizDuelMatch>.broadcast,
    );
  }

  void _updateMatch(String duelId, QuizDuelMatch match) {
    _activeMatches[duelId] = match;
    _activeMatches[match.duelId] = match;
    _recordAlias(duelId, match.duelId);

    final targetIds = <String>{
      duelId,
      match.duelId,
      ...?_duelAliases[duelId],
      ...?_duelAliases[match.duelId],
    };

    for (final id in targetIds) {
      final ctrl = _matchControllers[id];
      if (ctrl != null && !ctrl.isClosed) {
        ctrl.add(match);
      }
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
