import 'package:equatable/equatable.dart';

class TopicWeakness extends Equatable {
  const TopicWeakness({
    required this.subTopic,
    required this.totalQuestions,
    required this.correctCount,
  });

  final String subTopic;
  final int totalQuestions;
  final int correctCount;

  double get accuracy =>
      totalQuestions == 0 ? 0.0 : correctCount / totalQuestions;

  bool get isWeak => accuracy < 0.70;

  @override
  List<Object?> get props => [subTopic, totalQuestions, correctCount];
}

class QuizResultEntity extends Equatable {
  const QuizResultEntity({
    required this.id,
    required this.quizTitle,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.durationSeconds,
    required this.weaknesses,
    this.completedAt,
  });

  final String id;
  final String quizTitle;
  final int totalQuestions;
  final int correctAnswers;
  final int durationSeconds;
  final List<TopicWeakness> weaknesses;
  final DateTime? completedAt;

  int get scorePercent => totalQuestions == 0
      ? 0
      : ((correctAnswers / totalQuestions) * 100).round();

  List<String> get weakSubTopics => weaknesses
      .where((w) => w.isWeak)
      .map((w) => w.subTopic)
      .toList();

  @override
  List<Object?> get props => [
        id,
        quizTitle,
        totalQuestions,
        correctAnswers,
        durationSeconds,
        weaknesses,
        completedAt,
      ];
}
