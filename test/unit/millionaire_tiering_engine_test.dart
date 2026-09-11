import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/millionaire_tiering_engine.dart';

void main() {
  group('MillionaireTieringEngine Test Suite', () {
    const engine = MillionaireTieringEngine();

    QuizQuestionEntity makeQuestion({
      required String id,
      required String prompt,
      int optionCount = 4,
    }) {
      return QuizQuestionEntity(
        id: id,
        prompt: prompt,
        type: QuizQuestionType.multipleChoice,
        options: List.generate(optionCount, (i) => 'Option $i'),
        correctAnswer: 'Option 0',
        explanation: 'Explanation for $id',
        subTopic: 'Biology',
      );
    }

    test('returns empty list when input questions is empty', () {
      final result = engine.tierQuestions(questions: []);
      expect(result, isEmpty);
    });

    test('tiers 18 questions with retention rates into 3 distinct cognitive difficulty bands', () {
      final questions = List.generate(
        18,
        (i) => makeQuestion(id: 'q$i', prompt: 'Question $i'),
      );

      // q0-q5: Easy (>0.85), q6-q11: Medium (0.60-0.85), q12-q17: Hard (<0.60)
      final retentionMap = <String, double>{
        'q0': 0.95, 'q1': 0.92, 'q2': 0.90, 'q3': 0.88, 'q4': 0.87, 'q5': 0.86,
        'q6': 0.82, 'q7': 0.78, 'q8': 0.75, 'q9': 0.72, 'q10': 0.68, 'q11': 0.64,
        'q12': 0.52, 'q13': 0.45, 'q14': 0.38, 'q15': 0.30, 'q16': 0.22, 'q17': 0.15,
      };

      final tiered = engine.tierQuestions(
        questions: questions,
        retentionEvaluator: (q) => retentionMap[q.id] ?? 0.5,
      );

      expect(tiered.length, equals(12));
      // First 4 questions should be drawn from high retention candidates
      for (var i = 0; i < 4; i++) {
        expect(retentionMap[tiered[i].id], greaterThanOrEqualTo(0.85));
      }
      // Middle 4 questions should be drawn from medium retention candidates
      for (var i = 4; i < 8; i++) {
        expect(retentionMap[tiered[i].id], inInclusiveRange(0.60, 0.85));
      }
      // Last 4 questions should be drawn from hard/low retention candidates
      for (var i = 8; i < 12; i++) {
        expect(retentionMap[tiered[i].id], lessThan(0.60));
      }
    });

    test('uses heuristic fallback when retention evaluator is null', () {
      final questions = [
        // Short prompt -> lower complexity score
        makeQuestion(id: 'short1', prompt: 'What is DNA?'),
        makeQuestion(id: 'short2', prompt: 'Define RNA.'),
        makeQuestion(id: 'short3', prompt: 'Cell unit?'),
        makeQuestion(id: 'short4', prompt: 'What is ATP?'),

        // Long prompt with formulas -> higher complexity score
        makeQuestion(
          id: 'long1',
          prompt: 'Given the equation Delta G = Delta H - T Delta S, calculate enthalpy under standard conditions with extended precision.',
        ),
        makeQuestion(
          id: 'long2',
          prompt: 'Evaluate the integral from 0 to pi of sin(x) dx using the fundamental theorem of calculus and verify boundary values.',
        ),
      ];

      final tiered = engine.tierQuestions(questions: questions, targetCount: 6);

      expect(tiered.length, equals(6));
      // The shortest questions should be sorted earlier than the longest complex ones
      expect(tiered.first.prompt.length, lessThan(tiered.last.prompt.length));
    });

    test('preserves count when question count is less than targetCount', () {
      final questions = [
        makeQuestion(id: 'q1', prompt: 'Question 1'),
        makeQuestion(id: 'q2', prompt: 'Question 2'),
        makeQuestion(id: 'q3', prompt: 'Question 3'),
      ];

      final tiered = engine.tierQuestions(questions: questions);

      expect(tiered.length, equals(3));
    });

    test('curates exactly targetCount when input exceeds targetCount', () {
      final questions = List.generate(
        25,
        (i) => makeQuestion(
          id: 'q$i',
          prompt: 'Question $i with some length',
        ),
      );

      final tiered = engine.tierQuestions(questions: questions);

      expect(tiered.length, equals(12));
    });
  });
}
