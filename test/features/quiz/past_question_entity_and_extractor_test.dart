import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';

void main() {
  group('PastQuestionEntity & PastQuestionModel Tests', () {
    test('theory past question has isTheory == true when options are empty', () {
      const theoryQuestion = PastQuestionEntity(
        id: 'pq_theory_1',
        examType: ExamCategory.waec,
        subject: 'Physics',
        year: 2024,
        questionNumber: 1,
        prompt: "State Newton's second law of motion and derive F = ma.",
        options: [],
        correctOptionIndex: 0,
        correctOptionLabel: '',
        explanation:
            "Newton's second law states that the rate of change of momentum is proportional to the applied force.",
        topic: 'Mechanics',
        isUserAdded: true,
        courseId: 'phy_101',
        courseCode: 'PHY101',
      );

      expect(theoryQuestion.isTheory, isTrue);
      expect(theoryQuestion.isUserAdded, isTrue);
      expect(theoryQuestion.courseId, 'phy_101');
      expect(theoryQuestion.courseCode, 'PHY101');
    });

    test('mcq past question has isTheory == false when options are provided', () {
      const mcqQuestion = PastQuestionEntity(
        id: 'pq_mcq_1',
        examType: ExamCategory.jamb,
        subject: 'Chemistry',
        year: 2023,
        questionNumber: 1,
        prompt: 'What is the pH of a neutral solution at 25°C?',
        options: ['A. 5', 'B. 7', 'C. 9', 'D. 14'],
        correctOptionIndex: 1,
        correctOptionLabel: 'B',
        explanation: 'At 25°C, pure water has [H+] = 10^-7 M, giving a pH of 7.',
        topic: 'Acids and Bases',
      );

      expect(mcqQuestion.isTheory, isFalse);
      expect(mcqQuestion.isUserAdded, isFalse);
    });

    test('PastQuestionModel json serialization roundtrip preserves userAdded, course, and theory data', () {
      const model = PastQuestionModel(
        id: 'pq_custom_99',
        examType: ExamCategory.waec,
        subject: 'Biology',
        year: 2022,
        questionNumber: 5,
        prompt: 'Explain the process of glycolysis.',
        options: [],
        correctOptionIndex: 0,
        correctOptionLabel: '',
        explanation: 'Glycolysis breaks down 1 glucose molecule into 2 pyruvate molecules producing 2 ATP net.',
        topic: 'Cellular Respiration',
        imageUrl: '/path/to/diagram.png',
        isUserAdded: true,
        courseId: 'bio_201',
        courseCode: 'BIO201',
      );

      final json = model.toJson();
      expect(json['is_user_added'], isTrue);
      expect(json['course_id'], 'bio_201');
      expect(json['course_code'], 'BIO201');
      expect(json['options'], isEmpty);

      final deserialized = PastQuestionModel.fromJson(json);
      expect(deserialized.id, 'pq_custom_99');
      expect(deserialized.isUserAdded, isTrue);
      expect(deserialized.courseId, 'bio_201');
      expect(deserialized.courseCode, 'BIO201');
      expect(deserialized.options, isEmpty);

      final entity = deserialized.toEntity();
      expect(entity.isTheory, isTrue);
      expect(entity.isUserAdded, isTrue);
      expect(entity.courseId, 'bio_201');
      expect(entity.courseCode, 'BIO201');
      expect(entity.imageUrl, '/path/to/diagram.png');
    });

    test('QuizQuestionEntity.fromPastQuestion maps theory questions to shortAnswer type', () {
      const theoryPq = PastQuestionEntity(
        id: 'pq_theory_test',
        examType: ExamCategory.waec,
        subject: 'Mathematics',
        year: 2024,
        questionNumber: 2,
        prompt: 'Differentiate y = sin(3x) with respect to x.',
        options: [],
        correctOptionIndex: 0,
        correctOptionLabel: '',
        explanation: 'dy/dx = 3cos(3x) by the chain rule.',
        topic: 'Calculus',
        isUserAdded: true,
      );

      final quizQuestion = QuizQuestionEntity.fromPastQuestion(theoryPq);
      expect(quizQuestion.type, QuizQuestionType.shortAnswer);
      expect(quizQuestion.options, isEmpty);
      expect(quizQuestion.correctAnswer, 'dy/dx = 3cos(3x) by the chain rule.');
    });

    test('QuizQuestionEntity.fromPastQuestion maps mcq questions to multipleChoice type', () {
      const mcqPq = PastQuestionEntity(
        id: 'pq_mcq_test',
        examType: ExamCategory.jamb,
        subject: 'Mathematics',
        year: 2024,
        questionNumber: 3,
        prompt: 'If 2^x = 32, find x.',
        options: ['A. 2', 'B. 3', 'C. 4', 'D. 5'],
        correctOptionIndex: 3,
        correctOptionLabel: 'D',
        explanation: '32 = 2^5, hence x = 5.',
        topic: 'Indices',
      );

      final quizQuestion = QuizQuestionEntity.fromPastQuestion(mcqPq);
      expect(quizQuestion.type, QuizQuestionType.multipleChoice);
      expect(quizQuestion.options.length, 4);
      expect(quizQuestion.correctAnswer, 'D. 5');
    });
  });
}
