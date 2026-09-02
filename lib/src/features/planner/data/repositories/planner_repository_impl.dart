import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/data/models/exam_event_model.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';

class PlannerRepositoryImpl implements PlannerRepository {
  PlannerRepositoryImpl({
    CramWorkloadCalculator? calculator,
  }) : _calculator = calculator ?? const CramWorkloadCalculator();

  final CramWorkloadCalculator _calculator;

  // In-memory local cache / fallback list
  final List<ExamEventModel> _cachedExams = [];

  @override
  Future<Either<Failure, List<ExamEventEntity>>> getActiveExams() {
    return Future<List<ExamEventEntity>>.value(
      List<ExamEventEntity>.from(_cachedExams),
    ).makeRequest();
  }

  @override
  Future<Either<Failure, ExamEventEntity>> createExam({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  }) {
    return Future<ExamEventEntity>.sync(() {
      final daysRemaining = targetDate.difference(DateTime.now()).inDays;
      final dailyTarget = _calculator.calculateDailyTarget(
        remainingCards: totalCardsCount,
        lapses: 0,
        daysRemaining: daysRemaining < 1 ? 1 : daysRemaining,
      );

      final newExam = ExamEventModel(
        id: 'exam-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'current-user',
        examName: examName,
        targetDate: targetDate,
        subjectTrack: subjectTrack,
        totalCardsCount: totalCardsCount,
        dailyTarget: dailyTarget,
        targetScorePercent: targetScorePercent,
        createdAt: DateTime.now(),
      );

      _cachedExams.add(newExam);
      return newExam;
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> deleteExam(String examId) {
    return Future<void>.sync(() {
      _cachedExams.removeWhere((e) => e.id == examId);
    }).makeRequest();
  }
}
