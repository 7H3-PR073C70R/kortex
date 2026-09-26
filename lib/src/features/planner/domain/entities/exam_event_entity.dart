import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';

/// Entity representing an upcoming academic examination, test, or quiz and its pacing goals.
class ExamEventEntity extends Equatable {
  const ExamEventEntity({
    required this.id,
    required this.userId,
    required this.examName,
    required this.targetDate,
    required this.subjectTrack,
    this.assessmentType = AssessmentType.finalExam,
    this.scopedDeckIds = const [],
    this.scopedTopics = const [],
    this.weightPercent,
    this.totalCardsCount = 0,
    this.masteredCardsCount = 0,
    this.totalLapses = 0,
    this.dailyTarget = 20,
    this.targetScorePercent = 0.85,
    this.isCompleted = false,
    this.achievedScorePercent,
    this.completedAt,
    this.createdAt,
    this.isPostponed = false,
    this.originalTargetDate,
    this.postponedReason,
    this.isCancelled = false,
    this.cancelledAt,
    this.cancellationReason,
  });

  final String id;
  final String userId;
  final String examName;
  final DateTime targetDate;
  final String subjectTrack;
  final AssessmentType assessmentType;
  final List<String> scopedDeckIds;
  final List<String> scopedTopics;
  final double? weightPercent;
  final int totalCardsCount;
  final int masteredCardsCount;
  final int totalLapses;
  final int dailyTarget;
  final double targetScorePercent;
  final bool isCompleted;
  final double? achievedScorePercent;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final bool isPostponed;
  final DateTime? originalTargetDate;
  final String? postponedReason;
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  bool get isActive => !isCompleted && !isCancelled;

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

  bool get isImminent => !isPast && !isCompleted && !isCancelled && timeRemaining.inHours < 48;

  bool get isCriticalCrunch =>
      !isPast && !isCompleted && !isCancelled && timeRemaining.inHours < 24;

  double get effectiveWeightPercent =>
      weightPercent ?? assessmentType.defaultWeightPercent;

  String get statusBadgeText {
    if (isCancelled) return 'Cancelled';
    if (isCompleted) return 'Completed';
    if (isPostponed) return 'Postponed';
    if (isPast) return 'Concluded';
    return 'Active';
  }

  String get formattedSubDailyCountdown {
    if (isCancelled) return 'Cancelled';
    if (isCompleted) return 'Completed';
    if (isPast) return 'Concluded';
    final totalHours = timeRemaining.inHours;
    final mins = minutesRemaining;
    if (totalHours < 24) {
      if (totalHours > 0) {
        return '${totalHours}h ${mins}m left';
      }
      return '${mins}m left';
    }
    if (timeRemaining.inDays == 1) {
      return 'Tomorrow (${totalHours}h left)';
    }
    final days = daysRemaining;
    return '$days ${days == 1 ? "day" : "days"} left';
  }

  String get formattedCountdown {
    if (isCancelled) return 'Cancelled';
    if (isCompleted) return 'Completed';
    if (isPast) return 'Concluded';
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

  ExamEventEntity copyWith({
    String? id,
    String? userId,
    String? examName,
    DateTime? targetDate,
    String? subjectTrack,
    AssessmentType? assessmentType,
    List<String>? scopedDeckIds,
    List<String>? scopedTopics,
    double? weightPercent,
    int? totalCardsCount,
    int? masteredCardsCount,
    int? totalLapses,
    int? dailyTarget,
    double? targetScorePercent,
    bool? isCompleted,
    double? achievedScorePercent,
    DateTime? completedAt,
    DateTime? createdAt,
    bool? isPostponed,
    DateTime? originalTargetDate,
    String? postponedReason,
    bool? isCancelled,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) {
    return ExamEventEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      examName: examName ?? this.examName,
      targetDate: targetDate ?? this.targetDate,
      subjectTrack: subjectTrack ?? this.subjectTrack,
      assessmentType: assessmentType ?? this.assessmentType,
      scopedDeckIds: scopedDeckIds ?? this.scopedDeckIds,
      scopedTopics: scopedTopics ?? this.scopedTopics,
      weightPercent: weightPercent ?? this.weightPercent,
      totalCardsCount: totalCardsCount ?? this.totalCardsCount,
      masteredCardsCount: masteredCardsCount ?? this.masteredCardsCount,
      totalLapses: totalLapses ?? this.totalLapses,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      targetScorePercent: targetScorePercent ?? this.targetScorePercent,
      isCompleted: isCompleted ?? this.isCompleted,
      achievedScorePercent: achievedScorePercent ?? this.achievedScorePercent,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      isPostponed: isPostponed ?? this.isPostponed,
      originalTargetDate: originalTargetDate ?? this.originalTargetDate,
      postponedReason: postponedReason ?? this.postponedReason,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    examName,
    targetDate,
    subjectTrack,
    assessmentType,
    scopedDeckIds,
    scopedTopics,
    weightPercent,
    totalCardsCount,
    masteredCardsCount,
    totalLapses,
    dailyTarget,
    targetScorePercent,
    isCompleted,
    achievedScorePercent,
    completedAt,
    createdAt,
    isPostponed,
    originalTargetDate,
    postponedReason,
    isCancelled,
    cancelledAt,
    cancellationReason,
  ];
}
