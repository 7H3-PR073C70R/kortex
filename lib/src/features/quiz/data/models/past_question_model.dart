import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class PastQuestionModel {
  const PastQuestionModel({
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
  });

  factory PastQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawExam = (json['exam_type'] as String? ?? 'waec').toLowerCase();
    ExamCategory category;
    if (rawExam.contains('waec') || rawExam.contains('wassce')) {
      category = ExamCategory.waec;
    } else if (rawExam.contains('jamb') || rawExam.contains('utme')) {
      category = ExamCategory.jamb;
    } else if (rawExam.contains('sat')) {
      category = ExamCategory.sat;
    } else if (rawExam.contains('toefl')) {
      category = ExamCategory.toefl;
    } else if (rawExam.contains('ielts')) {
      category = ExamCategory.ielts;
    } else if (rawExam.contains('med')) {
      category = ExamCategory.medicine;
    } else if (rawExam.contains('law')) {
      category = ExamCategory.law;
    } else if (rawExam.contains('eng')) {
      category = ExamCategory.engineering;
    } else if (rawExam.contains('bus') || rawExam.contains('acc')) {
      category = ExamCategory.business;
    } else if (rawExam.contains('cs') || rawExam.contains('comp')) {
      category = ExamCategory.computerScience;
    } else {
      category = ExamCategory.general;
    }

    final rawOptions = json['options'];
    List<String> optionsList = [];
    if (rawOptions is List) {
      optionsList = rawOptions.map((e) => e.toString()).toList();
    } else if (rawOptions is Map) {
      optionsList = [
        rawOptions['A']?.toString() ?? '',
        rawOptions['B']?.toString() ?? '',
        rawOptions['C']?.toString() ?? '',
        rawOptions['D']?.toString() ?? '',
      ].where((s) => s.isNotEmpty).toList();
    }

    return PastQuestionModel(
      id: json['id'] as String? ?? 'pq_${DateTime.now().microsecondsSinceEpoch}',
      examType: category,
      subject: json['subject'] as String? ?? 'General',
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      questionNumber: (json['question_number'] as num?)?.toInt() ?? 1,
      prompt: json['prompt'] as String? ?? json['question'] as String? ?? '',
      options: optionsList,
      correctOptionIndex:
          (json['correct_option_index'] as num?)?.toInt() ?? 0,
      correctOptionLabel: json['correct_option_label'] as String? ?? 'A',
      explanation: json['explanation'] as String? ?? '',
      topic: json['topic'] as String? ?? 'General',
      passage: json['passage'] as String?,
      latexFormula: json['latex_formula'] as String?,
      difficulty: json['difficulty'] as String? ?? 'Medium',
    );
  }

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_type': examType.code,
      'subject': subject,
      'year': year,
      'question_number': questionNumber,
      'prompt': prompt,
      'options': options,
      'correct_option_index': correctOptionIndex,
      'correct_option_label': correctOptionLabel,
      'explanation': explanation,
      'topic': topic,
      'passage': passage,
      'latex_formula': latexFormula,
      'difficulty': difficulty,
    };
  }

  PastQuestionEntity toEntity() {
    return PastQuestionEntity(
      id: id,
      examType: examType,
      subject: subject,
      year: year,
      questionNumber: questionNumber,
      prompt: prompt,
      options: options,
      correctOptionIndex: correctOptionIndex,
      correctOptionLabel: correctOptionLabel,
      explanation: explanation,
      topic: topic,
      passage: passage,
      latexFormula: latexFormula,
      difficulty: difficulty,
    );
  }
}
