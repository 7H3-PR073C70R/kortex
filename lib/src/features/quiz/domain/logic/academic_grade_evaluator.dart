import 'package:flutter/material.dart';

/// Represents a standardized real-world academic grade assessment.
class AcademicGradeResult {
  const AcademicGradeResult({
    required this.grade,
    required this.classification,
    required this.remark,
    required this.standard,
    required this.scorePercent,
    required this.isPass,
    required this.gradeColor,
  });

  /// The grade letter or code (e.g., "A1", "B2", "C4", "1st Class", "310/400").
  final String grade;

  /// The classification label (e.g., "Distinction", "Very Good", "Credit", "First Class Honors").
  final String classification;

  /// Pedagogical remark or matriculation guidance.
  final String remark;

  /// The governing examination standard (e.g., "WASSCE / WAEC Standard", "JAMB / UTME Standard", "University Degree Standard").
  final String standard;

  /// The percentage achieved (0 - 100).
  final double scorePercent;

  /// Whether this grade constitutes a passing mark.
  final bool isPass;

  /// Associated UI indicator color.
  final Color gradeColor;

  String get fullBadgeText => '$grade • $classification';
}

/// Evaluates raw assessment percentages against real-world standardized curricula.
class AcademicGradeEvaluator {
  const AcademicGradeEvaluator();

