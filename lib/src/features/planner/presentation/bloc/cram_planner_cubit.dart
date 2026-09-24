import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/planner/domain/use_cases/calculate_daily_cram_target_use_case.dart';
import 'package:kortex/src/features/planner/domain/use_cases/create_exam_countdown_use_case.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';

class CramPlannerCubit extends Cubit<CramPlannerState> {
  CramPlannerCubit({
    required PlannerRepository plannerRepository,
    CalculateDailyCramTargetUseCase? calculateTargetUseCase,
    CreateExamCountdownUseCase? createExamUseCase,
    CramWorkloadCalculator? calculator,
  }) : _repository = plannerRepository,
       _calculateTargetUseCase =
           calculateTargetUseCase ?? const CalculateDailyCramTargetUseCase(),
       _createExamUseCase =
           createExamUseCase ?? CreateExamCountdownUseCase(plannerRepository),
       _calculator = calculator ?? const CramWorkloadCalculator(),
       super(const CramPlannerState()) {
    _initDecksListener();
  }

  final PlannerRepository _repository;
  final CalculateDailyCramTargetUseCase _calculateTargetUseCase;
  final CreateExamCountdownUseCase _createExamUseCase;
  final CramWorkloadCalculator _calculator;
  StreamSubscription<DecksState>? _decksSubscription;

  void _initDecksListener() {
    if (locator.isRegistered<DecksBloc>()) {
      _decksSubscription = locator<DecksBloc>().stream.listen((decksState) {
        if (state.activeExams.isNotEmpty) {
          final calibrated = _calibrateExamsWithLiveData(
            state.activeExams,
            decks: decksState.allDecks,
          );
          final (totalDaily, estMins, topPriorityId) =
              _computeAggregates(calibrated);
          final primary = state.selectedExam != null
              ? calibrated.firstWhere(
                  (e) => e.id == state.selectedExam!.id,
                  orElse: () => calibrated.first,
                )
              : (calibrated.isNotEmpty ? calibrated.first : null);
          emit(
            state.copyWith(
              activeExams: calibrated,
              selectedExam: primary,
              dynamicDailyTarget:
                  primary?.dailyTarget ?? state.dynamicDailyTarget,
              totalCombinedDailyTarget: totalDaily,
              estimatedDailyMinutes: estMins,
              topPriorityExamId: topPriorityId,
            ),
          );
        }
      });
    }
  }

  @override
  Future<void> close() async {
    await _decksSubscription?.cancel();
    return super.close();
  }

  (int totalDaily, int estMinutes, String? topPriorityId) _computeAggregates(
    List<ExamEventEntity> exams,
  ) {
    final active = exams.where((e) => !e.isCompleted && !e.isPast).toList();
    final totalDaily = _calculator.calculateTotalDailyWorkload(active);
    final estMinutes = _calculator.calculateEstimatedDailyMinutes(totalDaily);

    String? topPriorityId;
    var maxScore = -1.0;
    for (final e in active) {
      final score = _calculator.calculatePriorityScore(exam: e);
      if (score > maxScore) {
        maxScore = score;
        topPriorityId = e.id;
      }
    }

    return (totalDaily, estMinutes, topPriorityId);
  }

