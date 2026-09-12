import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';

/// Status of a 1v1 Quiz Duel match.
enum QuizDuelStatus {
  matching,
  countdown,
  inRound,
  roundSummary,
  finished,
  cancelled,
}

/// Represents a player participating in a 1v1 Quiz Duel.
class QuizDuelParticipant extends Equatable {
  const QuizDuelParticipant({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.score = 0,
    this.currentQuestionIndex = 0,
    this.selectedOptionIndex,
    this.answeredInMs,
    this.isAnswerCorrect,
    this.comboStreak = 0,
    this.isReady = false,
    this.isAiOpponent = false,
    this.hasFinished = false,
    this.eloRating = 1200,
  });

  factory QuizDuelParticipant.fromJson(Map<String, dynamic> json) {
    return QuizDuelParticipant(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Scholar',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      currentQuestionIndex: json['currentQuestionIndex'] as int? ?? 0,
      selectedOptionIndex: json['selectedOptionIndex'] as int?,
      answeredInMs: json['answeredInMs'] as int?,
      isAnswerCorrect: json['isAnswerCorrect'] as bool?,
      comboStreak: json['comboStreak'] as int? ?? 0,
      isReady: json['isReady'] as bool? ?? false,
      isAiOpponent: json['isAiOpponent'] as bool? ?? false,
      hasFinished: json['hasFinished'] as bool? ?? false,
      eloRating: json['eloRating'] as int? ?? 1200,
    );
  }

  final String userId;
  final String displayName;
  final String avatarUrl;
  final int score;
  final int currentQuestionIndex;
  final int? selectedOptionIndex;
  final int? answeredInMs;
  final bool? isAnswerCorrect;
  final int comboStreak;
  final bool isReady;
  final bool isAiOpponent;
  final bool hasFinished;
  final int eloRating;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'score': score,
      'currentQuestionIndex': currentQuestionIndex,
      'selectedOptionIndex': selectedOptionIndex,
      'answeredInMs': answeredInMs,
      'isAnswerCorrect': isAnswerCorrect,
      'comboStreak': comboStreak,
      'isReady': isReady,
      'isAiOpponent': isAiOpponent,
      'hasFinished': hasFinished,
      'eloRating': eloRating,
    };
  }

  QuizDuelParticipant copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    int? score,
    int? currentQuestionIndex,
    int? selectedOptionIndex,
    int? answeredInMs,
    bool? isAnswerCorrect,
    int? comboStreak,
    bool? isReady,
    bool? isAiOpponent,
    bool? hasFinished,
    int? eloRating,
  }) {
    return QuizDuelParticipant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      score: score ?? this.score,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      answeredInMs: answeredInMs ?? this.answeredInMs,
      isAnswerCorrect: isAnswerCorrect ?? this.isAnswerCorrect,
      comboStreak: comboStreak ?? this.comboStreak,
      isReady: isReady ?? this.isReady,
      isAiOpponent: isAiOpponent ?? this.isAiOpponent,
      hasFinished: hasFinished ?? this.hasFinished,
      eloRating: eloRating ?? this.eloRating,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        displayName,
        avatarUrl,
        score,
        currentQuestionIndex,
        selectedOptionIndex,
        answeredInMs,
        isAnswerCorrect,
        comboStreak,
        isReady,
        isAiOpponent,
        hasFinished,
        eloRating,
      ];
}

/// Represents a synchronized 1v1 Quiz Duel match.
class QuizDuelMatch extends Equatable {
  const QuizDuelMatch({
    required this.duelId,
    required this.subject,
    required this.examBoard,
    required this.questions,
    this.currentQuestionIndex = 0,
    this.durationPerQuestionSeconds = 15,
    required this.player1,
    this.player2,
    this.status = QuizDuelStatus.matching,
    this.winnerUserId,
    this.isDraw = false,
    this.createdAt,
    this.latestEmote,
    this.latestEmoteSenderId,
  });

