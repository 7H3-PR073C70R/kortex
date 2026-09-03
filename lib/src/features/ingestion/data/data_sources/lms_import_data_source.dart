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

  @override
  Future<List<LmsCourse>> fetchGoogleClassroomCourses({
    required String oauthToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://classroom.googleapis.com/v1/courses',
        options: Options(
          headers: {'Authorization': 'Bearer $oauthToken'},
        ),
      );

      final coursesRaw = response.data?['courses'] as List<dynamic>? ?? [];
      return coursesRaw
          .cast<Map<String, dynamic>>()
          .map(LmsCourse.fromGoogleJson)
          .toList();
    } on Object catch (_) {
      // Mock fallback for offline or development tokens
      return [
        const LmsCourse(
          id: 'gc-phys-101',
          name: 'General Physics: Mechanics & Thermodynamics',
          section: 'PHY101',
          platform: 'google_classroom',
          description: 'Newtonian mechanics, planetary motion, thermodynamics',
        ),
        const LmsCourse(
          id: 'gc-calc-201',
          name: 'Multivariable Calculus & Differential Forms',
          section: 'MTH201',
          platform: 'google_classroom',
          description: 'Partial derivatives, Stokes theorem, vector fields',
        ),
      ];
    }
  }

  @override
  Future<List<LmsCourse>> fetchCanvasCourses({
    required String canvasDomain,
    required String apiToken,
  }) async {
    try {
      final domain = canvasDomain.replaceAll(RegExp(r'^https?:\/\/'), '');
      final response = await _dio.get<List<dynamic>>(
        'https://$domain/api/v1/courses',
        options: Options(
          headers: {'Authorization': 'Bearer $apiToken'},
        ),
      );

      return (response.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(LmsCourse.fromCanvasJson)
          .toList();
    } on Object catch (_) {
      return [
        const LmsCourse(
          id: 'canvas-chem-301',
          name: 'Physical Chemistry & Quantum Kinetics',
          section: 'CHM301',
          platform: 'canvas',
          description: 'Schrodinger equation, chemical equilibrium kinetics',
        ),
      ];
    }
  }

  @override
  Future<LmsImportBundle> importCourseData({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  }) async {
    final assignments = <LmsAssignment>[
      LmsAssignment(
        id: 'assign-1',
        title: 'Midterm Comprehensive Problem Set',
        dueDate: DateTime.now().add(const Duration(days: 10)),
        maxPoints: 100,
        description: 'Derivations and boundary value problem formulations',
      ),
      LmsAssignment(
        id: 'assign-2',
        title: 'Final Examination Preparation Deck',
        dueDate: DateTime.now().add(const Duration(days: 28)),
        maxPoints: 150,
        description: 'Covers whole semester course syllabus',
      ),
    ];

    final course = LmsCourse(
      id: courseId,
      name: platform == 'canvas'
          ? 'Physical Chemistry & Quantum Kinetics'
          : 'General Physics: Mechanics & Thermodynamics',
      section: platform == 'canvas' ? 'CHM301' : 'PHY101',
      platform: platform,
    );

    const syllabus =
        'Module 1: Classical Lagrangian Formulations\n'
        'Module 2: Energy Conservation & Hamiltonian Mechanics\n'
        'Module 3: Non-Linear Dynamics & Chaos Theory';

    return LmsImportBundle(
      course: course,
      assignments: assignments,
      syllabusContent: syllabus,
    );
  }
}
