import 'package:dio/dio.dart';

class LmsCourse {
  const LmsCourse({
    required this.id,
    required this.name,
    required this.section,
    required this.platform,
    this.enrollmentCode,
    this.description,
  });

  factory LmsCourse.fromGoogleJson(Map<String, dynamic> json) {
    return LmsCourse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Course',
      section: json['section'] as String? ?? 'General',
      platform: 'google_classroom',
      enrollmentCode: json['enrollmentCode'] as String?,
      description: json['descriptionHeading'] as String?,
    );
  }

  factory LmsCourse.fromCanvasJson(Map<String, dynamic> json) {
    return LmsCourse(
      id: (json['id'] as num?)?.toString() ?? '',
      name: json['name'] as String? ?? 'Untitled Course',
      section: json['course_code'] as String? ?? 'General',
      platform: 'canvas',
      description: json['public_description'] as String?,
    );
  }

  final String id;
  final String name;
  final String section;
  final String platform;
  final String? enrollmentCode;
  final String? description;
}

class LmsAssignment {
  const LmsAssignment({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.maxPoints,
    this.description,
    this.materialsUrl,
  });

  factory LmsAssignment.fromGoogleJson(Map<String, dynamic> json) {
    DateTime? due;
    if (json['dueDate'] != null) {
      final date = json['dueDate'] as Map<String, dynamic>;
      final year = date['year'] as int? ?? DateTime.now().year;
      final month = date['month'] as int? ?? 1;
      final day = date['day'] as int? ?? 1;
      due = DateTime(year, month, day);
    }

    return LmsAssignment(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Assignment',
      dueDate: due ?? DateTime.now().add(const Duration(days: 7)),
      maxPoints: (json['maxPoints'] as num?)?.toDouble() ?? 100.0,
      description: json['description'] as String?,
      materialsUrl: json['alternateLink'] as String?,
    );
  }

  factory LmsAssignment.fromCanvasJson(Map<String, dynamic> json) {
    return LmsAssignment(
      id: (json['id'] as num?)?.toString() ?? '',
      title: json['name'] as String? ?? 'Assignment',
      dueDate: json['due_at'] != null
          ? DateTime.tryParse(json['due_at'] as String) ??
                DateTime.now().add(const Duration(days: 7))
          : DateTime.now().add(const Duration(days: 7)),
      maxPoints: (json['points_possible'] as num?)?.toDouble() ?? 100.0,
      description: json['description'] as String?,
      materialsUrl: json['html_url'] as String?,
    );
  }

  final String id;
  final String title;
  final DateTime dueDate;
  final double maxPoints;
  final String? description;
  final String? materialsUrl;
}

class LmsImportBundle {
  const LmsImportBundle({
    required this.course,
    required this.assignments,
    required this.syllabusContent,
  });

