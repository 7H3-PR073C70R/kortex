import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';

class CreateExamCountdownUseCase {
  const CreateExamCountdownUseCase(this._repository);

  final PlannerRepository _repository;

  Future<Either<Failure, ExamEventEntity>> call({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    AssessmentType assessmentType = AssessmentType.finalExam,
    List<String> scopedDeckIds = const [],
    List<String> scopedTopics = const [],
    double? weightPercent,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  }) {
    return _repository.createExam(
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
  }
}
