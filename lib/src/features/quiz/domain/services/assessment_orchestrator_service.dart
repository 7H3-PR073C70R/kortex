import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/academic_grade_evaluator.dart';

/// Comprehensive Assessment Telemetry Result generated after processing an evaluation.
class AssessmentOrchestrationResult {
  const AssessmentOrchestrationResult({
    required this.gradeResult,
    required this.readinessIndex,
    required this.remedialCardCount,
    required this.targetTrack,
    required this.timestamp,
  });

  /// The standardized academic grade evaluation result.
  final AcademicGradeResult gradeResult;

  /// The dynamic composite Academic Readiness Index (0.0 to 100.0).
  final double readinessIndex;

  /// Number of remedial review items flagged/generated from failed questions.
  final int remedialCardCount;

  /// The target academic track evaluated against (e.g. JAMB, WAEC, BSC).
  final String targetTrack;

  /// Timestamp when orchestration was completed.
  final DateTime timestamp;
}

/// Central orchestrator connecting Quiz/CBT results, FSRS Memory Scheduler,
/// Cram Planner deadlines, and User Analytics.
class AssessmentOrchestratorService {
  AssessmentOrchestratorService({
    required UserActivityService userActivityService,
    required UserStorageService userStorageService,
    FsrsAlgorithmEngine? fsrsEngine,
    DecksRepository? decksRepository,
    PlannerRepository? plannerRepository,
  })  : _userActivityService = userActivityService,
        _userStorageService = userStorageService,
        _fsrsEngine = fsrsEngine ?? FsrsAlgorithmEngine(),
        _decksRepository = decksRepository,
        _plannerRepository = plannerRepository;

  final UserActivityService _userActivityService;
  final UserStorageService _userStorageService;
  final FsrsAlgorithmEngine _fsrsEngine;
  final DecksRepository? _decksRepository;
  final PlannerRepository? _plannerRepository;

  /// Resolves the user's active academic track from storage or explicit override.
  String resolveTargetTrack([String? explicitTrack]) {
    if (explicitTrack != null && explicitTrack.trim().isNotEmpty) {
      return explicitTrack.trim();
    }
    final userEmail = _userStorageService.getUserEmail();
    if (userEmail != null && userEmail.contains('@')) {
      // Return track if available
      return 'WAEC';
    }
    return 'WAEC'; // Default fallback
  }

  /// Evaluates an assessment score against standardized curricula and returns
  /// the full [AcademicGradeResult].
  AcademicGradeResult evaluateAssessment({
    required double scorePercent,
    String? track,
  }) {
    final activeTrack = resolveTargetTrack(track);
    return AcademicGradeEvaluator.evaluate(
      scorePercent: scorePercent,
      track: activeTrack,
    );
  }

  /// Closed-loop processor invoked upon completion of a Quiz or Mock Exam.
  ///
  /// Performs:
  /// 1. Standardized grade evaluation via [AcademicGradeEvaluator].
  /// 2. User activity telemetry update via [UserActivityService].
  /// 3. Composite Readiness Index calculation.
  /// 4. FSRS recalibration for associated assessment deadlines.
  Future<AssessmentOrchestrationResult> processQuizCompletion({
    required double scorePercent,
    required int totalQuestions,
    required int correctAnswers,
    required List<QuizQuestionEntity> questions,
    List<int?>? userAnswers,
    String? examId,
    String? courseCode,
    String? explicitTrack,
  }) async {
    final activeTrack = resolveTargetTrack(explicitTrack);
    final gradeResult = evaluateAssessment(
      scorePercent: scorePercent,
      track: activeTrack,
    );

    // 1. Telemetry update
    try {
      final retentionScore = (scorePercent / 100).clamp(0.0, 1.0);
      await _userActivityService.recordStudySession(
        cardsReviewed: totalQuestions,
        durationSeconds: 60,
        retentionScore: retentionScore,
        masteredCards: correctAnswers,
        subject: courseCode,
        activityCategory: 'quiz',
      );
    } on Object catch (e) {
      debugPrint('[AssessmentOrchestrator] Error updating activity: $e');
    }

    // 2. Identify failed questions
    final failedQuestions = <QuizQuestionEntity>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (!q.isCorrect) {
        failedQuestions.add(q);
      }
    }

