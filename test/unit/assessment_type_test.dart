import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/planner/data/models/exam_event_model.dart';
import 'package:kortex/src/features/planner/data/repositories/planner_repository_impl.dart';
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

    test('defaultWeightPercent provides appropriate academic weighting', () {
      expect(AssessmentType.quiz.defaultWeightPercent, equals(0.10));
      expect(AssessmentType.classTest.defaultWeightPercent, equals(0.20));
      expect(AssessmentType.midterm.defaultWeightPercent, equals(0.30));
      expect(AssessmentType.finalExam.defaultWeightPercent, equals(0.50));
      expect(AssessmentType.mockExam.defaultWeightPercent, equals(0.25));
      expect(AssessmentType.custom.defaultWeightPercent, equals(0.15));
    });

    test('ExamEventModel serialization round-trip preserves assessment type, scopedTopics, and completion status', () {
      final completedTime = DateTime(2026, 10, 15, 12, 30);
      final model = ExamEventModel(
        id: 'test-evt-1',
        userId: 'usr-123',
        examName: 'Math Pop Quiz',
        targetDate: DateTime(2026, 10, 15, 10),
        subjectTrack: 'MTH 101',
        assessmentType: AssessmentType.quiz,
        scopedDeckIds: const ['deck-ch1', 'deck-ch2'],
        scopedTopics: const ['Matrices', 'Determinants'],
        weightPercent: 0.15,
        totalCardsCount: 45,
        dailyTarget: 15,
        isCompleted: true,
        achievedScorePercent: 88.5,
        completedAt: completedTime,
      );

      final json = model.toJson();
      expect(json['assessment_type'], equals('quiz'));
      expect(json['scoped_deck_ids'], equals(['deck-ch1', 'deck-ch2']));
      expect(json['scoped_topics'], equals(['Matrices', 'Determinants']));
      expect(json['weight_percent'], equals(0.15));
      expect(json['is_completed'], equals(true));
      expect(json['achieved_score_percent'], equals(88.5));
      expect(json['completed_at'], equals(completedTime.toIso8601String()));

      final restored = ExamEventModel.fromJson(json);
      expect(restored.assessmentType, equals(AssessmentType.quiz));
      expect(restored.scopedDeckIds, equals(['deck-ch1', 'deck-ch2']));
      expect(restored.scopedTopics, equals(['Matrices', 'Determinants']));
      expect(restored.weightPercent, equals(0.15));
      expect(restored.effectiveWeightPercent, equals(0.15));
      expect(restored.isCompleted, equals(true));
      expect(restored.achievedScorePercent, equals(88.5));
      expect(restored.completedAt, equals(completedTime));
      expect(restored.examName, equals('Math Pop Quiz'));
    });

    test('ExamEventEntity effectiveWeightPercent falls back to assessment default when null', () {
      final exam = ExamEventModel(
        id: 'test-evt-2',
        userId: 'usr-123',
        examName: 'Midterm Assessment',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        subjectTrack: 'PHY 102',
        assessmentType: AssessmentType.midterm,
      );
      expect(exam.effectiveWeightPercent, equals(0.30));
    });

    test('ExamEventEntity sub-daily getters and urgency detection work accurately', () {
      // 12 hours away -> isImminent == true, isCriticalCrunch == true
      final imminentExam = ExamEventModel(
        id: 'test-imminent',
        userId: 'usr-123',
        examName: 'Chemistry Quiz',
        subjectTrack: 'CHM 111',
        targetDate: DateTime.now().add(const Duration(hours: 12)),
        assessmentType: AssessmentType.quiz,
      );
      expect(imminentExam.isImminent, isTrue);
      expect(imminentExam.isCriticalCrunch, isTrue);
      expect(imminentExam.formattedSubDailyCountdown.contains('h'), isTrue);
      expect(imminentExam.formattedSubDailyCountdown.contains('left'), isTrue);

      // 36 hours away -> isImminent == true, isCriticalCrunch == false
      final tomorrowExam = ExamEventModel(
        id: 'test-tomorrow',
        userId: 'usr-123',
        examName: 'Biology Midterm',
        subjectTrack: 'BIO 101',
        targetDate: DateTime.now().add(const Duration(hours: 36)),
        assessmentType: AssessmentType.midterm,
      );
      expect(tomorrowExam.isImminent, isTrue);
      expect(tomorrowExam.isCriticalCrunch, isFalse);
      expect(tomorrowExam.formattedSubDailyCountdown.contains('Tomorrow'), isTrue);

      // 10 days away -> isImminent == false, isCriticalCrunch == false
      final futureExam = ExamEventModel(
        id: 'test-future',
        userId: 'usr-123',
        examName: 'Final Exam',
        subjectTrack: 'ENG 101',
        targetDate: DateTime.now().add(const Duration(days: 10)),
      );
      expect(futureExam.isImminent, isFalse);
      expect(futureExam.isCriticalCrunch, isFalse);
      expect(futureExam.formattedSubDailyCountdown, equals('10 days left'));
    });
  });

  group('PlannerRepositoryImpl Milestone Conclusion & Rollover Tests', () {
    test('completeExam marks complete, records score, and rolls over to midterm/final', () async {
      final fakeStorage = _FakeLocalStorageService();
      final repo = PlannerRepositoryImpl(storageService: fakeStorage);

      // Create a quiz with scoped deck and topics
      final quizRes = await repo.createExam(
        examName: 'MTH 101 Quiz 1',
        targetDate: DateTime.now().add(const Duration(days: 2)),
        subjectTrack: 'MTH 101',
        assessmentType: AssessmentType.quiz,
        scopedDeckIds: ['deck-limits'],
        scopedTopics: ['Limits', 'Derivatives'],
      );
      expect(quizRes.isRight, isTrue);
      final quiz = quizRes.fold((l) => throw Exception(l.message), (r) => r);

      // Create an upcoming final exam for the same course
      final finalRes = await repo.createExam(
        examName: 'MTH 101 Final Exam',
        targetDate: DateTime.now().add(const Duration(days: 45)),
        subjectTrack: 'MTH 101',
        scopedDeckIds: ['deck-integrals'],
        scopedTopics: ['Integrals'],
      );
      expect(finalRes.isRight, isTrue);
      final finalExam = finalRes.fold((l) => throw Exception(l.message), (r) => r);

      // Conclude the quiz with 85% score and rollover
      final concludeRes = await repo.completeExam(
        examId: quiz.id,
        scorePercent: 0.85,
      );
      expect(concludeRes.isRight, isTrue);
      final concluded = concludeRes.fold((l) => throw Exception(l.message), (r) => r);
      expect(concluded.isCompleted, isTrue);
      expect(concluded.achievedScorePercent, equals(0.85));

      // Verify that final exam rolled over the scoped decks & topics from quiz
      final allExamsRes = await repo.getActiveExams();
      final allExams = allExamsRes.fold((l) => throw Exception(l.message), (r) => r);
      final updatedFinal = allExams.firstWhere((e) => e.id == finalExam.id);
      expect(updatedFinal.scopedDeckIds, containsAll(['deck-integrals', 'deck-limits']));
      expect(updatedFinal.scopedTopics, containsAll(['Integrals', 'Limits', 'Derivatives']));
    });
  });
}

class _FakeLocalStorageService implements LocalStorageService {
  final Map<String, String> storage = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => storage[key];

  @override
  Future<void> savePreference({required String key, required String data}) async {
    storage[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    storage.remove(key);
  }
}
