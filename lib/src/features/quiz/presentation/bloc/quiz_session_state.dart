import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';

enum QuizSessionStatus {
  initial,
  loading,
  inProgress,
  questionAnswered,
  completed,
  error,
}

enum AssessmentMode {
  discoveryMode,      // Formative learning: immediate explanations, hint support, low stakes
  examSimulationMode, // Summative testing: timed, strict, no hints until results
  millionaireMode,    // Gamified tiered ladder with safe milestones & lifelines
}

enum MillionaireScope {
  courseTied,   // Curriculum-aligned mastery milestone for a specific course/deck
  globalArcade, // Cross-subject randomized dopamine climb
}

enum LifelineType {
  fiftyFifty,  // Eliminates two incorrect options
  aiClue,      // Socratic hint from Syllabot / AI tutor
  askAudience, // Crowd wisdom / simulated confidence distribution
  skipSwap,    // Skips current question without penalty
}

class QuizSessionState extends Equatable {
  const QuizSessionState({
    this.status = QuizSessionStatus.initial,
    this.quizTitle = 'Practice Quiz',
    this.questions = const [],
    this.currentIndex = 0,
    this.elapsedSeconds = 0,
    this.durationMinutes,
    this.flaggedQuestionIds = const {},
    this.assessmentMode = AssessmentMode.discoveryMode,
    this.isHintRevealed = false,
    this.hintsUsedCount = 0,
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
  final String quizTitle;
  final List<QuizQuestionEntity> questions;
  final int currentIndex;
  final int elapsedSeconds;
  final int? durationMinutes;
  final Set<String> flaggedQuestionIds;
  final AssessmentMode assessmentMode;
  final bool isHintRevealed;
  final int hintsUsedCount;
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

  bool get isCurrentQuestionFlagged => isQuestionFlagged(currentQuestion?.id);

  int get remainingSeconds {
    if (durationMinutes == null) return 0;
    final totalSecs = durationMinutes! * 60;
    return totalSecs - elapsedSeconds;
  }

  bool get isTimeExpired => durationMinutes != null && remainingSeconds <= 0;

  bool get isTimeRunningLow =>
      durationMinutes != null && remainingSeconds > 0 && remainingSeconds <= 300;

  String get formattedTimer {
    final secs = durationMinutes != null
        ? (remainingSeconds < 0 ? 0 : remainingSeconds)
        : elapsedSeconds;
    final minutes = (secs ~/ 60).toString().padLeft(2, '0');
    final seconds = (secs % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // --- Millionaire Ladder Constants & Helpers ---
  static const List<int> millionaireTiersXp = [
    100, 200, 300, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000, 125000,
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

  bool get isCurrentTierSafeCheckpoint => safeCheckpointTiers.contains(currentTier);

  bool isLifelineAvailable(LifelineType type) =>
      availableLifelines[type] ?? false;

  bool isOptionEliminated(int optionIndex) =>
      eliminatedOptionIndices.contains(optionIndex);

  QuizSessionState copyWith({
    QuizSessionStatus? status,
    String? quizTitle,
    List<QuizQuestionEntity>? questions,
    int? currentIndex,
    int? elapsedSeconds,
    int? durationMinutes,
    Set<String>? flaggedQuestionIds,
    AssessmentMode? assessmentMode,
    bool? isHintRevealed,
    int? hintsUsedCount,
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
      quizTitle: quizTitle ?? this.quizTitle,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
      assessmentMode: assessmentMode ?? this.assessmentMode,
      isHintRevealed: isHintRevealed ?? this.isHintRevealed,
      hintsUsedCount: hintsUsedCount ?? this.hintsUsedCount,
      result: result ?? this.result,
      errorMessage: errorMessage,
      currentTier: currentTier ?? this.currentTier,
      bankedTier: bankedTier ?? this.bankedTier,
      millionaireScope: millionaireScope ?? this.millionaireScope,
      availableLifelines: availableLifelines ?? this.availableLifelines,
      eliminatedOptionIndices: eliminatedOptionIndices ?? this.eliminatedOptionIndices,
      activeClueText: clearActiveClue ? null : (activeClueText ?? this.activeClueText),
      audienceDistribution: clearAudienceDistribution ? null : (audienceDistribution ?? this.audienceDistribution),
      speedBonusXp: speedBonusXp ?? this.speedBonusXp,
      questionStartTimeSeconds: questionStartTimeSeconds ?? this.questionStartTimeSeconds,
      hasSecondChance: hasSecondChance ?? this.hasSecondChance,
      isSecondChanceActive: isSecondChanceActive ?? this.isSecondChanceActive,
      isWalkedAway: isWalkedAway ?? this.isWalkedAway,
      isSoftFailed: isSoftFailed ?? this.isSoftFailed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    quizTitle,
    questions,
    currentIndex,
    elapsedSeconds,
    durationMinutes,
    flaggedQuestionIds,
    assessmentMode,
    isHintRevealed,
    hintsUsedCount,
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