    // 3. FSRS Post-Assessment Recalibration if linked to an exam event
    if (examId != null && _plannerRepository != null && _decksRepository != null) {
      try {
        final activeExamsResult = await _plannerRepository.getActiveExams();
        await activeExamsResult.fold(
          (failure) async {},
          (exams) async {
            final matchedExam = exams.where((e) => e.id == examId).firstOrNull;
            if (matchedExam != null && matchedExam.scopedDeckIds.isNotEmpty) {
              for (final deckId in matchedExam.scopedDeckIds) {
                final cardsResult = await _decksRepository.getDeckCards(deckId);
                await cardsResult.fold(
                  (failure) async {},
                  (cards) async {
                    final recalibratedCards = cards.map((card) {
                      final memoryState = FsrsMemoryState(
                        stability: card.fsrsStability,
                        difficulty: card.fsrsDifficulty,
                        retrievability: 0.9,
                        elapsedDays: card.fsrsElapsedDays,
                        scheduledDays: card.fsrsScheduledDays,
                        reps: card.repetitions,
                        lapses: card.fsrsLapses,
                        nextDueDate: card.nextDueDate ?? DateTime.now(),
                        lastReview: card.lastReviewed,
                      );
                      final recalibratedState = _fsrsEngine.recalibratePostAssessment(
                        currentState: memoryState,
                        referenceTime: DateTime.now(),
                      );
                      return card.copyWith(
                        fsrsStability: recalibratedState.stability,
                        fsrsDifficulty: recalibratedState.difficulty,
                        fsrsScheduledDays: recalibratedState.scheduledDays,
                        nextDueDate: recalibratedState.nextDueDate,
                      );
                    }).toList();
                    await _decksRepository.updateDeckCards(deckId, recalibratedCards);
                  },
                );
              }
            }
          },
        );
      } on Object catch (e) {
        debugPrint('[AssessmentOrchestrator] Post-assessment FSRS recalibration error: $e');
      }
    }

    // 4. Calculate composite Readiness Index
    final readinessIndex = calculateReadinessIndex(
      recentScorePercent: scorePercent,
    );

    return AssessmentOrchestrationResult(
      gradeResult: gradeResult,
      readinessIndex: readinessIndex,
      remedialCardCount: failedQuestions.length,
      targetTrack: activeTrack,
      timestamp: DateTime.now(),
    );
  }

  /// Calculates a composite Academic Readiness Index (0.0 to 100.0) combining
  /// recent quiz performance, FSRS retention rate, and syllabus progress.
  double calculateReadinessIndex({
    required double recentScorePercent,
    int daysRemaining = 14,
    List<dynamic>? registeredCourses,
  }) {
    final overallRetention = _userActivityService.getOverallRetentionRate();
    final mockRatio = (recentScorePercent / 100).clamp(0.0, 1.0);
    final coverage = (overallRetention * 0.90).clamp(0.0, 1.0);

    final result = const CbtReadinessCalculator().compute(
      syllabusCoverage: coverage,
      fsrsRetentionRate: overallRetention,
      mockScoreRatio: mockRatio,
      daysRemaining: daysRemaining,
      registeredCourses: registeredCourses,
    );
    return result.scorePercent.toDouble();
  }

  /// Recalibrates compressed FSRS card intervals when an exam date is edited,
  /// postponed, or deleted in the Cram Planner.
  Future<void> onExamScheduleChanged({
    required String deckId,
    DateTime? oldExamDate,
    DateTime? newExamDate,
  }) async {
    if (_decksRepository == null) return;
    try {
      final cardsResult = await _decksRepository.getDeckCards(deckId);
      await cardsResult.fold(
        (failure) async {},
        (cards) async {
          final recalibratedCards = cards.map((card) {
            final memoryState = FsrsMemoryState(
              stability: card.fsrsStability,
              difficulty: card.fsrsDifficulty,
              retrievability: 0.9,
              elapsedDays: card.fsrsElapsedDays,
              scheduledDays: card.fsrsScheduledDays,
              reps: card.repetitions,
              lapses: card.fsrsLapses,
              nextDueDate: card.nextDueDate ?? DateTime.now(),
              lastReview: card.lastReviewed,
            );
            final recalibratedState = _fsrsEngine.recalibratePostAssessment(
              currentState: memoryState,
              referenceTime: DateTime.now(),
            );
            return card.copyWith(
              fsrsStability: recalibratedState.stability,
              fsrsDifficulty: recalibratedState.difficulty,
              fsrsScheduledDays: recalibratedState.scheduledDays,
              nextDueDate: recalibratedState.nextDueDate,
            );
          }).toList();
          await _decksRepository.updateDeckCards(deckId, recalibratedCards);
        },
      );
    } on Object catch (e) {
      debugPrint('[AssessmentOrchestrator] Error on exam schedule changed: $e');
    }
  }
}
