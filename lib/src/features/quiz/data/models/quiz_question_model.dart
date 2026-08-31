import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';

class QuizQuestionModel extends QuizQuestionEntity {
  const QuizQuestionModel({
    required super.id,
    required super.prompt,
    required super.type,
    required super.options,
    required super.correctAnswer,
    required super.explanation,
    required super.subTopic,
    super.latexFormula,
    super.userSelectedAnswer,
    super.isAnswered = false,
    super.isCorrect = false,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    QuizQuestionType parsedType;
    final typeStr = json['type'] as String? ?? 'multipleChoice';
    switch (typeStr) {
      case 'shortAnswer':
        parsedType = QuizQuestionType.shortAnswer;
        break;
      case 'trueFalse':
        parsedType = QuizQuestionType.trueFalse;
        break;
      default:
        parsedType = QuizQuestionType.multipleChoice;
    }

    final rawOptions = json['options'];
    final List<String> parsedOptions = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : [];

    return QuizQuestionModel(
      id: json['id'] as String? ?? 'q-${DateTime.now().microsecondsSinceEpoch}',
      prompt: json['prompt'] as String? ?? '',
      type: parsedType,
      options: parsedOptions,
      correctAnswer: json['correct_answer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      subTopic: json['sub_topic'] as String? ?? 'General Knowledge',
      latexFormula: json['latex_formula'] as String?,
      userSelectedAnswer: json['user_selected_answer'] as String?,
      isAnswered: json['is_answered'] as bool? ?? false,
      isCorrect: json['is_correct'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'type': type.name,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'sub_topic': subTopic,
      if (latexFormula != null) 'latex_formula': latexFormula,
      if (userSelectedAnswer != null)
        'user_selected_answer': userSelectedAnswer,
      'is_answered': isAnswered,
      'is_correct': isCorrect,
    };
  }
}
