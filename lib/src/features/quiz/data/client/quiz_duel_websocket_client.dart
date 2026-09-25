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
  static const int defaultQuestionTimeSeconds = 60;

  /// Returns passed questions or an empty bank (dynamic curation handled via repositories).
  static List<QuizQuestionEntity> getDefaultDuelQuestions(
    String subject,
    String examBoard, {
    int count = 10,
  }) {
    return const [];
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
            final remoteSubject =
                (data['subject'] as String? ?? '').trim().toLowerCase();
            final remoteExamBoard =
                (data['examBoard'] as String? ?? '').trim().toLowerCase();
            final remoteUserId = data['userId'] as String?;
            final remoteDisplayName =
                data['displayName'] as String? ?? 'Scholar';
            final remoteAvatarUrl = data['avatarUrl'] as String? ?? '';

            if (remoteDuelId == null || remoteUserId == null) return;

            for (final localMatch in _activeMatches.values) {
              if (localMatch.status == QuizDuelStatus.matching &&
                  localMatch.subject.trim().toLowerCase() == remoteSubject &&
                  localMatch.examBoard.trim().toLowerCase() ==
                      remoteExamBoard &&
                  localMatch.player1.userId != remoteUserId &&
                  localMatch.player2 == null) {
                final player2 = QuizDuelParticipant(
                  userId: remoteUserId,
                  displayName: remoteDisplayName,
                  avatarUrl: remoteAvatarUrl,
                  isReady: true,
                  eloRating: 1250,
                );

                _matchingTimers[localMatch.duelId]?.cancel();

                final matched = localMatch.copyWith(
                  player2: player2,
                  status: QuizDuelStatus.countdown,
                );

                _updateMatch(localMatch.duelId, matched);
                _listenToDuelChannel(localMatch.duelId);

                _realtimeClient.broadcastPresence(
                  channelName: 'realtime:quiz_duel_matchmaking',
                  payload: {
                    'type': 'match_joined',
                    'data': {
                      'duelId': localMatch.duelId,
                      'matchedUserId': remoteUserId,
                      'match': matched.toJson(),
                    },
                  },
                );

                Timer(const Duration(milliseconds: 2500), () {
                  _startRound(localMatch.duelId, 0);
                });
                break;
              }
            }
          } else if (type == 'match_joined') {
            final matchedUserId = data['matchedUserId'] as String?;
            final matchJson = data['match'] as Map<String, dynamic>?;

            for (final localMatch in _activeMatches.values.toList()) {
              if (localMatch.status == QuizDuelStatus.matching &&
                  (matchedUserId == localMatch.player1.userId || matchJson != null)) {
                _matchingTimers[localMatch.duelId]?.cancel();

                final QuizDuelMatch syncedMatch;
                if (matchJson != null) {
                  syncedMatch = QuizDuelMatch.fromJson(matchJson);
                } else {
                  final duelId = data['duelId'] as String? ?? localMatch.duelId;
                  final player2Data = data['player2'] as Map<String, dynamic>?;
                  final p2 = player2Data != null
                      ? QuizDuelParticipant.fromJson(player2Data)
                      : QuizDuelParticipant(
                          userId: matchedUserId ?? 'p2',
                          displayName: 'Opponent',
                          avatarUrl: '',
                          isReady: true,
                          eloRating: 1250,
                        );
                  syncedMatch = localMatch.copyWith(
                    duelId: duelId,
                    player2: p2,
                    status: QuizDuelStatus.countdown,
                  );
                }

                _activeMatches[syncedMatch.duelId] = syncedMatch;
                _listenToDuelChannel(syncedMatch.duelId);

                _updateMatch(localMatch.duelId, syncedMatch);
                _updateMatch(syncedMatch.duelId, syncedMatch);

                Timer(const Duration(milliseconds: 2500), () {
                  _startRound(syncedMatch.duelId, 0);
                });
                break;
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

            if (userId != null) {
              _applyDuelAnswerLocally(
                duelId: duelId,
                userId: userId,
                questionIndex: questionIndex,
                optionIndex: optionIndex,
                responseTimeMs: responseTimeMs,
              );
            }
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
            'player2': {
              'userId': userId,
              'displayName': displayName,
              'avatarUrl': avatarUrl,
            },
          },
        },
      );

      Timer(const Duration(milliseconds: 2500), () {
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

    final aiNames = [
      'Syllabot Scholar',
      'Wuke Anjolaoluwa Omotoyosi ⚡',
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

  void _applyDuelAnswerLocally({
    required String duelId,
    required String userId,
    required int questionIndex,
    required int optionIndex,
    required int responseTimeMs,
  }) {
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

  /// Submits an answer for player 1 or player 2.
  Future<void> submitDuelAnswer({
    required String duelId,
    required String userId,
    required int questionIndex,
    required int optionIndex,
    required int responseTimeMs,
  }) async {
    _applyDuelAnswerLocally(
      duelId: duelId,
      userId: userId,
      questionIndex: questionIndex,
      optionIndex: optionIndex,
      responseTimeMs: responseTimeMs,
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

    final updated = current.copyWith(status: QuizDuelStatus.roundSummary);
    _updateMatch(duelId, updated);

    // Show round summary briefly (600ms), then proceed immediately to next question
    Timer(const Duration(milliseconds: 600), () {
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
