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
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? 'current-user',
      examName: json['exam_name']?.toString() ?? 'Exam',
      targetDate: DateTime.parse(json['target_date'] as String),
      subjectTrack: json['subject_track']?.toString() ?? 'General',
      totalCardsCount: (json['total_cards_count'] as num?)?.toInt() ?? 0,
      masteredCardsCount: (json['mastered_cards_count'] as num?)?.toInt() ?? 0,
      totalLapses: (json['total_lapses'] as num?)?.toInt() ?? 0,
      dailyTarget: (json['daily_target'] as num?)?.toInt() ?? 20,
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