  factory QuizDuelMatch.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'] as List<dynamic>? ?? [];
    final questions = questionsRaw.map((q) {
      if (q is Map<String, dynamic>) {
        return QuizQuestionEntity(
          id: q['id'] as String? ?? 'q_0',
          prompt: q['prompt'] as String? ?? '',
          type: QuizQuestionType.multipleChoice,
          options: (q['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          correctAnswer: q['correctAnswer'] as String? ?? '',
          explanation: q['explanation'] as String? ?? '',
          subTopic: q['subTopic'] as String? ?? 'General',
        );
      }
      return q as QuizQuestionEntity;
    }).toList();

    return QuizDuelMatch(
      duelId: json['duelId'] as String? ?? '',
      subject: json['subject'] as String? ?? 'General',
      examBoard: json['examBoard'] as String? ?? 'WAEC',
      questions: questions,
      currentQuestionIndex: json['currentQuestionIndex'] as int? ?? 0,
      durationPerQuestionSeconds: json['durationPerQuestionSeconds'] as int? ?? 15,
      player1: QuizDuelParticipant.fromJson(json['player1'] as Map<String, dynamic>? ?? {}),
      player2: json['player2'] != null
          ? QuizDuelParticipant.fromJson(json['player2'] as Map<String, dynamic>)
          : null,
      status: QuizDuelStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String?),
        orElse: () => QuizDuelStatus.matching,
      ),
      winnerUserId: json['winnerUserId'] as String?,
      isDraw: json['isDraw'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      latestEmote: json['latestEmote'] as String?,
      latestEmoteSenderId: json['latestEmoteSenderId'] as String?,
    );
  }

  final String duelId;
  final String subject;
  final String examBoard;
  final List<QuizQuestionEntity> questions;
  final int currentQuestionIndex;
  final int durationPerQuestionSeconds;
  final QuizDuelParticipant player1;
  final QuizDuelParticipant? player2;
  final QuizDuelStatus status;
  final String? winnerUserId;
  final bool isDraw;
  final DateTime? createdAt;
  final String? latestEmote;
  final String? latestEmoteSenderId;

  QuizQuestionEntity? get currentQuestion =>
      (currentQuestionIndex >= 0 && currentQuestionIndex < questions.length)
          ? questions[currentQuestionIndex]
          : null;

  int get totalQuestions => questions.length;

  bool get isMatchOver => status == QuizDuelStatus.finished;

  Map<String, dynamic> toJson() {
    return {
      'duelId': duelId,
      'subject': subject,
      'examBoard': examBoard,
      'questions': questions
          .map((q) => {
                'id': q.id,
                'prompt': q.prompt,
                'options': q.options,
                'correctAnswer': q.correctAnswer,
                'explanation': q.explanation,
                'subTopic': q.subTopic,
              })
          .toList(),
      'currentQuestionIndex': currentQuestionIndex,
      'durationPerQuestionSeconds': durationPerQuestionSeconds,
      'player1': player1.toJson(),
      if (player2 != null) 'player2': player2!.toJson(),
      'status': status.name,
      if (winnerUserId != null) 'winnerUserId': winnerUserId,
      'isDraw': isDraw,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      if (latestEmote != null) 'latestEmote': latestEmote,
      if (latestEmoteSenderId != null) 'latestEmoteSenderId': latestEmoteSenderId,
    };
  }

  QuizDuelMatch copyWith({
    String? duelId,
    String? subject,
    String? examBoard,
    List<QuizQuestionEntity>? questions,
    int? currentQuestionIndex,
    int? durationPerQuestionSeconds,
    QuizDuelParticipant? player1,
    QuizDuelParticipant? player2,
    QuizDuelStatus? status,
    String? winnerUserId,
    bool? isDraw,
    DateTime? createdAt,
    String? latestEmote,
    String? latestEmoteSenderId,
  }) {
    return QuizDuelMatch(
      duelId: duelId ?? this.duelId,
      subject: subject ?? this.subject,
      examBoard: examBoard ?? this.examBoard,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      durationPerQuestionSeconds:
          durationPerQuestionSeconds ?? this.durationPerQuestionSeconds,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      status: status ?? this.status,
      winnerUserId: winnerUserId ?? this.winnerUserId,
      isDraw: isDraw ?? this.isDraw,
      createdAt: createdAt ?? this.createdAt,
      latestEmote: latestEmote ?? this.latestEmote,
      latestEmoteSenderId: latestEmoteSenderId ?? this.latestEmoteSenderId,
    );
  }

  @override
  List<Object?> get props => [
        duelId,
        subject,
        examBoard,
        questions,
        currentQuestionIndex,
        durationPerQuestionSeconds,
        player1,
        player2,
        status,
        winnerUserId,
        isDraw,
        createdAt,
        latestEmote,
        latestEmoteSenderId,
      ];
}
