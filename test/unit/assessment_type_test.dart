import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/planner/data/models/exam_event_model.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';

void main() {
  group('AssessmentType Domain & Serialization Tests', () {
    test('fromString accurately maps diverse string inputs and fallbacks', () {
      expect(AssessmentType.fromString('quiz'), equals(AssessmentType.quiz));
      expect(AssessmentType.fromString('Quiz'), equals(AssessmentType.quiz));
      expect(AssessmentType.fromString('test'), equals(AssessmentType.classTest));
      expect(
        AssessmentType.fromString('class_test'),
        equals(AssessmentType.classTest),
      );
      expect(
        AssessmentType.fromString('midterm'),
        equals(AssessmentType.midterm),
      );
      expect(
        AssessmentType.fromString('midterm_exam'),
        equals(AssessmentType.midterm),
      );
      expect(
        AssessmentType.fromString('final_exam'),
        equals(AssessmentType.finalExam),
      );
      expect(
        AssessmentType.fromString('mock'),
        equals(AssessmentType.mockExam),
      );
      expect(
        AssessmentType.fromString('custom'),
        equals(AssessmentType.custom),
      );
      expect(
        AssessmentType.fromString(null),
        equals(AssessmentType.finalExam),
      );
      expect(
        AssessmentType.fromString('unknown_val'),
        equals(AssessmentType.custom),
      );
    });

    test('defaultNameForCourse constructs clean titles', () {
      expect(
        AssessmentType.quiz.defaultNameForCourse('MTH 101'),
        equals('MTH 101 Quiz'),
      );
      expect(
        AssessmentType.classTest.defaultNameForCourse('CHM 111'),
        equals('CHM 111 Test'),
      );
      expect(
        AssessmentType.midterm.defaultNameForCourse('PHY 102'),
        equals('PHY 102 Mid-Term Exam'),
      );
      expect(
        AssessmentType.finalExam.defaultNameForCourse('BIO 101'),
        equals('BIO 101 Final Exam'),
      );
      expect(
        AssessmentType.mockExam.defaultNameForCourse('WAEC'),
        equals('WAEC Mock Exam'),
      );
    });

    test('suggestedDaysAhead provides rational horizons', () {
      expect(AssessmentType.quiz.suggestedDaysAhead, equals(3));
      expect(AssessmentType.classTest.suggestedDaysAhead, equals(7));
      expect(AssessmentType.midterm.suggestedDaysAhead, equals(21));
      expect(AssessmentType.finalExam.suggestedDaysAhead, equals(60));
    });

    test('icons are non-null and distinctive', () {
      expect(AssessmentType.quiz.icon, isA<IconData>());
      expect(AssessmentType.classTest.icon, isA<IconData>());
      expect(AssessmentType.midterm.icon, isA<IconData>());
      expect(AssessmentType.finalExam.icon, isA<IconData>());
    });

    test('ExamEventModel serialization round-trip preserves assessment type and scopes', () {
      final model = ExamEventModel(
        id: 'test-evt-1',
        userId: 'usr-123',
        examName: 'Math Pop Quiz',
        targetDate: DateTime(2026, 10, 15, 10),
        subjectTrack: 'MTH 101',
        assessmentType: AssessmentType.quiz,
        scopedDeckIds: const ['deck-ch1', 'deck-ch2'],
        weightPercent: 0.15,
        totalCardsCount: 45,
        dailyTarget: 15,
      );

      final json = model.toJson();
      expect(json['assessment_type'], equals('quiz'));
      expect(json['scoped_deck_ids'], equals(['deck-ch1', 'deck-ch2']));
      expect(json['weight_percent'], equals(0.15));

      final restored = ExamEventModel.fromJson(json);
      expect(restored.assessmentType, equals(AssessmentType.quiz));
      expect(restored.scopedDeckIds, equals(['deck-ch1', 'deck-ch2']));
      expect(restored.weightPercent, equals(0.15));
      expect(restored.examName, equals('Math Pop Quiz'));
    });
  });
}
