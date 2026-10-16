import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/domain/services/day_one_diagnostic_service.dart';

void main() {
  group('DayOneDiagnosticService Unit Tests', () {
    const service = DayOneDiagnosticService();

    test('Generates exactly 15 diagnostic questions for JAMB track', () async {
      final questions = await service.generateDiagnosticQuestions(
        trackOrExamName: 'JAMB / UTME Examination',
      );

      expect(questions.length, equals(15));
      expect(questions.every((q) => q.prompt.isNotEmpty), isTrue);
      expect(questions.every((q) => q.options.length >= 4), isTrue);
      expect(questions.every((q) => q.options.contains(q.correctAnswer)), isTrue);
    });

    test('Generates exactly 15 diagnostic questions for WAEC track', () async {
      final questions = await service.generateDiagnosticQuestions(
        trackOrExamName: 'WAEC WASSCE Senior Secondary',
      );

      expect(questions.length, equals(15));
      expect(questions.every((q) => q.explanation.isNotEmpty), isTrue);
    });

    test('Respects custom totalQuestions parameter', () async {
      final questions = await service.generateDiagnosticQuestions(
        trackOrExamName: 'SAT Track',
        totalQuestions: 10,
      );

      expect(questions.length, equals(10));
    });

    test('Safely handles unknown track by falling back to general diagnostic pool', () async {
      final questions = await service.generateDiagnosticQuestions(
        trackOrExamName: 'Custom Experimental Exam',
      );

      expect(questions.length, equals(15));
    });
  });
}
