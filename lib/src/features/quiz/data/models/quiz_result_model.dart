import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';

class TopicWeaknessModel extends TopicWeakness {
  const TopicWeaknessModel({
    required super.subTopic,
    required super.totalQuestions,
    required super.correctCount,
  });

  factory TopicWeaknessModel.fromJson(Map<String, dynamic> json) {
    return TopicWeaknessModel(
      subTopic: json['sub_topic'] as String? ?? 'General',
      totalQuestions: json['total_questions'] as int? ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sub_topic': subTopic,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
    };
  }
}

class QuizResultModel extends QuizResultEntity {
  const QuizResultModel({
    required super.id,
    required super.quizTitle,
    required super.totalQuestions,
    required super.correctAnswers,
    required super.durationSeconds,
    required super.weaknesses,
    super.completedAt,
  });

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    final rawWeaknesses = json['weaknesses'];
    final List<TopicWeakness> parsedWeaknesses = rawWeaknesses is List
        ? rawWeaknesses
              .map(
                (w) => TopicWeaknessModel.fromJson(w as Map<String, dynamic>),
              )
              .toList()
        : [];

    return QuizResultModel(
      id: json['id'] as String,
      quizTitle: json['quiz_title'] as String? ?? 'Practice Quiz',
      totalQuestions: json['total_questions'] as int? ?? 0,
      correctAnswers: json['correct_answers'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      weaknesses: parsedWeaknesses,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_title': quizTitle,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'duration_seconds': durationSeconds,
      'weaknesses': weaknesses
          .map(
            (w) => {
              'sub_topic': w.subTopic,
              'total_questions': w.totalQuestions,
              'correct_count': w.correctCount,
            },
          )
          .toList(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}
