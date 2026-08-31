import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';

void main() {
  group('Quiz Models & Entities Serialization Test Suite', () {
    test('QuizQuestionModel serialization and parsing', () {
      final json = {
        'id': 'q-101',
        'prompt': 'What is delta G when a system is at equilibrium?',
        'type': 'multipleChoice',
        'options': ['0', '< 0', '> 0', 'Undefined'],
        'correct_answer': '0',
        'explanation': 'At equilibrium, delta G = 0 and delta G_0 = -RT ln K.',
        'sub_topic': 'Thermodynamic Equilibrium',
        'latex_formula': r'\Delta G = 0',
        'user_selected_answer': '0',
        'is_answered': true,
        'is_correct': true,
      };

      final model = QuizQuestionModel.fromJson(json);

      expect(model.id, equals('q-101'));
      expect(model.type, equals(QuizQuestionType.multipleChoice));
      expect(model.options.length, equals(4));
      expect(model.correctAnswer, equals('0'));
      expect(model.subTopic, equals('Thermodynamic Equilibrium'));
      expect(model.isCorrect, isTrue);

      final serialized = model.toJson();
      expect(serialized['id'], equals('q-101'));
      expect(serialized['correct_answer'], equals('0'));
    });

    test('QuizResultModel and TopicWeakness calculation', () {
      const weaknesses = [
        TopicWeakness(
          subTopic: 'Thermodynamics',
          totalQuestions: 4,
          correctCount: 1, // 25% => weak (<70%)
        ),
        TopicWeakness(
          subTopic: 'Kinematics',
          totalQuestions: 4,
          correctCount: 4, // 100% => not weak
        ),
      ];

      const result = QuizResultEntity(
        id: 'res-1',
        quizTitle: 'Physics Mock Exam',
        totalQuestions: 8,
        correctAnswers: 5,
        durationSeconds: 120,
        weaknesses: weaknesses,
      );

      expect(result.scorePercent, equals(63)); // (5/8)*100 = 62.5 => 63
      expect(result.weakSubTopics, contains('Thermodynamics'));
      expect(result.weakSubTopics, isNot(contains('Kinematics')));
    });
  });
}
