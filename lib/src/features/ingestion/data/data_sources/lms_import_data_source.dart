import 'package:dio/dio.dart';
import 'package:kortex/src/features/ingestion/data/services/html_entity_decoder.dart';
import 'package:kortex/src/features/ingestion/domain/entities/lms_course_entity.dart';

export 'package:kortex/src/features/ingestion/domain/entities/lms_course_entity.dart';

abstract class LmsImportDataSource {
  Future<List<LmsCourse>> fetchGoogleClassroomCourses({
    required String oauthToken,
  });

  Future<List<LmsCourse>> fetchCanvasCourses({
    required String canvasDomain,
    required String apiToken,
  });

  Future<LmsImportBundle> importCourseData({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  });
}

class LmsImportDataSourceImpl implements LmsImportDataSource {
  LmsImportDataSourceImpl({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  String _cleanDomain(String domain) {
    return domain
        .replaceAll(RegExp('^https?://'), '')
        .replaceAll(RegExp(r'/.*$'), '')
        .trim();
  }

  static String stripHtml(String? html) {
    if (html == null || html.isEmpty) return '';
    final stripped = html
        .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\/p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<\/h[1-6]>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<\/li>', caseSensitive: false), '\n')
        .replaceAll(RegExp('<li[^>]*>', caseSensitive: false), '- ')
        .replaceAll(RegExp('<[^>]*>'), '');

    return HtmlEntityDecoder.decode(stripped)
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  @override
  Future<List<LmsCourse>> fetchGoogleClassroomCourses({
    required String oauthToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://classroom.googleapis.com/v1/courses',
      queryParameters: {'courseStates': 'ACTIVE'},
      options: Options(
        headers: {'Authorization': 'Bearer $oauthToken'},
      ),
    );

    final coursesRaw = response.data?['courses'] as List<dynamic>? ?? [];
    return coursesRaw
        .cast<Map<String, dynamic>>()
        .map(LmsCourse.fromGoogleJson)
        .toList();
  }

  @override
  Future<List<LmsCourse>> fetchCanvasCourses({
    required String canvasDomain,
    required String apiToken,
  }) async {
    final domain = _cleanDomain(canvasDomain);
    final response = await _dio.get<List<dynamic>>(
      'https://$domain/api/v1/courses',
      queryParameters: {
        'enrollment_state': 'active',
        'include[]': ['syllabus_body', 'total_students'],
      },
      options: Options(
        headers: {'Authorization': 'Bearer $apiToken'},
      ),
    );

    final rawList = response.data ?? [];
    return rawList
        .cast<Map<String, dynamic>>()
        .where(
          (c) => c['name'] != null && (c['name'] as String).trim().isNotEmpty,
        )
        .map(LmsCourse.fromCanvasJson)
        .toList();
  }

  @override
  Future<LmsImportBundle> importCourseData({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  }) async {
    if (platform == 'canvas') {
      return _importCanvasCourse(
        courseId: courseId,
        apiToken: authToken,
        canvasDomain: canvasDomain ?? 'canvas.instructure.com',
      );
    }

    return _importGoogleClassroomCourse(
      courseId: courseId,
      oauthToken: authToken,
    );
  }



  Future<LmsImportBundle> _importGoogleClassroomCourse({
    required String courseId,
    required String oauthToken,
  }) async {
    final headers = {'Authorization': 'Bearer $oauthToken'};

    // 1. Fetch course details
    final courseResp = await _dio.get<Map<String, dynamic>>(
      'https://classroom.googleapis.com/v1/courses/$courseId',
      options: Options(headers: headers),
    );
    final course = LmsCourse.fromGoogleJson(courseResp.data ?? {});

    // 2. Fetch coursework (assignments)
    var assignments = <LmsAssignment>[];
    try {
      final workResp = await _dio.get<Map<String, dynamic>>(
        'https://classroom.googleapis.com/v1/courses/$courseId/courseWork',
        options: Options(headers: headers),
      );
      final workList = workResp.data?['courseWork'] as List<dynamic>? ?? [];
      assignments = workList
          .cast<Map<String, dynamic>>()
          .map(LmsAssignment.fromGoogleJson)
          .toList();
    } on Object catch (_) {
      // Coursework might not exist or student has no permission
    }

    // 3. Fetch announcements / course updates
    final announcementsText = StringBuffer();
    try {
      final annResp = await _dio.get<Map<String, dynamic>>(
        'https://classroom.googleapis.com/v1/courses/$courseId/announcements',
        queryParameters: {'pageSize': 20},
        options: Options(headers: headers),
      );
      final annList = annResp.data?['announcements'] as List<dynamic>? ?? [];
      for (final a in annList.cast<Map<String, dynamic>>()) {
        final text = a['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          announcementsText.writeln('- ${text.trim()}');
        }
      }
    } on Object catch (_) {
      // Announcements may be empty
    }

    // Assemble dynamic syllabus
    final syllabusBuffer = StringBuffer();
    if (course.description != null && course.description!.trim().isNotEmpty) {
      syllabusBuffer.writeln(
        '## Course Overview\n${course.description!.trim()}\n',
      );
    }

    if (announcementsText.isNotEmpty) {
      syllabusBuffer.writeln(
        '## Announcements & Course Materials\n$announcementsText\n',
      );
    }

    if (assignments.isNotEmpty) {
      syllabusBuffer.writeln('## Coursework & Assignments');
      for (final assign in assignments) {
        syllabusBuffer.writeln('### ${assign.title}');
        if (assign.description != null &&
            assign.description!.trim().isNotEmpty) {
          syllabusBuffer.writeln(assign.description!.trim());
        }
        syllabusBuffer.writeln(
          'Due: ${assign.dueDate.toIso8601String().split('T').first} | Points: ${assign.maxPoints.toInt()}\n',
        );
      }
    }

    if (syllabusBuffer.isEmpty) {
      syllabusBuffer.writeln(
        '# ${course.name}\n${course.section}\nAcademic course materials imported from Google Classroom.',
      );
    }

    return LmsImportBundle(
      course: course,
      assignments: assignments,
      syllabusContent: syllabusBuffer.toString().trim(),
    );
  }

  Future<LmsImportBundle> _importCanvasCourse({
    required String courseId,
    required String apiToken,
    required String canvasDomain,
  }) async {
    final domain = _cleanDomain(canvasDomain);
    final headers = {'Authorization': 'Bearer $apiToken'};

    // 1. Fetch course details with syllabus_body
    final courseResp = await _dio.get<Map<String, dynamic>>(
      'https://$domain/api/v1/courses/$courseId',
      queryParameters: {
        'include[]': ['syllabus_body'],
      },
      options: Options(headers: headers),
    );
    final courseData = courseResp.data ?? {};
    final course = LmsCourse.fromCanvasJson(courseData);
    final rawSyllabus = courseData['syllabus_body'] as String? ?? '';
    final cleanedSyllabus = stripHtml(rawSyllabus);

    // 2. Fetch assignments
    var assignments = <LmsAssignment>[];
    try {
      final assignResp = await _dio.get<List<dynamic>>(
        'https://$domain/api/v1/courses/$courseId/assignments',
        queryParameters: {
          'per_page': 50,
          'order_by': 'due_at',
        },
        options: Options(headers: headers),
      );
      final rawAssigns = assignResp.data ?? [];
      assignments = rawAssigns.cast<Map<String, dynamic>>().map((json) {
        final cleaned = Map<String, dynamic>.from(json);
        if (cleaned['description'] is String) {
          cleaned['description'] = stripHtml(cleaned['description'] as String);
        }
        return LmsAssignment.fromCanvasJson(cleaned);
      }).toList();
    } on Object catch (_) {
      // Assignments might be empty or restricted
    }

    // 3. Fetch modules
    final modulesBuffer = StringBuffer();
    try {
      final modulesResp = await _dio.get<List<dynamic>>(
        'https://$domain/api/v1/courses/$courseId/modules',
        queryParameters: {
          'include[]': ['items'],
          'per_page': 30,
        },
        options: Options(headers: headers),
      );
      final rawModules = modulesResp.data ?? [];
      for (final mod in rawModules.cast<Map<String, dynamic>>()) {
        final modName = mod['name'] as String? ?? 'Module';
        modulesBuffer.writeln('### $modName');
        final items = mod['items'] as List<dynamic>? ?? [];
        for (final item in items.cast<Map<String, dynamic>>()) {
          final title = item['title'] as String? ?? '';
          final type = item['type'] as String? ?? '';
          if (title.isNotEmpty) {
            modulesBuffer.writeln('- [$type] $title');
          }
        }
        modulesBuffer.writeln();
      }
    } on Object catch (_) {
      // Modules might be empty or restricted
    }

    // Assemble dynamic syllabus
    final syllabusBuffer = StringBuffer();
    if (cleanedSyllabus.isNotEmpty) {
      syllabusBuffer.writeln('## Syllabus\n$cleanedSyllabus\n');
    }

    if (modulesBuffer.isNotEmpty) {
      syllabusBuffer.writeln('## Course Modules\n$modulesBuffer\n');
    }

    if (assignments.isNotEmpty) {
      syllabusBuffer.writeln('## Assignments & Problem Sets');
      for (final assign in assignments) {
        syllabusBuffer.writeln(
          '### ${assign.title} (Points: ${assign.maxPoints.toInt()})',
        );
        final desc = assign.description;
        if (desc != null && desc.isNotEmpty) {
          syllabusBuffer.writeln(desc);
        }
        syllabusBuffer.writeln(
          'Due: ${assign.dueDate.toIso8601String().split('T').first}\n',
        );
      }
    }

    if (syllabusBuffer.isEmpty) {
      syllabusBuffer.writeln(
        '# ${course.name}\n${course.section}\nAcademic course materials imported from Canvas LMS.',
      );
    }

    return LmsImportBundle(
      course: course,
      assignments: assignments,
      syllabusContent: syllabusBuffer.toString().trim(),
    );
  }
}
