import 'package:equatable/equatable.dart';

/// Entity representing an upcoming academic examination and its pacing goals.
class ExamEventEntity extends Equatable {
  const ExamEventEntity({
    required this.id,
    required this.userId,
    required this.examName,
    required this.targetDate,
    required this.subjectTrack,
    this.totalCardsCount = 0,
    this.masteredCardsCount = 0,
    this.totalLapses = 0,
    this.dailyTarget = 20,
    this.targetScorePercent = 0.85,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String examName;
  final DateTime targetDate;
  final String subjectTrack;
  final int totalCardsCount;
  final int masteredCardsCount;
  final int totalLapses;
  final int dailyTarget;
  final double targetScorePercent;
  final DateTime? createdAt;

  int get daysRemaining {
    final now = DateTime.now();
    final difference = targetDate.difference(now).inDays;
    return difference < 0 ? 0 : difference;
  }

  int get remainingCards =>
      (totalCardsCount - masteredCardsCount).clamp(0, totalCardsCount);

  double get completionProgress => totalCardsCount == 0
      ? 0.0
      : (masteredCardsCount / totalCardsCount).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [
    id,
    userId,
    examName,
    targetDate,
    subjectTrack,
    totalCardsCount,
    masteredCardsCount,
    totalLapses,
    dailyTarget,
    targetScorePercent,
    createdAt,
  ];
}