  /// Evaluates the grade based on target track and achieved percentage.
  static AcademicGradeResult evaluate({
    required double scorePercent,
    String? track,
  }) {
    final cleanTrack = (track ?? '').toUpperCase();
    final clamped = scorePercent.clamp(0.0, 100.0);

    // 1. JAMB / UTME CBT Scale (Scaled out of 400 or per-subject 100)
    if (cleanTrack.contains('JAMB') || cleanTrack.contains('UTME')) {
      final scaledScore = (clamped * 4).round();
      if (clamped >= 75) {
        return AcademicGradeResult(
          grade: '$scaledScore / 400',
          classification: 'Top 5% Competitive Band',
          remark: 'Highly competitive for top-choice competitive university programs (Medicine, Law, Eng).',
          standard: 'JAMB / UTME Standard',
          scorePercent: clamped,
          isPass: true,
          gradeColor: const Color(0xFF10B981), // Emerald
        );
      } else if (clamped >= 60) {
        return AcademicGradeResult(
          grade: '$scaledScore / 400',
          classification: 'Competitive Merit Band',
          remark: 'Solid aggregate score exceeding general federal university cut-off benchmarks.',
          standard: 'JAMB / UTME Standard',
          scorePercent: clamped,
          isPass: true,
          gradeColor: const Color(0xFF06B6D4), // Cyan
        );
      } else if (clamped >= 50) {
        return AcademicGradeResult(
          grade: '$scaledScore / 400',
          classification: 'Eligible Matriculation Band',
          remark: 'Meets minimum institutional cut-off for accredited degree faculties.',
          standard: 'JAMB / UTME Standard',
          scorePercent: clamped,
          isPass: true,
          gradeColor: const Color(0xFFF59E0B), // Amber
        );
      } else {
        return AcademicGradeResult(
          grade: '$scaledScore / 400',
          classification: 'Below Cut-off Threshold',
          remark: 'Target daily high-yield CBT drills to cross the 200+ aggregate boundary.',
          standard: 'JAMB / UTME Standard',
          scorePercent: clamped,
          isPass: false,
          gradeColor: const Color(0xFFEF4444), // Red
        );
      }
    }

    // 2. University Degree / Polytechnic (B.Sc, M.Sc, HND, OND)
    if (cleanTrack.contains('BSC') ||
        cleanTrack.contains('MSC') ||
        cleanTrack.contains('HND') ||
        cleanTrack.contains('OND') ||
        cleanTrack.contains('DEGREE') ||
        cleanTrack.contains('UNIVERSITY')) {
      if (clamped >= 70) {
        return AcademicGradeResult(
          grade: 'A (First Class)',
          classification: 'First Class Honors (4.50 - 5.00 GPA)',
          remark: 'Exemplary academic mastery. Exceptional command of course concepts.',
          standard: 'Tertiary Degree Rubric',
          scorePercent: clamped,
          isPass: true,
          gradeColor: const Color(0xFF10B981),
        );
      } else if (clamped >= 60) {
        return AcademicGradeResult(
          grade: 'B (Second Class Upper)',
          classification: 'Upper Division (3.50 - 4.49 GPA)',
          remark: 'Very strong analytical performance exceeding postgraduate requirements.',
          standard: 'Tertiary Degree Rubric',
          scorePercent: clamped,
          isPass: true,
          gradeColor: const Color(0xFF06B6D4),
        );
      } else if (clamped >= 50) {
        return AcademicGradeResult(
          grade: 'C (Second Class Lower)',
          classification: 'Lower Division (2.40 - 3.49 GPA)',
          remark: 'Good working comprehension meeting graduation criteria.',
          standard: 'Tertiary Degree Rubric',
          scorePercent: clamped,
          isPass: true,
          gradeColor: const Color(0xFFF59E0B),
        );
      } else if (clamped >= 45) {
        return AcademicGradeResult(
          grade: 'D (Third Class)',
          classification: 'Third Class Division (1.50 - 2.39 GPA)',
          remark: 'Passing score. Recommend targeted spaced repetition reviews.',
          standard: 'Tertiary Degree Rubric',
          scorePercent: clamped,
          isPass: true,
          gradeColor: const Color(0xFFF97316),
        );
      } else if (clamped >= 40) {
        return AcademicGradeResult(
          grade: 'E (Pass)',
          classification: 'Pass Degree',
          remark: 'Marginal pass. Critical concept reinforcement recommended.',
          standard: 'Tertiary Degree Rubric',
          scorePercent: clamped,
          isPass: true,
          gradeColor: const Color(0xFFF97316),
        );
      } else {
        return AcademicGradeResult(
          grade: 'F (Carryover)',
          classification: 'Fail / Repeat Course',
          remark: 'Score below academic retention standard. Triage weak deck cards immediately.',
          standard: 'Tertiary Degree Rubric',
          scorePercent: clamped,
          isPass: false,
          gradeColor: const Color(0xFFEF4444),
        );
      }
    }

    // 3. Default / WAEC / WASSCE / NECO (Standard 9-Point Scale)
    if (clamped >= 75) {
      return AcademicGradeResult(
        grade: 'A1',
        classification: 'Distinction (Excellent)',
        remark: 'Outstanding mastery. Fully satisfies direct university admission criteria.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: true,
        gradeColor: const Color(0xFF10B981),
      );
    } else if (clamped >= 70) {
      return AcademicGradeResult(
        grade: 'B2',
        classification: 'Very Good',
        remark: 'Strong academic performance exceeding competitive admission benchmarks.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: true,
        gradeColor: const Color(0xFF14B8A6),
      );
    } else if (clamped >= 65) {
      return AcademicGradeResult(
        grade: 'B3',
        classification: 'Good',
        remark: 'High-quality understanding across core syllabus requirements.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: true,
        gradeColor: const Color(0xFF06B6D4),
      );
    } else if (clamped >= 60) {
      return AcademicGradeResult(
        grade: 'C4',
        classification: 'Credit',
        remark: 'Clear credit pass satisfying STEM and humanities admission prerequisites.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: true,
        gradeColor: const Color(0xFF3B82F6),
      );
    } else if (clamped >= 55) {
      return AcademicGradeResult(
        grade: 'C5',
        classification: 'Credit',
        remark: 'Solid credit grade fulfilling prerequisite course criteria.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: true,
        gradeColor: const Color(0xFF6366F1),
      );
    } else if (clamped >= 50) {
      return AcademicGradeResult(
        grade: 'C6',
        classification: 'Credit',
        remark: 'Valid credit pass qualifying for undergraduate matriculation.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: true,
        gradeColor: const Color(0xFF8B5CF6),
      );
    } else if (clamped >= 45) {
      return AcademicGradeResult(
        grade: 'D7',
        classification: 'Pass',
        remark: 'Passing grade, but may not meet competitive departmental cut-offs.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: true,
        gradeColor: const Color(0xFFF59E0B),
      );
    } else if (clamped >= 40) {
      return AcademicGradeResult(
        grade: 'E8',
        classification: 'Pass',
        remark: 'Weak pass. Further syllabus revision and practice papers advised.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: true,
        gradeColor: const Color(0xFFF97316),
      );
    } else {
      return AcademicGradeResult(
        grade: 'F9',
        classification: 'Fail',
        remark: 'Needs comprehensive review of foundational syllabus topics.',
        standard: 'WASSCE / WAEC Standard',
        scorePercent: clamped,
        isPass: false,
        gradeColor: const Color(0xFFEF4444),
      );
    }
  }
}
