import 'package:equatable/equatable.dart';

enum QuizQuestionType {
  multipleChoice,
  shortAnswer,
  trueFalse,
}

class QuizQuestionEntity extends Equatable {
  const QuizQuestionEntity({
    required this.id,
    required this.prompt,
    required this.type,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.subTopic,
    this.latexFormula,
    this.userSelectedAnswer,
    this.isAnswered = false,
    this.isCorrect = false,
  });

  final String id;
  final String prompt;
  final QuizQuestionType type;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String subTopic;
  final String? latexFormula;
  final String? userSelectedAnswer;
  final bool isAnswered;
  final bool isCorrect;

  QuizQuestionEntity copyWith({
    String? id,
    String? prompt,
    QuizQuestionType? type,
    List<String>? options,
    String? correctAnswer,
    String? explanation,
    String? subTopic,
    String? latexFormula,
    String? userSelectedAnswer,
    bool? isAnswered,
    bool? isCorrect,
  }) {
    return QuizQuestionEntity(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      type: type ?? this.type,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      subTopic: subTopic ?? this.subTopic,
      latexFormula: latexFormula ?? this.latexFormula,
      userSelectedAnswer: userSelectedAnswer ?? this.userSelectedAnswer,
      isAnswered: isAnswered ?? this.isAnswered,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }

  @override
  List<Object?> get props => [
        id,
        prompt,
        type,
        options,
        correctAnswer,
        explanation,
        subTopic,
        latexFormula,
        userSelectedAnswer,
        isAnswered,
        isCorrect,
      ];
}
