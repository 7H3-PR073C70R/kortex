import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';

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
    this.imageUrl,
    this.userSelectedAnswer,
    this.isAnswered = false,
    this.isCorrect = false,
  });

  factory QuizQuestionEntity.fromPastQuestion(PastQuestionEntity q) {
    if (q.isTheory) {
      return QuizQuestionEntity(
        id: q.id,
        prompt: q.passage != null && q.passage!.isNotEmpty
            ? '${q.passage}\n\n${q.prompt}'
            : q.prompt,
        type: QuizQuestionType.shortAnswer,
        options: const [],
        correctAnswer: q.explanation,
        explanation: q.explanation.isNotEmpty
            ? q.explanation
            : 'Review the model answer and key marking rubrics above.',
        subTopic: '${q.subject} (${q.year} • Q${q.questionNumber}) [Theory]',
        latexFormula: q.latexFormula,
        imageUrl: q.imageUrl,
      );
    }

    final optionLetters = ['A', 'B', 'C', 'D', 'E'];
    final rawCorrectAns = q.correctOptionIndex < q.options.length
        ? q.options[q.correctOptionIndex]
        : (q.correctOptionIndex < optionLetters.length
              ? optionLetters[q.correctOptionIndex]
              : '');

    return QuizQuestionEntity(
      id: q.id,
      prompt: q.passage != null && q.passage!.isNotEmpty
          ? '${q.passage}\n\n${q.prompt}'
          : q.prompt,
      type: QuizQuestionType.multipleChoice,
      options: q.options,
      correctAnswer: rawCorrectAns,
      explanation: q.explanation.isNotEmpty
          ? q.explanation
          : 'Option ${q.correctOptionLabel} is the correct answer.',
      subTopic: '${q.subject} (${q.year} • Q${q.questionNumber})',
      latexFormula: q.latexFormula,
      imageUrl: q.imageUrl,
    );
  }

  final String id;
  final String prompt;
  final QuizQuestionType type;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String subTopic;
  final String? latexFormula;
  final String? imageUrl;
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
    String? imageUrl,
    String? userSelectedAnswer,
    bool clearUserSelectedAnswer = false,
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
      imageUrl: imageUrl ?? this.imageUrl,
      userSelectedAnswer: clearUserSelectedAnswer
          ? null
          : (userSelectedAnswer ?? this.userSelectedAnswer),
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
    imageUrl,
    userSelectedAnswer,
    isAnswered,
    isCorrect,
  ];
}