  /// Calibrates exam entities with live deck card counts, actual mastery rates,
  /// and due retention metrics from [DecksBloc] or [UserActivityService].
  List<ExamEventEntity> _calibrateExamsWithLiveData(
    List<ExamEventEntity> exams, {
    List<DeckEntity>? decks,
  }) {
    final allDecks = decks ??
        (locator.isRegistered<DecksBloc>()
            ? locator<DecksBloc>().state.allDecks
            : const <DeckEntity>[]);

    return exams.map((exam) {
      if (allDecks.isNotEmpty) {
        final matchingDecks = <DeckEntity>[];
        if (exam.scopedDeckIds.isNotEmpty) {
          for (final deckId in exam.scopedDeckIds) {
            matchingDecks.addAll(allDecks.where((d) => d.id == deckId));
          }
        }

        // If no explicit scoped decks, match by smart tokens & subject/course track
        if (matchingDecks.isEmpty) {
          final examText = '${exam.subjectTrack} ${exam.examName}'.toLowerCase();
          final examTokens = RegExp('[a-zA-Z0-9]+')
              .allMatches(examText)
              .map((m) => m.group(0)!)
              .where((t) =>
                  t.length >= 2 &&
                  !const {
                    'exam',
                    'test',
                    'final',
                    'midterm',
                    'the',
                    'and',
                    'for',
                    'course',
                    'academic',
                  }.contains(t))
              .toSet();

          for (final d in allDecks) {
            final deckText =
                '${d.courseCode ?? ""} ${d.subject} ${d.title}'.toLowerCase();
            final deckTokens = RegExp('[a-zA-Z0-9]+')
                .allMatches(deckText)
                .map((m) => m.group(0)!)
                .where((t) =>
                    t.length >= 2 &&
                    !const {
                      'exam',
                      'test',
                      'final',
                      'midterm',
                      'the',
                      'and',
                      'for',
                      'course',
                      'academic',
                    }.contains(t))
                .toSet();

            final hasCommonToken = examTokens.any(deckTokens.contains);
            final directSubstring = (d.courseCode != null &&
                    d.courseCode!.isNotEmpty &&
                    examText.contains(d.courseCode!.toLowerCase())) ||
                (d.subject.isNotEmpty &&
                    (examText.contains(d.subject.toLowerCase()) ||
                        d.subject.toLowerCase().contains(exam.subjectTrack.toLowerCase())));

            if (hasCommonToken || directSubstring) {
              matchingDecks.add(d);
            }
          }

          // If still empty and the user has only 1 deck, associate it naturally
          if (matchingDecks.isEmpty && allDecks.length == 1) {
            matchingDecks.add(allDecks.first);
          }
        }

        if (matchingDecks.isNotEmpty) {
          final totalCards = matchingDecks.fold<int>(
            0,
            (sum, d) => sum + d.totalCards,
          );
          final masteredCards = matchingDecks.fold<int>(
            0,
            (sum, d) => sum + (d.totalCards * d.masteryRate).round(),
          );
          final totalLapses = matchingDecks.fold<int>(
            0,
            (sum, d) => sum + d.dueCards,
          );
          final days = exam.daysRemaining <= 0 ? 1 : exam.daysRemaining;
          final remaining = (totalCards - masteredCards).clamp(0, totalCards);
          final dailyPace = _calculateTargetUseCase(
            remainingCards: remaining,
            lapses: totalLapses,
            daysRemaining: days,
          );

          final scopedIds = exam.scopedDeckIds.isNotEmpty
              ? exam.scopedDeckIds
              : matchingDecks.map((d) => d.id).toList();

          return exam.copyWith(
            scopedDeckIds: scopedIds,
            totalCardsCount: totalCards > 0 ? totalCards : exam.totalCardsCount,
            masteredCardsCount: masteredCards,
            totalLapses: totalLapses,
            dailyTarget: dailyPace,
          );
        }
      }

      // Check UserActivityService if available
      if (locator.isRegistered<UserActivityService>()) {
        final totalMastered =
            locator<UserActivityService>().getTotalCardsMastered();
        if (totalMastered > 0) {
          final total =
              exam.totalCardsCount > 0 ? exam.totalCardsCount : totalMastered;
          final mastered = totalMastered.clamp(0, total);
          final remaining = (total - mastered).clamp(0, total);
          final dailyPace = _calculateTargetUseCase(
            remainingCards: remaining,
            lapses: exam.totalLapses,
            daysRemaining: exam.daysRemaining <= 0 ? 1 : exam.daysRemaining,
          );
          return exam.copyWith(
            totalCardsCount: total,
            masteredCardsCount: mastered,
            dailyTarget: dailyPace,
          );
        }
      }

      // If truly no decks and no activity, reflect real state (not dummy 50)
      if (allDecks.isEmpty &&
          exam.totalCardsCount == 50 &&
          exam.masteredCardsCount == 0) {
        return exam.copyWith(
          totalCardsCount: 0,
          masteredCardsCount: 0,
          dailyTarget: 0,
        );
      }

      return exam;
    }).toList();
  }

