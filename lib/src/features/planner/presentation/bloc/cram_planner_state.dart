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
    this.urgencyLevel = ExamUrgencyLevel.normal,
    this.errorMessage,
  });

  final CramPlannerStatus status;
  final List<ExamEventEntity> activeExams;
  final ExamEventEntity? selectedExam;
  final int dynamicDailyTarget;
  final ExamUrgencyLevel urgencyLevel;
  final String? errorMessage;

  CramPlannerState copyWith({
    CramPlannerStatus? status,
    List<ExamEventEntity>? activeExams,
    ExamEventEntity? selectedExam,
    int? dynamicDailyTarget,
    ExamUrgencyLevel? urgencyLevel,
    String? errorMessage,
  }) {
    return CramPlannerState(
      status: status ?? this.status,
      activeExams: activeExams ?? this.activeExams,
      selectedExam: selectedExam ?? this.selectedExam,
      dynamicDailyTarget: dynamicDailyTarget ?? this.dynamicDailyTarget,
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
    urgencyLevel,
    errorMessage,
  ];
}
