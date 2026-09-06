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

  bool _isMockToken(String token) {
    return token.startsWith('demo_') ||
        token.startsWith('mock_') ||
        token == 'fake-token' ||
        token == 'token-123' ||
        token == 'test-mock-token';
  }

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
    if (_isMockToken(oauthToken)) {
      return _mockGoogleClassroomCourses();
    }

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
    if (_isMockToken(apiToken)) {
      return _mockCanvasCourses();
    }

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
        .where((c) => c['name'] != null && (c['name'] as String).trim().isNotEmpty)
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
    if (_isMockToken(authToken)) {
      return _mockImportBundle(platform: platform, courseId: courseId);
    }

    if (platform == 'canvas') {
      return _importCanvasCourse(
        courseId: courseId,
        apiToken: authToken,
        canvasDomain: canvasDomain ?? 'canvas.instructure.com',
      );
    } else {
      return _importGoogleClassroomCourse(
        courseId: courseId,
        oauthToken: authToken,
      );
    }
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
      syllabusBuffer.writeln('## Course Overview\n${course.description!.trim()}\n');
    }

    if (announcementsText.isNotEmpty) {
      syllabusBuffer.writeln('## Announcements & Course Materials\n$announcementsText\n');
    }

    if (assignments.isNotEmpty) {
      syllabusBuffer.writeln('## Coursework & Assignments');
      for (final assign in assignments) {
        syllabusBuffer.writeln('### ${assign.title}');
        if (assign.description != null && assign.description!.trim().isNotEmpty) {
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
      assignments = rawAssigns
          .cast<Map<String, dynamic>>()
          .map((json) {
            final cleaned = Map<String, dynamic>.from(json);
            if (cleaned['description'] is String) {
              cleaned['description'] = stripHtml(cleaned['description'] as String);
            }
            return LmsAssignment.fromCanvasJson(cleaned);
          })
          .toList();
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
        syllabusBuffer.writeln('### ${assign.title} (Points: ${assign.maxPoints.toInt()})');
        final desc = assign.description;
        if (desc != null && desc.isNotEmpty) {
          syllabusBuffer.writeln(desc);
        }
        syllabusBuffer.writeln('Due: ${assign.dueDate.toIso8601String().split('T').first}\n');
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

  List<LmsCourse> _mockGoogleClassroomCourses() {
    return const [
      LmsCourse(
        id: 'gc-phys-101',
        name: 'General Physics: Mechanics & Thermodynamics',
        section: 'PHY101',
        platform: 'google_classroom',
        description: 'Newtonian mechanics, planetary motion, thermodynamics',
      ),
      LmsCourse(
        id: 'gc-calc-201',
        name: 'Multivariable Calculus & Differential Forms',
        section: 'MTH201',
        platform: 'google_classroom',
        description: 'Partial derivatives, Stokes theorem, vector fields',
      ),
    ];
  }

  List<LmsCourse> _mockCanvasCourses() {
    return const [
      LmsCourse(
        id: 'canvas-chem-301',
        name: 'Physical Chemistry & Quantum Kinetics',
        section: 'CHM301',
        platform: 'canvas',
        description: 'Schrodinger equation, chemical equilibrium kinetics',
      ),
      LmsCourse(
        id: 'canvas-bio-101',
        name: 'Cellular Biology & Genetics',
        section: 'BIO101',
        platform: 'canvas',
        description: 'Cell structure, mitosis, Mendelian genetics, gene expression',
      ),
    ];
  }

  LmsImportBundle _mockImportBundle({
    required String platform,
    required String courseId,
  }) {
    final isCanvas = platform == 'canvas';
    final course = LmsCourse(
      id: courseId,
      name: isCanvas
          ? 'Physical Chemistry & Quantum Kinetics'
          : 'General Physics: Mechanics & Thermodynamics',
      section: isCanvas ? 'CHM301' : 'PHY101',
      platform: platform,
      description: isCanvas
          ? 'Comprehensive study of thermodynamics, quantum mechanics, and chemical kinetics.'
          : 'Fundamental mechanics, Newton laws, rotational motion, and thermal physics.',
    );

    final assignments = [
      LmsAssignment(
        id: 'assign-1',
        title: isCanvas
            ? 'Problem Set 1: Schrodinger Wave Mechanics'
            : 'Problem Set 1: Lagrangian Equations of Motion',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        maxPoints: 100,
        description: isCanvas
            ? 'Solve 1D particle in a box and harmonic oscillator eigenstates.'
            : 'Formulate generalized coordinates and solve Euler-Lagrange equations.',
      ),
      LmsAssignment(
        id: 'assign-2',
        title: isCanvas
            ? 'Midterm Review: Chemical Equilibrium & Free Energy'
            : 'Midterm Review: Rigid Body Dynamics & Torque',
        dueDate: DateTime.now().add(const Duration(days: 21)),
        maxPoints: 150,
        description: 'Comprehensive review problems for midterm examination.',
      ),
    ];

    final syllabus = isCanvas
        ? '## Course Syllabus\n'
          '### Module 1: Quantum Foundations\n'
          'Wave-particle duality, de Broglie relations, Heisenberg uncertainty principle.\n\n'
          '### Module 2: Chemical Thermodynamics\n'
          'First and Second Laws, Gibbs Free Energy, Maxwell Relations.\n\n'
          '### Module 3: Reaction Kinetics\n'
          'Transition state theory, Arrhenius rate equations, enzyme kinetics.'
        : '## Course Syllabus\n'
          '### Module 1: Classical Mechanics\n'
          'Kinematics, Newton laws, work-energy theorem, momentum conservation.\n\n'
          '### Module 2: Oscillations & Gravitation\n'
          'Simple harmonic motion, damped oscillations, Kepler laws of planetary motion.\n\n'
          '### Module 3: Thermal Physics\n'
          'Ideal gas laws, kinetic theory, heat transfer mechanisms, entropy.';

    return LmsImportBundle(
      course: course,
      assignments: assignments,
      syllabusContent: syllabus,
    );
  }
}
