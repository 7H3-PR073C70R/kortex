import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';

class ExamEventModel extends ExamEventEntity {
  const ExamEventModel({
    required super.id,
    required super.userId,
    required super.examName,
    required super.targetDate,
    required super.subjectTrack,
    super.assessmentType = AssessmentType.finalExam,
    super.scopedDeckIds = const [],
    super.scopedTopics = const [],
    super.weightPercent,
    super.totalCardsCount = 0,
    super.masteredCardsCount = 0,
    super.totalLapses = 0,
    super.dailyTarget = 20,
    super.targetScorePercent = 0.85,
    super.isCompleted = false,
    super.achievedScorePercent,
    super.completedAt,
    super.createdAt,
    super.isPostponed = false,
    super.originalTargetDate,
    super.postponedReason,
    super.isCancelled = false,
    super.cancelledAt,
    super.cancellationReason,
  });

  factory ExamEventModel.fromJson(Map<String, dynamic> json) {
    return ExamEventModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? 'current-user',
      examName: json['exam_name']?.toString() ?? 'Exam',
      targetDate: DateTime.parse(json['target_date'] as String),
      subjectTrack: json['subject_track']?.toString() ?? 'General',
      assessmentType: AssessmentType.fromString(
        json['assessment_type']?.toString(),
      ),
      scopedDeckIds: (json['scoped_deck_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      scopedTopics: (json['scoped_topics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      weightPercent: (json['weight_percent'] as num?)?.toDouble(),
      totalCardsCount: (json['total_cards_count'] as num?)?.toInt() ?? 0,
      masteredCardsCount: (json['mastered_cards_count'] as num?)?.toInt() ?? 0,
      totalLapses: (json['total_lapses'] as num?)?.toInt() ?? 0,
      dailyTarget: (json['daily_target'] as num?)?.toInt() ?? 20,
      targetScorePercent:
          (json['target_score_percent'] as num?)?.toDouble() ?? 0.85,
      isCompleted: json['is_completed'] as bool? ?? false,
      achievedScorePercent:
          (json['achieved_score_percent'] as num?)?.toDouble(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      isPostponed: json['is_postponed'] as bool? ?? false,
      originalTargetDate: json['original_target_date'] != null
          ? DateTime.parse(json['original_target_date'] as String)
          : null,
      postponedReason: json['postponed_reason']?.toString(),
      isCancelled: json['is_cancelled'] as bool? ?? false,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason']?.toString(),
    );
  }

  factory ExamEventModel.fromEntity(ExamEventEntity entity) {
    return ExamEventModel(
      id: entity.id,
      userId: entity.userId,
      examName: entity.examName,
      targetDate: entity.targetDate,
      subjectTrack: entity.subjectTrack,
      assessmentType: entity.assessmentType,
      scopedDeckIds: entity.scopedDeckIds,
      scopedTopics: entity.scopedTopics,
      weightPercent: entity.weightPercent,
      totalCardsCount: entity.totalCardsCount,
      masteredCardsCount: entity.masteredCardsCount,
      totalLapses: entity.totalLapses,
      dailyTarget: entity.dailyTarget,
      targetScorePercent: entity.targetScorePercent,
      isCompleted: entity.isCompleted,
      achievedScorePercent: entity.achievedScorePercent,
      completedAt: entity.completedAt,
      createdAt: entity.createdAt,
      isPostponed: entity.isPostponed,
      originalTargetDate: entity.originalTargetDate,
      postponedReason: entity.postponedReason,
      isCancelled: entity.isCancelled,
      cancelledAt: entity.cancelledAt,
      cancellationReason: entity.cancellationReason,
    );
  }

  @override
  ExamEventModel copyWith({
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
    return ExamEventModel(
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'exam_name': examName,
      'target_date': targetDate.toIso8601String(),
      'subject_track': subjectTrack,
      'assessment_type': assessmentType.name,
      'scoped_deck_ids': scopedDeckIds,
      'scoped_topics': scopedTopics,
      if (weightPercent != null) 'weight_percent': weightPercent,
      'total_cards_count': totalCardsCount,
      'mastered_cards_count': masteredCardsCount,
      'total_lapses': totalLapses,
      'daily_target': dailyTarget,
      'target_score_percent': targetScorePercent,
      'is_completed': isCompleted,
      if (achievedScorePercent != null)
        'achieved_score_percent': achievedScorePercent,
      if (completedAt != null) 'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'is_postponed': isPostponed,
      if (originalTargetDate != null)
        'original_target_date': originalTargetDate?.toIso8601String(),
      if (postponedReason != null) 'postponed_reason': postponedReason,
      'is_cancelled': isCancelled,
      if (cancelledAt != null) 'cancelled_at': cancelledAt?.toIso8601String(),
      if (cancellationReason != null)
        'cancellation_reason': cancellationReason,
    };
  }
}