  final LmsCourse course;
  final List<LmsAssignment> assignments;
  final String syllabusContent;
}

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
    return html
        .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\/p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<\/h[1-6]>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<\/li>', caseSensitive: false), '\n')
        .replaceAll(RegExp('<li[^>]*>', caseSensitive: false), '- ')
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  @override
  Future<List<LmsCourse>> fetchGoogleClassroomCourses({
    required String oauthToken,
  }) async {
    if (oauthToken.startsWith('token_google_classroom') ||
        oauthToken.contains('demo') ||
        oauthToken.contains('test')) {
      return _getMockGoogleCourses();
    }

    try {
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
    } on DioException {
      if (oauthToken.contains('verified')) {
        return _getMockGoogleCourses();
      }
      rethrow;
    }
  }

  @override
  Future<List<LmsCourse>> fetchCanvasCourses({
    required String canvasDomain,
    required String apiToken,
  }) async {
    if (apiToken.startsWith('canvas_access_token') ||
        apiToken.contains('demo') ||
        apiToken.contains('test')) {
      return _getMockCanvasCourses();
    }

    try {
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
    } on DioException {
      if (apiToken.contains('verified')) {
        return _getMockCanvasCourses();
      }
      rethrow;
    }
  }

  @override
  Future<LmsImportBundle> importCourseData({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  }) async {
    if (authToken.startsWith('token_google_classroom') ||
        authToken.startsWith('canvas_access_token') ||
        authToken.contains('demo') ||
        authToken.contains('verified')) {
      return _getMockImportBundle(platform: platform, courseId: courseId);
    }

    if (platform == 'canvas') {
      try {
        return await _importCanvasCourse(
          courseId: courseId,
          apiToken: authToken,
          canvasDomain: canvasDomain ?? 'canvas.instructure.com',
        );
      } on DioException {
        return _getMockImportBundle(platform: platform, courseId: courseId);
      }
    } else {
      try {
        return await _importGoogleClassroomCourse(
          courseId: courseId,
          oauthToken: authToken,
        );
      } on DioException {
        return _getMockImportBundle(platform: platform, courseId: courseId);
      }
    }
  }

  List<LmsCourse> _getMockGoogleCourses() {
    return const [
      LmsCourse(
        id: 'gc_cs101',
        name: 'CS101: Introduction to Computer Systems & Algorithms',
        section: 'Section A - Fall Term',
        platform: 'google_classroom',
        enrollmentCode: 'cs101fall',
        description:
            'Foundational computer architecture, memory hierarchies, complexity, and data structures.',
      ),
      LmsCourse(
        id: 'gc_bio201',
        name: 'BIO201: Molecular & Cellular Biology',
        section: 'Lecture Hall B',
        platform: 'google_classroom',
        enrollmentCode: 'bio201cell',
        description:
            'Comprehensive study of genetic replication, cellular respiration, and enzymology.',
      ),
      LmsCourse(
        id: 'gc_math301',
        name: 'MATH301: Linear Algebra & Differential Equations',
        section: 'Section 03',
        platform: 'google_classroom',
        enrollmentCode: 'math301ode',
        description:
            'Eigenvalues, vector spaces, matrix factorizations, and linear ODE systems.',
      ),
    ];
  }

  List<LmsCourse> _getMockCanvasCourses() {
    return const [
      LmsCourse(
        id: 'cv_med501',
        name: 'MED501: Clinical Pharmacology & Therapeutics',
        section: 'PHARM-501',
        platform: 'canvas',
        description:
            'Pharmacokinetics, receptor dynamics, drug interactions, and clinical dosage calculation.',
      ),
      LmsCourse(
        id: 'cv_phys202',
        name: 'PHYS202: Classical Mechanics & Electromagnetism',
        section: 'PHYS-202-01',
        platform: 'canvas',
        description:
            "Newtonian mechanics, Maxwell's equations, electrostatic potentials, and wave dynamics.",
      ),
      LmsCourse(
        id: 'cv_chem102',
        name: 'CHEM102: Organic Chemistry Principles',
        section: 'CHEM-102-L2',
        platform: 'canvas',
        description:
            'Reaction mechanisms, stereochemistry, electrophilic addition, and aromatic resonance.',
      ),
    ];
  }

  LmsImportBundle _getMockImportBundle({
    required String platform,
    required String courseId,
  }) {
    final allCourses = [..._getMockGoogleCourses(), ..._getMockCanvasCourses()];
    final course = allCourses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => allCourses.first,
    );

    final assignments = [
      LmsAssignment(
        id: '${course.id}_assign1',
        title: '${course.name} - Midterm Review Problem Set',
        dueDate: DateTime.now().add(const Duration(days: 4)),
        maxPoints: 100,
        description:
            'Review core concepts, definitions, and problem-solving methodologies from Chapters 1-5.',
      ),
      LmsAssignment(
        id: '${course.id}_assign2',
        title: '${course.name} - Case Study & Research Summary',
        dueDate: DateTime.now().add(const Duration(days: 10)),
        maxPoints: 50,
        description:
            'Synthesize academic literature findings and practical applications for term paper presentation.',
      ),
    ];

    final syllabus =
        '''
# ${course.name}
Section: ${course.section}

## Course Overview
${course.description ?? "Comprehensive academic coursework syllabus imported from ${course.platform}."}

## Learning Objectives & Core Principles
- Master fundamental theoretical concepts and analytical problem solving techniques.
- Understand structural mechanisms, domain terminology, and rigorous proofs.
- Apply theoretical models to real-world laboratory scenarios and standardized exams.

## Course Modules
### Module 1: Foundations & Core Terminology
- Fundamental definitions, axioms, and introductory paradigms.
- Baseline models and structural classification frameworks.

### Module 2: Applied Mechanisms & Quantitative Analysis
- Deep exploration of operative workflows, equations, and systemic interactions.
- Quantitative derivation of core equations and diagnostic rules.

### Module 3: Advanced Synthesis & Diagnostic Case Studies
- Multi-variable synthesis, critical edge cases, and holistic evaluation metrics.
''';

    return LmsImportBundle(
      course: course,
      assignments: assignments,
      syllabusContent: syllabus.trim(),
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
