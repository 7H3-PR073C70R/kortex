import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('LmsImportDataSource Unit Test Suite', () {
    late MockDio mockDio;
    late LmsImportDataSourceImpl dataSource;

    setUp(() {
      mockDio = MockDio();
      dataSource = LmsImportDataSourceImpl(dio: mockDio);
    });

    group('HTML Stripping Utility', () {
      test('strips HTML tags and decodes entities properly', () {
        const rawHtml =
            '<h1>Course Syllabus</h1>\n'
            '<p>Welcome to <b>Advanced Mechanics</b> &amp; Energy.<br>\n'
            'Topics include:</p>\n'
            '<ul>\n'
            '<li>Hamiltonian Formulations</li>\n'
            '<li>Chaos &lt; Theory &gt;</li>\n'
            '</ul>\n'
            '<p>Office hours: Mon &amp; Wed&nbsp;2-4pm.</p>';

        final clean = LmsImportDataSourceImpl.stripHtml(rawHtml);

        expect(clean, contains('Course Syllabus'));
        expect(clean, contains('Welcome to Advanced Mechanics & Energy.'));
        expect(clean, contains('- Hamiltonian Formulations'));
        expect(clean, contains('Chaos < Theory >'));
        expect(clean, contains('Mon & Wed 2-4pm.'));
        expect(clean, isNot(contains('<h1')));
        expect(clean, isNot(contains('<p>')));
        expect(clean, isNot(contains('<li>')));
        expect(clean, isNot(contains('&amp;')));
      });

      test('returns empty string on null or empty input', () {
        expect(LmsImportDataSourceImpl.stripHtml(null), equals(''));
        expect(LmsImportDataSourceImpl.stripHtml(''), equals(''));
      });
    });

    group('Google Classroom Live API & Dynamic Aggregation', () {
      test('fetchGoogleClassroomCourses queries Google Classroom API and parses response', () async {
        when(
          () => mockDio.get<Map<String, dynamic>>(
            'https://classroom.googleapis.com/v1/courses',
            queryParameters: {'courseStates': 'ACTIVE'},
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: {
              'courses': [
                {
                  'id': 'real-gc-101',
                  'name': 'Quantum Physics & Relativity',
                  'section': 'PHY301',
                  'descriptionHeading': 'Modern Physics',
                },
              ],
            },
          ),
        );

        final courses = await dataSource.fetchGoogleClassroomCourses(
          oauthToken: 'live_google_oauth_token',
        );

        expect(courses.length, equals(1));
        expect(courses.first.id, equals('real-gc-101'));
        expect(courses.first.name, equals('Quantum Physics & Relativity'));
        expect(courses.first.section, equals('PHY301'));
      });

      test('importCourseData fetches courseWork, announcements, and aggregates dynamic syllabus', () async {
        // Course metadata
        when(
          () => mockDio.get<Map<String, dynamic>>(
            'https://classroom.googleapis.com/v1/courses/course-999',
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: {
              'id': 'course-999',
              'name': 'Differential Equations & Dynamical Systems',
              'section': 'MTH320',
              'descriptionHeading': 'Ordinary and partial differential equations with dynamical systems applications.',
            },
          ),
        );

        // CourseWork (assignments)
        when(
          () => mockDio.get<Map<String, dynamic>>(
            'https://classroom.googleapis.com/v1/courses/course-999/courseWork',
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: {
              'courseWork': [
                {
                  'id': 'cw-1',
                  'title': 'Problem Set 1: Phase Plane Analysis',
                  'dueDate': {'year': 2026, 'month': 10, 'day': 15},
                  'maxPoints': 100,
                  'description': 'Analyze fixed points, linearization, and Hartman-Grobman theorem.',
                },
              ],
            },
          ),
        );

        // Announcements
        when(
          () => mockDio.get<Map<String, dynamic>>(
            'https://classroom.googleapis.com/v1/courses/course-999/announcements',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: {
              'announcements': [
                {
                  'id': 'ann-1',
                  'text': 'Midterm exam will cover Chapters 1 through 5. Bring your formula sheets.',
                },
              ],
            },
          ),
        );

        final bundle = await dataSource.importCourseData(
          platform: 'google_classroom',
          courseId: 'course-999',
          authToken: 'live_google_token_123',
        );

        expect(bundle.course.name, equals('Differential Equations & Dynamical Systems'));
        expect(bundle.assignments.length, equals(1));
        expect(bundle.assignments.first.title, equals('Problem Set 1: Phase Plane Analysis'));
        expect(bundle.syllabusContent, contains('Problem Set 1: Phase Plane Analysis'));
        expect(bundle.syllabusContent, contains('Midterm exam will cover Chapters 1 through 5'));
      });
    });

    group('Canvas Live API & Dynamic Aggregation', () {
      test('fetchCanvasCourses queries Canvas API and filters valid courses', () async {
        when(
          () => mockDio.get<List<dynamic>>(
            'https://canvas.harvard.edu/api/v1/courses',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: [
              {
                'id': 12345,
                'name': 'CS50: Introduction to Computer Science',
                'course_code': 'CS50',
                'public_description': 'Entry-level course on computer science and programming.',
              },
              {
                // Incomplete course object without name
                'id': 99999,
                'name': null,
              },
            ],
          ),
        );

        final courses = await dataSource.fetchCanvasCourses(
          canvasDomain: 'https://canvas.harvard.edu/courses',
          apiToken: 'live_canvas_pat_token',
        );

        expect(courses.length, equals(1));
        expect(courses.first.id, equals('12345'));
        expect(courses.first.name, equals('CS50: Introduction to Computer Science'));
        expect(courses.first.section, equals('CS50'));
      });

      test('importCourseData aggregates syllabus_body, modules, assignments into dynamic syllabus', () async {
        // Course metadata with syllabus_body
        when(
          () => mockDio.get<Map<String, dynamic>>(
            'https://canvas.instructure.com/api/v1/courses/777',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: {
              'id': 777,
              'name': 'Organic Chemistry I',
              'course_code': 'CHEM201',
              'syllabus_body': '<h1>Course Policy</h1><p>Welcome to Organic Chemistry. Grading is based on 3 exams.</p>',
            },
          ),
        );

        // Assignments
        when(
          () => mockDio.get<List<dynamic>>(
            'https://canvas.instructure.com/api/v1/courses/777/assignments',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: [
              {
                'id': 101,
                'name': 'Spectroscopy Lab Report',
                'due_at': '2026-11-20T23:59:00Z',
                'points_possible': 75.0,
                'description': '<p>Submit NMR and IR spectroscopy analysis.</p>',
              },
            ],
          ),
        );

        // Modules
        when(
          () => mockDio.get<List<dynamic>>(
            'https://canvas.instructure.com/api/v1/courses/777/modules',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: [
              {
                'name': 'Module 1: Alkane Nomenclature & Stereochemistry',
                'items': [
                  {'title': 'Newman Projections Reading', 'type': 'Page'},
                  {'title': 'Chirality Problem Set', 'type': 'Assignment'},
                ],
              },
            ],
          ),
        );

        final bundle = await dataSource.importCourseData(
          platform: 'canvas',
          courseId: '777',
          authToken: 'live_canvas_token_xyz',
          canvasDomain: 'canvas.instructure.com',
        );

        expect(bundle.course.name, equals('Organic Chemistry I'));
        expect(bundle.assignments.length, equals(1));
        expect(bundle.assignments.first.description, equals('Submit NMR and IR spectroscopy analysis.'));
        expect(bundle.syllabusContent, contains('Welcome to Organic Chemistry. Grading is based on 3 exams.'));
        expect(bundle.syllabusContent, contains('Module 1: Alkane Nomenclature & Stereochemistry'));
        expect(bundle.syllabusContent, contains('- [Page] Newman Projections Reading'));
        expect(bundle.syllabusContent, contains('Spectroscopy Lab Report (Points: 75)'));
      });
    });

    group('Error Propagation (No Silent Swallowing)', () {
      test('fetchGoogleClassroomCourses propagates DioException on 401 Unauthorized', () async {
        when(
          () => mockDio.get<Map<String, dynamic>>(
            'https://classroom.googleapis.com/v1/courses',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: 401,
              statusMessage: 'Unauthorized',
            ),
          ),
        );

        expect(
          () => dataSource.fetchGoogleClassroomCourses(oauthToken: 'expired_google_token'),
          throwsA(isA<DioException>()),
        );
      });

      test('fetchCanvasCourses propagates DioException on network/auth failure', () async {
        when(
          () => mockDio.get<List<dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: 403,
              statusMessage: 'Forbidden',
            ),
          ),
        );

        expect(
          () => dataSource.fetchCanvasCourses(
            canvasDomain: 'canvas.harvard.edu',
            apiToken: 'invalid_pat_token',
          ),
          throwsA(isA<DioException>()),
        );
      });
    });
  });
}
