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
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final difference = target.difference(today).inDays;
    return difference < 0 ? 0 : difference;
  }

  Duration get timeRemaining {
    final diff = targetDate.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  int get hoursRemaining => timeRemaining.inHours % 24;

  int get minutesRemaining => timeRemaining.inMinutes % 60;

  bool get isPast => targetDate.isBefore(DateTime.now());

  String get formattedCountdown {
    if (isPast) return 'Completed';
    final days = timeRemaining.inDays;
    final hours = hoursRemaining;
    final mins = minutesRemaining;
    if (days > 0) {
      return '$days ${days == 1 ? "day" : "days"}, $hours ${hours == 1 ? "hr" : "hrs"} left';
    }
    if (hours > 0) {
      return '$hours ${hours == 1 ? "hr" : "hrs"}, $mins min left';
    }
    return '$mins min left';
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
