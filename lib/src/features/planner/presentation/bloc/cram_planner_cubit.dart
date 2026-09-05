import 'package:flutter_bloc/flutter_bloc.dart';
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
       super(const CramPlannerState());

  final PlannerRepository _repository;
  final CalculateDailyCramTargetUseCase _calculateTargetUseCase;
  final CreateExamCountdownUseCase _createExamUseCase;
  final CramWorkloadCalculator _calculator;

  /// Loads active exams and calculates initial urgency for the closest exam.
  Future<void> loadExams() async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    final result = await _repository.getActiveExams();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CramPlannerStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (exams) {
        final sorted = List<ExamEventEntity>.from(exams)
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        final primaryExam = sorted.isNotEmpty ? sorted.first : null;
        var pace = 20;
        var urgency = ExamUrgencyLevel.normal;

        if (primaryExam != null) {
          pace = _calculateTargetUseCase(
            remainingCards: primaryExam.remainingCards,
            lapses: primaryExam.totalLapses,
            daysRemaining: primaryExam.daysRemaining,
          );
          urgency = _calculator.getUrgencyLevel(primaryExam.daysRemaining);
        }

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: sorted,
            selectedExam: primaryExam,
            clearSelectedExam: primaryExam == null,
            dynamicDailyTarget: pace,
            urgencyLevel: urgency,
          ),
        );
      },
    );
  }

  /// Adds a new exam countdown and recalculates workload.
  Future<void> addExamCountdown({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  }) async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    final result = await _createExamUseCase(
      examName: examName,
      targetDate: targetDate,
      subjectTrack: subjectTrack,
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
        final updatedList = List<ExamEventEntity>.from(state.activeExams)
          ..add(newExam)
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        final primary = updatedList.first;
        final pace = _calculateTargetUseCase(
          remainingCards: primary.remainingCards,
          lapses: primary.totalLapses,
          daysRemaining: primary.daysRemaining,
        );
        final urgency = _calculator.getUrgencyLevel(primary.daysRemaining);

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: updatedList,
            selectedExam: primary,
            dynamicDailyTarget: pace,
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
        urgencyLevel: _calculator.getUrgencyLevel(exam.daysRemaining),
      ),
    );
  }

  /// Updates an existing exam countdown.
  Future<void> updateExamCountdown({
    required String examId,
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    int? totalCardsCount,
    double? targetScorePercent,
  }) async {
    emit(state.copyWith(status: CramPlannerStatus.loading));

    final result = await _repository.updateExam(
      examId: examId,
      examName: examName,
      targetDate: targetDate,
      subjectTrack: subjectTrack,
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
      (updatedExam) {
        final updatedList = state.activeExams
            .map((e) => e.id == examId ? updatedExam : e)
            .toList()
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

        final primary = (state.selectedExam?.id == examId)
            ? updatedExam
            : (updatedList.isNotEmpty ? updatedList.first : null);

        var pace = 20;
        var urgency = ExamUrgencyLevel.normal;
        if (primary != null) {
          pace = _calculateTargetUseCase(
            remainingCards: primary.remainingCards,
            lapses: primary.totalLapses,
            daysRemaining: primary.daysRemaining,
          );
          urgency = _calculator.getUrgencyLevel(primary.daysRemaining);
        }

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: updatedList,
            selectedExam: primary,
            dynamicDailyTarget: pace,
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
        final updatedList = state.activeExams
            .where((e) => e.id != examId)
            .toList()
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
          urgency = _calculator.getUrgencyLevel(primary.daysRemaining);
        }

        emit(
          state.copyWith(
            status: CramPlannerStatus.loaded,
            activeExams: updatedList,
            selectedExam: primary,
            clearSelectedExam: primary == null,
            dynamicDailyTarget: pace,
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
    final urgency = _calculator.getUrgencyLevel(match.daysRemaining);

    emit(
      state.copyWith(
        selectedExam: match,
        dynamicDailyTarget: pace,
        urgencyLevel: urgency,
      ),
    );
  }
}
