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
    };
  }
}
