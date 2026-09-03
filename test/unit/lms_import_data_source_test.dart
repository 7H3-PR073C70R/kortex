import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';

void main() {
  group('LmsImportDataSource Unit Test Suite', () {
    late LmsImportDataSourceImpl dataSource;

    setUp(() {
      dataSource = LmsImportDataSourceImpl();
    });

    test(
      'fetchGoogleClassroomCourses returns courses with correct platform',
      () async {
        final courses = await dataSource.fetchGoogleClassroomCourses(
          oauthToken: 'fake-token',
        );

        expect(courses.isNotEmpty, isTrue);
        expect(courses.first.platform, equals('google_classroom'));
      },
    );

    test('fetchCanvasCourses returns courses with canvas platform', () async {
      final courses = await dataSource.fetchCanvasCourses(
        canvasDomain: 'canvas.instructure.com',
        apiToken: 'fake-token',
      );

      expect(courses.isNotEmpty, isTrue);
      expect(courses.first.platform, equals('canvas'));
    });

    test(
      'importCourseData generates bundle with assignments and syllabus',
      () async {
        final bundle = await dataSource.importCourseData(
          platform: 'canvas',
          courseId: 'chem-301',
          authToken: 'token-123',
        );

        expect(bundle.course.id, equals('chem-301'));
        expect(bundle.assignments.length, equals(2));
        expect(bundle.syllabusContent.contains('Module 1'), isTrue);
      },
    );
  });
}
