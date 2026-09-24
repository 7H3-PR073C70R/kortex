import 'package:flutter/material.dart';

/// Categorization of an academic milestone or evaluation.
enum AssessmentType {
  quiz,
  classTest,
  midterm,
  finalExam,
  mockExam,
  custom;

  /// User-facing human readable title
  String get displayName => switch (this) {
    AssessmentType.quiz => 'Quiz',
    AssessmentType.classTest => 'Test / CA',
    AssessmentType.midterm => 'Mid-Term',
    AssessmentType.finalExam => 'Final Exam',
    AssessmentType.mockExam => 'Mock Exam',
    AssessmentType.custom => 'Assessment',
  };

  /// Distinctive icon for each evaluation type
  IconData get icon => switch (this) {
    AssessmentType.quiz => Icons.bolt_rounded,
    AssessmentType.classTest => Icons.assignment_outlined,
    AssessmentType.midterm => Icons.auto_stories_rounded,
    AssessmentType.finalExam => Icons.school_rounded,
    AssessmentType.mockExam => Icons.psychology_rounded,
    AssessmentType.custom => Icons.event_note_rounded,
  };

  /// Default preparation horizon days recommended when scheduling
  int get suggestedDaysAhead => switch (this) {
    AssessmentType.quiz => 3,
    AssessmentType.classTest => 7,
    AssessmentType.midterm => 21,
    AssessmentType.finalExam => 60,
    AssessmentType.mockExam => 30,
    AssessmentType.custom => 14,
  };

  /// Generates a contextual default name given a course code (e.g. MTH 101 Quiz)
  String defaultNameForCourse(String courseCode) {
    final clean = courseCode.trim();
    final prefix = clean.isNotEmpty ? clean : 'Course';
    return switch (this) {
      AssessmentType.quiz => '$prefix Quiz',
      AssessmentType.classTest => '$prefix Test',
      AssessmentType.midterm => '$prefix Mid-Term Exam',
      AssessmentType.finalExam => '$prefix Final Exam',
      AssessmentType.mockExam => '$prefix Mock Exam',
      AssessmentType.custom => '$prefix Assessment',
    };
  }

  /// Parses a string into an AssessmentType safely with fallback to finalExam
  static AssessmentType fromString(String? value) {
    if (value == null) return AssessmentType.finalExam;
    return switch (value.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '')) {
      'quiz' => AssessmentType.quiz,
      'test' || 'classtest' || 'ca' || 'continuousassessment' =>
        AssessmentType.classTest,
      'midterm' || 'midtermexam' => AssessmentType.midterm,
      'final' || 'finalexam' => AssessmentType.finalExam,
      'mock' || 'mockexam' => AssessmentType.mockExam,
      _ => AssessmentType.custom,
    };
  }
}
