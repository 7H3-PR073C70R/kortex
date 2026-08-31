import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';

abstract class PlannerRepository {
  Future<Either<Failure, List<ExamEventEntity>>> getActiveExams();

  Future<Either<Failure, ExamEventEntity>> createExam({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  });

  Future<Either<Failure, void>> deleteExam(String examId);
}
