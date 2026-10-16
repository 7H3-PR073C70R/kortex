import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';

/// Score percentage at or above which a quiz attempt counts as a pass.
/// Shared by the workspace, results hero and celebration logic so the
/// verdict a student sees never disagrees with the badge they get.
const int kQuizPassScore = 65;

enum QuizSessionStatus {
  initial,
  loading,
  inProgress,
  questionAnswered,
  submitting,
  completed,
  error,
}

enum AssessmentMode {
  discoveryMode, // Formative learning: immediate explanations, hint support, low stakes
  examSimulationMode, // Summative testing: timed, strict, no hints until results
  millionaireMode, // Gamified tiered ladder with safe milestones & lifelines
}

enum MillionaireScope {
  courseTied, // Curriculum-aligned mastery milestone for a specific course/deck
  globalArcade, // Cross-subject randomized dopamine climb
}

enum LifelineType {
  fiftyFifty, // Eliminates two incorrect options
  aiClue, // Socratic hint from Syllabot / AI tutor
  askAudience, // Crowd wisdom / simulated confidence distribution
  skipSwap, // Skips current question without penalty
}

class QuizSessionState extends Equatable {
  const QuizSessionState({
    this.status = QuizSessionStatus.initial,
    this.attemptId,
    this.quizTitle = 'Practice Quiz',
    this.questions = const [],
    this.currentIndex = 0,
    this.elapsedSeconds = 0,
    this.durationMinutes,
    this.startedAt,
    this.deadline,
    this.flaggedQuestionIds = const {},
    this.assessmentMode = AssessmentMode.discoveryMode,
    this.isHintRevealed = false,
    this.hintsUsedCount = 0,
    this.pendingAnswer,
    this.result,
    this.errorMessage,
    this.currentTier = 1,
    this.bankedTier = 0,
    this.millionaireScope,
    this.availableLifelines = const {
      LifelineType.fiftyFifty: true,
      LifelineType.aiClue: true,
      LifelineType.askAudience: true,
      LifelineType.skipSwap: true,
    },
    this.eliminatedOptionIndices = const {},
    this.activeClueText,
    this.audienceDistribution,
    this.speedBonusXp = 0,
    this.questionStartTimeSeconds = 0,
    this.hasSecondChance = true,
    this.isSecondChanceActive = false,
    this.isWalkedAway = false,
    this.isSoftFailed = false,
  });

  final QuizSessionStatus status;
  final String? attemptId;
  final String quizTitle;
  final List<QuizQuestionEntity> questions;
  final int currentIndex;
  final int elapsedSeconds;
  final int? durationMinutes;
  final DateTime? startedAt;
  final DateTime? deadline;
  final Set<String> flaggedQuestionIds;
  final AssessmentMode assessmentMode;
  final bool isHintRevealed;
  final int hintsUsedCount;

  /// Option tapped in practice mode before the student presses Check.
  /// It carries no grading weight until it is committed.
  final String? pendingAnswer;
  final QuizResultEntity? result;
  final String? errorMessage;

  // --- Millionaire Ascent Mode State ---
  final int currentTier;
  final int bankedTier;
  final MillionaireScope? millionaireScope;
  final Map<LifelineType, bool> availableLifelines;
  final Set<int> eliminatedOptionIndices;
  final String? activeClueText;
  final Map<String, int>? audienceDistribution;
  final int speedBonusXp;
  final int questionStartTimeSeconds;
  final bool hasSecondChance;
  final bool isSecondChanceActive;
  final bool isWalkedAway;
  final bool isSoftFailed;

  QuizQuestionEntity? get currentQuestion =>
      currentIndex >= 0 && currentIndex < questions.length
      ? questions[currentIndex]
      : null;

  bool get isLastQuestion =>
      questions.isNotEmpty && currentIndex == questions.length - 1;

  bool get canGoPrevious => currentIndex > 0;
  bool get canGoNext => currentIndex < questions.length - 1;

  int get totalQuestions => questions.length;

  int get answeredCount => questions.where((q) => q.isAnswered).length;

  int get unansweredCount => totalQuestions - answeredCount;

  int get flaggedCount => flaggedQuestionIds.length;

  bool isQuestionFlagged(String? questionId) {
    if (questionId == null) return false;
    return flaggedQuestionIds.contains(questionId);
  }

  bool get hasPendingAnswer => pendingAnswer != null;

  bool get isCurrentQuestionFlagged => isQuestionFlagged(currentQuestion?.id);

  int get remainingSeconds => getRemainingSeconds();

  /// Calculates remaining seconds monotonically, optionally using [at] as the current time.
  int getRemainingSeconds([DateTime? at]) {
    final now = at ?? DateTime.now();
    if (deadline != null) {
      final diff = deadline!.difference(now).inSeconds;
      return diff < 0 ? 0 : diff;
    }
    if (durationMinutes == null) return 0;
    final totalSecs = durationMinutes! * 60;
    final rem = totalSecs - elapsedSeconds;
    return rem < 0 ? 0 : rem;
  }

  bool get isTimeExpired => getIsTimeExpired();

  /// Determines if time is expired, optionally using [at] as the current time.
  bool getIsTimeExpired([DateTime? at]) {
    final now = at ?? DateTime.now();
    if (deadline != null) {
      return now.isAfter(deadline!);
    }
    return durationMinutes != null && getRemainingSeconds(now) <= 0;
  }

  bool get isTimeRunningLow => getIsTimeRunningLow();

