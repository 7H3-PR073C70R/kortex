import 'package:equatable/equatable.dart';

enum ExamCategory {
  waec,
  jamb,
  neco,
  sat,
  toefl,
  ielts,
  medicine,
  law,
  engineering,
  business,
  computerScience,
  general,
}

extension ExamCategoryExt on ExamCategory {
  String get displayName {
    switch (this) {
      case ExamCategory.waec:
        return 'WAEC / WASSCE';
      case ExamCategory.jamb:
        return 'JAMB / UTME';
      case ExamCategory.neco:
        return 'NECO / SSCE';
      case ExamCategory.sat:
        return 'SAT';
      case ExamCategory.toefl:
        return 'TOEFL iBT';
      case ExamCategory.ielts:
        return 'IELTS';
      case ExamCategory.medicine:
        return 'Medicine';
      case ExamCategory.law:
        return 'Law';
      case ExamCategory.engineering:
        return 'Engineering';
      case ExamCategory.business:
        return 'Business & Accounting';
      case ExamCategory.computerScience:
        return 'Computer Science';
      case ExamCategory.general:
        return 'General Studies';
    }
  }

  String get code {
    switch (this) {
      case ExamCategory.waec:
        return 'WAEC';
      case ExamCategory.jamb:
        return 'JAMB';
      case ExamCategory.neco:
        return 'NECO';
      case ExamCategory.sat:
        return 'SAT';
      case ExamCategory.toefl:
        return 'TOEFL';
      case ExamCategory.ielts:
        return 'IELTS';
      case ExamCategory.medicine:
        return 'MEDICINE';
      case ExamCategory.law:
        return 'LAW';
      case ExamCategory.engineering:
        return 'ENGINEERING';
      case ExamCategory.business:
        return 'BUSINESS';
      case ExamCategory.computerScience:
        return 'CS';
      case ExamCategory.general:
        return 'GENERAL';
    }
  }
}

class PastQuestionEntity extends Equatable {
  const PastQuestionEntity({
    required this.id,
    required this.examType,
    required this.subject,
    required this.year,
    required this.questionNumber,
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
    required this.correctOptionLabel,
    required this.explanation,
    required this.topic,
    this.passage,
    this.latexFormula,
    this.difficulty = 'Medium',
    this.userSelectedOptionIndex,
    this.isBookmarked = false,
  });

  final String id;
  final ExamCategory examType;
  final String subject;
  final int year;
  final int questionNumber;
  final String prompt;
  final List<String> options;
  final int correctOptionIndex;
  final String correctOptionLabel;
  final String explanation;
  final String topic;
  final String? passage;
  final String? latexFormula;
  final String difficulty;
  final int? userSelectedOptionIndex;
  final bool isBookmarked;

  bool get isAnswered => userSelectedOptionIndex != null;
  bool get isCorrect => userSelectedOptionIndex == correctOptionIndex;

  PastQuestionEntity copyWith({
    String? id,
    ExamCategory? examType,
    String? subject,
    int? year,
    int? questionNumber,
    String? prompt,
    List<String>? options,
    int? correctOptionIndex,
    String? correctOptionLabel,
    String? explanation,
    String? topic,
    String? passage,
    String? latexFormula,
    String? difficulty,
    int? userSelectedOptionIndex,
    bool? isBookmarked,
  }) {
    return PastQuestionEntity(
      id: id ?? this.id,
      examType: examType ?? this.examType,
      subject: subject ?? this.subject,
      year: year ?? this.year,
      questionNumber: questionNumber ?? this.questionNumber,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      correctOptionLabel: correctOptionLabel ?? this.correctOptionLabel,
      explanation: explanation ?? this.explanation,
      topic: topic ?? this.topic,
      passage: passage ?? this.passage,
      latexFormula: latexFormula ?? this.latexFormula,
      difficulty: difficulty ?? this.difficulty,
      userSelectedOptionIndex:
          userSelectedOptionIndex ?? this.userSelectedOptionIndex,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  @override
  List<Object?> get props => [
    id,
    examType,
    subject,
    year,
    questionNumber,
    prompt,
    options,
    correctOptionIndex,
    correctOptionLabel,
    explanation,
    topic,
    passage,
    latexFormula,
    difficulty,
    userSelectedOptionIndex,
    isBookmarked,
  ];
}
