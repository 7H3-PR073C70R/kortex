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
    this.imageUrl,
    this.difficulty = 'Medium',
    this.isUserAdded = false,
    this.courseId,
    this.courseCode,
  });

  static ExamCategory parseExamCategory(String? raw) {
    final rawExam = (raw ?? 'general').toLowerCase();
    if (rawExam.contains('waec') || rawExam.contains('wassce')) {
      return ExamCategory.waec;
    } else if (rawExam.contains('jamb') || rawExam.contains('utme')) {
      return ExamCategory.jamb;
    } else if (rawExam.contains('neco')) {
      return ExamCategory.neco;
    } else if (rawExam.contains('sat')) {
      return ExamCategory.sat;
    } else if (rawExam.contains('toefl')) {
      return ExamCategory.toefl;
    } else if (rawExam.contains('ielts')) {
      return ExamCategory.ielts;
    } else if (rawExam.contains('med')) {
      return ExamCategory.medicine;
    } else if (rawExam.contains('law')) {
      return ExamCategory.law;
    } else if (rawExam.contains('eng')) {
      return ExamCategory.engineering;
    } else if (rawExam.contains('bus') || rawExam.contains('acc')) {
      return ExamCategory.business;
    } else if (rawExam.contains('cs') || rawExam.contains('comp')) {
      return ExamCategory.computerScience;
    }
    return ExamCategory.general;
  }

  factory PastQuestionModel.fromJson(Map<String, dynamic> json) {
    final category = parseExamCategory(json['exam_type'] as String?);

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
      id:
          json['id'] as String? ??
          'pq_${DateTime.now().microsecondsSinceEpoch}',
      examType: category,
      subject: json['subject'] as String? ?? 'General',
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      questionNumber: (json['question_number'] as num?)?.toInt() ?? 1,
      prompt: json['prompt'] as String? ?? json['question'] as String? ?? '',
      options: optionsList,
      correctOptionIndex: (json['correct_option_index'] as num?)?.toInt() ?? 0,
      correctOptionLabel: json['correct_option_label'] as String? ?? 'A',
      explanation: json['explanation'] as String? ?? '',
      topic: json['topic'] as String? ?? 'General',
      passage: json['passage'] as String?,
      latexFormula: json['latex_formula'] as String?,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      difficulty: json['difficulty'] as String? ?? 'Medium',
      isUserAdded: json['is_user_added'] as bool? ??
          json['isUserAdded'] as bool? ??
          false,
      courseId: json['course_id'] as String? ?? json['courseId'] as String?,
      courseCode:
          json['course_code'] as String? ?? json['courseCode'] as String?,
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
  final String? imageUrl;
  final String difficulty;
  final bool isUserAdded;
  final String? courseId;
  final String? courseCode;

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
      'image_url': imageUrl,
      'difficulty': difficulty,
      'is_user_added': isUserAdded,
      'course_id': courseId,
      'course_code': courseCode,
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
      imageUrl: imageUrl,
      difficulty: difficulty,
      isUserAdded: isUserAdded,
      courseId: courseId,
      courseCode: courseCode,
    );
  }
}
