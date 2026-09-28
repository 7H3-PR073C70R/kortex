import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/cbt_practice_config_modal_sheet.dart';

void main() {
  group('CbtDirectPastQuestionLaunch Test Suite', () {
    test('generateCourseQuestions creates 20 high-quality fallback questions for course', () {
      const courseId = 'course_csc301';
      const courseCode = 'CSC301';
      const courseTitle = 'Data Structures and Algorithms';

      final questions = CbtPracticeConfigModalSheet.generateCourseQuestions(
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
      );

      expect(questions.length, equals(20));
      expect(questions.first.courseId, equals(courseId));
      expect(questions.first.courseCode, equals(courseCode));
      expect(questions.first.subject, equals(courseTitle));
      expect(questions.first.options.length, equals(4));
      expect(questions.first.examType, equals(ExamCategory.general));
    });

    test('CuratedCourseEntity properties map cleanly for direct CBT launch', () {
      const course = CuratedCourseEntity(
        id: 'c123',
        courseCode: 'MTH101',
        title: 'General Mathematics I',
        department: 'Mathematics',
        totalMaterials: 5,
        hasActivePastPapers: true,
        iconName: 'calculator',
        colorHex: '#10B981',
      );

      expect(course.courseCode, equals('MTH101'));
      expect(course.title, equals('General Mathematics I'));
      expect(course.hasActivePastPapers, isTrue);
    });
  });
}
