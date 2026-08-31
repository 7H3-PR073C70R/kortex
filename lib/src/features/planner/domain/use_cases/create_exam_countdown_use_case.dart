import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';

class CreateExamCountdownUseCase {
  const CreateExamCountdownUseCase(this._repository);

  final PlannerRepository _repository;

  Future<Either<Failure, ExamEventEntity>> call({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  }) {
    return _repository.createExam(
      examName: examName,
      targetDate: targetDate,
      subjectTrack: subjectTrack,
      totalCardsCount: totalCardsCount,
      targetScorePercent: targetScorePercent,
    );
  }
}
