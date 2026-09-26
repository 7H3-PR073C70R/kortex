import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';

enum CramPlannerStatus {
  initial,
  loading,
  loaded,
  error,
}

class CramPlannerState extends Equatable {
  const CramPlannerState({
    this.status = CramPlannerStatus.initial,
    this.activeExams = const [],
    this.selectedExam,
    this.dynamicDailyTarget = 20,
    this.totalCombinedDailyTarget = 0,
    this.estimatedDailyMinutes = 0,
    this.topPriorityExamId,
    this.urgencyLevel = ExamUrgencyLevel.normal,
    this.errorMessage,
  });

  final CramPlannerStatus status;
  final List<ExamEventEntity> activeExams;
  final ExamEventEntity? selectedExam;
  final int dynamicDailyTarget;
  final int totalCombinedDailyTarget;
  final int estimatedDailyMinutes;
  final String? topPriorityExamId;
  final ExamUrgencyLevel urgencyLevel;
  final String? errorMessage;

  List<ExamEventEntity> get upcomingUncompletedExams =>
      activeExams.where((e) => !e.isCompleted && !e.isPast && !e.isCancelled).toList();

  List<ExamEventEntity> get postponedExams =>
      activeExams.where((e) => e.isPostponed && !e.isCancelled && !e.isCompleted).toList();

  List<ExamEventEntity> get cancelledExams =>
      activeExams.where((e) => e.isCancelled).toList();

  List<ExamEventEntity> get completedExams =>
      activeExams.where((e) => e.isCompleted).toList();

  List<ExamEventEntity> get concludedUnloggedExams =>
      activeExams.where((e) => e.isPast && !e.isCompleted && !e.isCancelled).toList();

  CramPlannerState copyWith({
    CramPlannerStatus? status,
    List<ExamEventEntity>? activeExams,
    ExamEventEntity? selectedExam,
    bool clearSelectedExam = false,
    int? dynamicDailyTarget,
    int? totalCombinedDailyTarget,
    int? estimatedDailyMinutes,
    String? topPriorityExamId,
    bool clearTopPriorityExamId = false,
    ExamUrgencyLevel? urgencyLevel,
    String? errorMessage,
  }) {
    return CramPlannerState(
      status: status ?? this.status,
      activeExams: activeExams ?? this.activeExams,
      selectedExam: clearSelectedExam
          ? null
          : (selectedExam ?? this.selectedExam),
      dynamicDailyTarget: dynamicDailyTarget ?? this.dynamicDailyTarget,
      totalCombinedDailyTarget:
          totalCombinedDailyTarget ?? this.totalCombinedDailyTarget,
      estimatedDailyMinutes:
          estimatedDailyMinutes ?? this.estimatedDailyMinutes,
      topPriorityExamId: clearTopPriorityExamId
          ? null
          : (topPriorityExamId ?? this.topPriorityExamId),
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    activeExams,
    selectedExam,
    dynamicDailyTarget,
    totalCombinedDailyTarget,
    estimatedDailyMinutes,
    topPriorityExamId,
    urgencyLevel,
    errorMessage,
  ];
}
