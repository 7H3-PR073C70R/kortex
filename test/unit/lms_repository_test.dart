import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:kortex/src/features/ingestion/data/repositories/lms_repository_impl.dart';

class FakeLmsImportDataSource implements LmsImportDataSource {
  @override
  Future<List<LmsCourse>> fetchGoogleClassroomCourses({
    required String oauthToken,
  }) async {
    return [
      const LmsCourse(
        id: 'gc-math-101',
        name: 'Calculus I',
        section: 'MTH101',
        platform: 'google_classroom',
      ),
    ];
  }

  @override
  Future<List<LmsCourse>> fetchCanvasCourses({
    required String canvasDomain,
    required String apiToken,
  }) async {
    return [
      const LmsCourse(
        id: 'canvas-eng-101',
        name: 'Thermodynamics',
        section: 'ENG101',
        platform: 'canvas',
      ),
    ];
  }

  @override
  Future<LmsImportBundle> importCourseData({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  }) async {
    return LmsImportBundle(
      course: LmsCourse(
        id: courseId,
        name: 'Calculus I',
        section: 'MTH101',
        platform: platform,
      ),
      assignments: [
        LmsAssignment(
          id: 'hw-1',
          title: 'Problem Set 1',
          dueDate: DateTime.now().add(const Duration(days: 5)),
          maxPoints: 50,
        ),
      ],
      syllabusContent: 'Derivatives and Integrals',
    );
  }
}

void main() {
  group('LmsRepository Unit Test Suite', () {
    late LmsRepositoryImpl repository;

    setUp(() {
      repository = LmsRepositoryImpl(dataSource: FakeLmsImportDataSource());
    });

    test(
      'fetchGoogleClassroomCourses returns Right with course list',
      () async {
        final result = await repository.fetchGoogleClassroomCourses(
          oauthToken: 'fake-token',
        );

        expect(result.isRight, isTrue);
        result.fold(
          (_) => fail('Expected Right'),
          (courses) {
            expect(courses.length, equals(1));
            expect(courses.first.name, equals('Calculus I'));
          },
        );
      },
    );

    test('fetchCanvasCourses returns Right with canvas courses', () async {
      final result = await repository.fetchCanvasCourses(
        canvasDomain: 'school.instructure.com',
        apiToken: 'fake-token',
      );

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (courses) {
          expect(courses.first.platform, equals('canvas'));
        },
      );
    });

    test('importCourse returns Right with syllabus and assignments', () async {
      final result = await repository.importCourse(
        platform: 'google_classroom',
        courseId: 'gc-math-101',
        authToken: 'token-abc',
      );

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (bundle) {
          expect(bundle.assignments.length, equals(1));
          expect(bundle.syllabusContent, equals('Derivatives and Integrals'));
        },
      );
    });
  });
}