  /// Loads active exams and calculates initial urgency for the closest exam.
  Future<void> loadExams() async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    var allDecks = locator.isRegistered<DecksBloc>()
        ? locator<DecksBloc>().state.allDecks
        : const <DeckEntity>[];

    if (allDecks.isEmpty && locator.isRegistered<GetUserDecksUseCase>()) {
      try {
        final decksRes = await locator<GetUserDecksUseCase>()(const NoParams());
        decksRes.fold(
          (_) {},
          (fetched) => allDecks = fetched,
        );
      } on Object catch (_) {}
    }

    final result = await _repository.getActiveExams();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CramPlannerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (exams) {
        final calibrated = _calibrateExamsWithLiveData(exams, decks: allDecks);
        final sorted = List<ExamEventEntity>.from(calibrated)
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        final primaryExam = sorted.isNotEmpty ? sorted.first : null;
        var pace = 20;
        var urgency = ExamUrgencyLevel.normal;

        if (primaryExam != null) {
          pace = primaryExam.dailyTarget > 0
              ? primaryExam.dailyTarget
              : _calculateTargetUseCase(
                  remainingCards: primaryExam.remainingCards,
                  lapses: primaryExam.totalLapses,
                  daysRemaining: primaryExam.daysRemaining,
                );
          urgency = _calculator.getUrgencyLevel(
            primaryExam.daysRemaining,
            type: primaryExam.assessmentType,
          );
        }

        final (totalDaily, estMins, topPriorityId) =
            _computeAggregates(sorted);

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: sorted,
            selectedExam: primaryExam,
            clearSelectedExam: primaryExam == null,
            dynamicDailyTarget: pace,
            totalCombinedDailyTarget: totalDaily,
            estimatedDailyMinutes: estMins,
            topPriorityExamId: topPriorityId,
            urgencyLevel: urgency,
          ),
        );
      },
    );
  }

  /// Adds a new exam/assessment countdown and recalculates workload.
  Future<void> addExamCountdown({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    AssessmentType assessmentType = AssessmentType.finalExam,
    List<String> scopedDeckIds = const [],
    List<String> scopedTopics = const [],
    double? weightPercent,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  }) async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    final result = await _createExamUseCase(
      examName: examName,
      targetDate: targetDate,
      subjectTrack: subjectTrack,
      assessmentType: assessmentType,
      scopedDeckIds: scopedDeckIds,
      scopedTopics: scopedTopics,
      weightPercent: weightPercent,
      totalCardsCount: totalCardsCount,
      targetScorePercent: targetScorePercent,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CramPlannerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (newExam) {
        final rawList = List<ExamEventEntity>.from(state.activeExams)
          ..add(newExam);
        final updatedList = _calibrateExamsWithLiveData(rawList)
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        final primary = updatedList.first;
        final pace = primary.dailyTarget;
        final urgency = _calculator.getUrgencyLevel(
          primary.daysRemaining,
          type: primary.assessmentType,
        );

        final (totalDaily, estMins, topPriorityId) =
            _computeAggregates(updatedList);

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: updatedList,
            selectedExam: primary,
            dynamicDailyTarget: pace,
            totalCombinedDailyTarget: totalDaily,
            estimatedDailyMinutes: estMins,
            topPriorityExamId: topPriorityId,
            urgencyLevel: urgency,
          ),
        );
      },
    );
  }

  /// Dynamically recalculates pace when reviews are missed or lapses occur.
  void recalculatePace({required int lapses}) {
    if (state.selectedExam == null) return;
    final exam = state.selectedExam!;

    final adjustedPace = _calculateTargetUseCase(
      remainingCards: exam.remainingCards,
      lapses: lapses,
      daysRemaining: exam.daysRemaining,
    );

    emit(
      state.copyWith(
        dynamicDailyTarget: adjustedPace,
        urgencyLevel: _calculator.getUrgencyLevel(
          exam.daysRemaining,
          type: exam.assessmentType,
        ),
      ),
    );
  }

  /// Automatically rebalances daily study pacing to prevent cram burnout
  /// or unmanageable spikes after missed study days. Caps maximum daily target to 45 cards
  /// and spreads remaining workload smoothly across available preparation days.
  void autoRebalanceTargets() {
    if (state.selectedExam == null) return;
    final exam = state.selectedExam!;

    final days = exam.daysRemaining <= 0 ? 1 : exam.daysRemaining;
    final baseDaily = (exam.remainingCards / days).ceil();
    final balancedTarget = baseDaily.clamp(10, 45);

    emit(
      state.copyWith(
        dynamicDailyTarget: balancedTarget,
        urgencyLevel: _calculator.getUrgencyLevel(
          exam.daysRemaining,
          type: exam.assessmentType,
        ),
      ),
    );
  }

  /// Updates an existing exam countdown.
  Future<void> updateExamCountdown({
    required String examId,
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    AssessmentType? assessmentType,
    List<String>? scopedDeckIds,
    List<String>? scopedTopics,
    double? weightPercent,
    int? totalCardsCount,
    int? masteredCardsCount,
    int? totalLapses,
    double? targetScorePercent,
    bool? isCompleted,
    double? achievedScorePercent,
  }) async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    final result = await _repository.updateExam(
      examId: examId,
      examName: examName,
      targetDate: targetDate,
      subjectTrack: subjectTrack,
      assessmentType: assessmentType,
      scopedDeckIds: scopedDeckIds,
      scopedTopics: scopedTopics,
      weightPercent: weightPercent,
      totalCardsCount: totalCardsCount,
      masteredCardsCount: masteredCardsCount,
      totalLapses: totalLapses,
      targetScorePercent: targetScorePercent,
      isCompleted: isCompleted,
      achievedScorePercent: achievedScorePercent,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CramPlannerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (updatedExam) {
        final rawList =
            state.activeExams
                .map((e) => e.id == examId ? updatedExam : e)
                .toList();
        final updatedList = _calibrateExamsWithLiveData(rawList)
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        final primary = updatedList.firstWhere(
          (e) => e.id == examId,
          orElse: () => (state.selectedExam?.id == examId)
              ? updatedExam
              : (updatedList.isNotEmpty ? updatedList.first : updatedExam),
        );

        final pace = primary.dailyTarget;
        final urgency = _calculator.getUrgencyLevel(
          primary.daysRemaining,
          type: primary.assessmentType,
        );

        final (totalDaily, estMins, topPriorityId) =
            _computeAggregates(updatedList);

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: updatedList,
            selectedExam: primary,
            dynamicDailyTarget: pace,
            totalCombinedDailyTarget: totalDaily,
            estimatedDailyMinutes: estMins,
            topPriorityExamId: topPriorityId,
            urgencyLevel: urgency,
          ),
        );
      },
    );
  }

  /// Concludes and records the final grade of an assessment, archiving it
  /// and optionally rolling over lapsed / unmastered cards to subsequent exams.
  Future<void> completeAssessment({
    required String examId,
    required double scorePercent,
    bool rolloverWeakCards = true,
  }) async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    final result = await _repository.completeExam(
      examId: examId,
      scorePercent: scorePercent,
      rolloverWeakCards: rolloverWeakCards,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CramPlannerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (completedExam) {
        final updatedList =
            state.activeExams
                .map((e) => e.id == examId ? completedExam : e)
                .toList()
              ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        // Primary becomes the next upcoming uncompleted exam if available
        final uncompleted =
            updatedList.where((e) => !e.isCompleted && !e.isPast).toList();
        final primary = uncompleted.isNotEmpty ? uncompleted.first : null;

        var pace = 20;
        var urgency = ExamUrgencyLevel.normal;
        if (primary != null) {
          pace = _calculateTargetUseCase(
            remainingCards: primary.remainingCards,
            lapses: primary.totalLapses,
            daysRemaining: primary.daysRemaining,
          );
          urgency = _calculator.getUrgencyLevel(
            primary.daysRemaining,
            type: primary.assessmentType,
          );
        }

        final (totalDaily, estMins, topPriorityId) =
            _computeAggregates(updatedList);

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: updatedList,
            selectedExam: primary,
            clearSelectedExam: primary == null,
            dynamicDailyTarget: pace,
            totalCombinedDailyTarget: totalDaily,
            estimatedDailyMinutes: estMins,
            topPriorityExamId: topPriorityId,
            urgencyLevel: urgency,
          ),
        );
      },
    );
  }

  /// Reopens a previously completed assessment back into active study planning.
  Future<void> reopenAssessment(String examId) async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    final result = await _repository.reopenExam(examId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CramPlannerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (reopenedExam) {
        final updatedList =
            state.activeExams
                .map((e) => e.id == examId ? reopenedExam : e)
                .toList()
              ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        final primary = reopenedExam;
        final pace = _calculateTargetUseCase(
          remainingCards: primary.remainingCards,
          lapses: primary.totalLapses,
          daysRemaining: primary.daysRemaining,
        );
        final urgency = _calculator.getUrgencyLevel(
          primary.daysRemaining,
          type: primary.assessmentType,
        );

        final (totalDaily, estMins, topPriorityId) =
            _computeAggregates(updatedList);

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: updatedList,
            selectedExam: primary,
            dynamicDailyTarget: pace,
            totalCombinedDailyTarget: totalDaily,
            estimatedDailyMinutes: estMins,
            topPriorityExamId: topPriorityId,
            urgencyLevel: urgency,
          ),
        );
      },
    );
  }

  /// Deletes an exam countdown.
  Future<void> deleteExamCountdown(String examId) async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    final result = await _repository.deleteExam(examId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CramPlannerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (_) {
        final updatedList =
            state.activeExams.where((e) => e.id != examId).toList()
              ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        final primary = updatedList.isNotEmpty ? updatedList.first : null;
        var pace = 20;
        var urgency = ExamUrgencyLevel.normal;

        if (primary != null) {
          pace = _calculateTargetUseCase(
            remainingCards: primary.remainingCards,
            lapses: primary.totalLapses,
            daysRemaining: primary.daysRemaining,
          );
          urgency = _calculator.getUrgencyLevel(
            primary.daysRemaining,
            type: primary.assessmentType,
          );
        }

        final (totalDaily, estMins, topPriorityId) =
            _computeAggregates(updatedList);

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: updatedList,
            selectedExam: primary,
            clearSelectedExam: primary == null,
            dynamicDailyTarget: pace,
            totalCombinedDailyTarget: totalDaily,
            estimatedDailyMinutes: estMins,
            topPriorityExamId: topPriorityId,
            urgencyLevel: urgency,
          ),
        );
      },
    );
  }

  /// Selects which exam is active in the banner.
  void selectExam(String examId) {
    final match = state.activeExams.where((e) => e.id == examId).firstOrNull;
    if (match == null) return;

    final pace = _calculateTargetUseCase(
      remainingCards: match.remainingCards,
      lapses: match.totalLapses,
      daysRemaining: match.daysRemaining,
    );
    final urgency = _calculator.getUrgencyLevel(
      match.daysRemaining,
      type: match.assessmentType,
    );

    emit(
      state.copyWith(
        selectedExam: match,
        dynamicDailyTarget: pace,
        urgencyLevel: urgency,
      ),
    );
  }
}
