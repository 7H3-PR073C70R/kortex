import 'package:equatable/equatable.dart';

/// Domain entity representing an imported Learning Management System course.
class LmsCourse extends Equatable {
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

  @override
  List<Object?> get props => [
        id,
        name,
        section,
        platform,
        enrollmentCode,
        description,
      ];
}

/// Domain entity representing an assignment within an LMS course.
class LmsAssignment extends Equatable {
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

  @override
  List<Object?> get props => [
        id,
        title,
        dueDate,
        maxPoints,
        description,
        materialsUrl,
      ];
}

/// Domain bundle holding imported course, syllabus, and assignment entities.
class LmsImportBundle extends Equatable {
  const LmsImportBundle({
    required this.course,
    required this.assignments,
    required this.syllabusContent,
  });

  final LmsCourse course;
  final List<LmsAssignment> assignments;
  final String syllabusContent;

  @override
  List<Object?> get props => [
        course,
        assignments,
        syllabusContent,
      ];
}
