import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';

abstract class PlannerRepository {
  Future<Either<Failure, List<ExamEventEntity>>> getActiveExams();

  Future<Either<Failure, ExamEventEntity>> createExam({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    AssessmentType assessmentType = AssessmentType.finalExam,
    List<String> scopedDeckIds = const [],
    List<String> scopedTopics = const [],
    double? weightPercent,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  });

  Future<Either<Failure, ExamEventEntity>> updateExam({
    required String examId,
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    AssessmentType? assessmentType,
    List<String>? scopedDeckIds,
    List<String>? scopedTopics,
    double? weightPercent,
    int? totalCardsCount,
    double? targetScorePercent,
    bool? isCompleted,
    double? achievedScorePercent,
  });

  Future<Either<Failure, ExamEventEntity>> completeExam({
    required String examId,
    required double scorePercent,
    bool rolloverWeakCards = true,
  });

  Future<Either<Failure, ExamEventEntity>> reopenExam(String examId);

  Future<Either<Failure, void>> deleteExam(String examId);
}
