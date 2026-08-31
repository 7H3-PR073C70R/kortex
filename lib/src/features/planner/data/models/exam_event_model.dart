import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';

class ExamEventModel extends ExamEventEntity {
  const ExamEventModel({
    required super.id,
    required super.userId,
    required super.examName,
    required super.targetDate,
    required super.subjectTrack,
    super.totalCardsCount = 0,
    super.masteredCardsCount = 0,
    super.totalLapses = 0,
    super.dailyTarget = 20,
    super.targetScorePercent = 0.85,
    super.createdAt,
  });

  factory ExamEventModel.fromJson(Map<String, dynamic> json) {
    return ExamEventModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      examName: json['exam_name'] as String,
      targetDate: DateTime.parse(json['target_date'] as String),
      subjectTrack: json['subject_track'] as String? ?? 'General',
      totalCardsCount: json['total_cards_count'] as int? ?? 0,
      masteredCardsCount: json['mastered_cards_count'] as int? ?? 0,
      totalLapses: json['total_lapses'] as int? ?? 0,
      dailyTarget: json['daily_target'] as int? ?? 20,
      targetScorePercent:
          (json['target_score_percent'] as num?)?.toDouble() ?? 0.85,
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
      'total_cards_count': totalCardsCount,
      'mastered_cards_count': masteredCardsCount,
      'total_lapses': totalLapses,
      'daily_target': dailyTarget,
      'target_score_percent': targetScorePercent,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