  /// Determines if time is running low (<= 5 mins remaining), optionally using [at] as current time.
  bool getIsTimeRunningLow([DateTime? at]) {
    final now = at ?? DateTime.now();
    final rem = getRemainingSeconds(now);
    return (deadline != null || durationMinutes != null) &&
        rem > 0 &&
        rem <= 300;
  }

  String get formattedTimer {
    final secs = (deadline != null || durationMinutes != null)
        ? (remainingSeconds < 0 ? 0 : remainingSeconds)
        : elapsedSeconds;
    final minutes = (secs ~/ 60).toString().padLeft(2, '0');
    final seconds = (secs % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // --- Millionaire Ladder Constants & Helpers ---
  static const List<int> millionaireTiersXp = [
    10,
    20,
    35,
    50,
    75,
    100,
    150,
    200,
    275,
    350,
    425,
    500,
  ];

  static const Set<int> safeCheckpointTiers = {4, 8};

  int get maxMillionaireTier => millionaireTiersXp.length;

  int get currentTierPrizeXp {
    if (currentTier <= 0) return 0;
    final index = (currentTier - 1).clamp(0, millionaireTiersXp.length - 1);
    return millionaireTiersXp[index];
  }

  int get bankedTierPrizeXp {
    if (bankedTier <= 0) return 0;
    final index = (bankedTier - 1).clamp(0, millionaireTiersXp.length - 1);
    return millionaireTiersXp[index];
  }

  bool get isCurrentTierSafeCheckpoint =>
      safeCheckpointTiers.contains(currentTier);

  bool isLifelineAvailable(LifelineType type) =>
      availableLifelines[type] ?? false;

  bool isOptionEliminated(int optionIndex) =>
      eliminatedOptionIndices.contains(optionIndex);

  bool get isSubmitting => status == QuizSessionStatus.submitting;

  QuizSessionState copyWith({
    QuizSessionStatus? status,
    String? attemptId,
    String? quizTitle,
    List<QuizQuestionEntity>? questions,
    int? currentIndex,
    int? elapsedSeconds,
    int? durationMinutes,
    bool clearDurationMinutes = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? deadline,
    bool clearDeadline = false,
    Set<String>? flaggedQuestionIds,
    AssessmentMode? assessmentMode,
    bool? isHintRevealed,
    int? hintsUsedCount,
    String? pendingAnswer,
    bool clearPendingAnswer = false,
    QuizResultEntity? result,
    String? errorMessage,
    int? currentTier,
    int? bankedTier,
    MillionaireScope? millionaireScope,
    Map<LifelineType, bool>? availableLifelines,
    Set<int>? eliminatedOptionIndices,
    String? activeClueText,
    bool clearActiveClue = false,
    Map<String, int>? audienceDistribution,
    bool clearAudienceDistribution = false,
    int? speedBonusXp,
    int? questionStartTimeSeconds,
    bool? hasSecondChance,
    bool? isSecondChanceActive,
    bool? isWalkedAway,
    bool? isSoftFailed,
  }) {
    return QuizSessionState(
      status: status ?? this.status,
      attemptId: attemptId ?? this.attemptId,
      quizTitle: quizTitle ?? this.quizTitle,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      durationMinutes: clearDurationMinutes
          ? null
          : (durationMinutes ?? this.durationMinutes),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
      assessmentMode: assessmentMode ?? this.assessmentMode,
      isHintRevealed: isHintRevealed ?? this.isHintRevealed,
      hintsUsedCount: hintsUsedCount ?? this.hintsUsedCount,
      pendingAnswer: clearPendingAnswer
          ? null
          : (pendingAnswer ?? this.pendingAnswer),
      result: result ?? this.result,
      errorMessage: errorMessage,
      currentTier: currentTier ?? this.currentTier,
      bankedTier: bankedTier ?? this.bankedTier,
      millionaireScope: millionaireScope ?? this.millionaireScope,
      availableLifelines: availableLifelines ?? this.availableLifelines,
      eliminatedOptionIndices:
          eliminatedOptionIndices ?? this.eliminatedOptionIndices,
      activeClueText: clearActiveClue
          ? null
          : (activeClueText ?? this.activeClueText),
      audienceDistribution: clearAudienceDistribution
          ? null
          : (audienceDistribution ?? this.audienceDistribution),
      speedBonusXp: speedBonusXp ?? this.speedBonusXp,
      questionStartTimeSeconds:
          questionStartTimeSeconds ?? this.questionStartTimeSeconds,
      hasSecondChance: hasSecondChance ?? this.hasSecondChance,
      isSecondChanceActive: isSecondChanceActive ?? this.isSecondChanceActive,
      isWalkedAway: isWalkedAway ?? this.isWalkedAway,
      isSoftFailed: isSoftFailed ?? this.isSoftFailed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    attemptId,
    quizTitle,
    questions,
    currentIndex,
    elapsedSeconds,
    durationMinutes,
    startedAt,
    deadline,
    flaggedQuestionIds,
    assessmentMode,
    isHintRevealed,
    hintsUsedCount,
    pendingAnswer,
    result,
    errorMessage,
    currentTier,
    bankedTier,
    millionaireScope,
    availableLifelines,
    eliminatedOptionIndices,
    activeClueText,
    audienceDistribution,
    speedBonusXp,
    questionStartTimeSeconds,
    hasSecondChance,
    isSecondChanceActive,
    isWalkedAway,
    isSoftFailed,
  ];
}
