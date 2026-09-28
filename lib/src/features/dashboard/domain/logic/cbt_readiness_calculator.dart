import 'package:flutter/material.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';

/// Represents per-subject mastery diagnostic breakdown for CBT Readiness
class SubjectReadinessBreakdown {
  const SubjectReadinessBreakdown({
    required this.subjectName,
    required this.readinessPercent,
    required this.coveragePercent,
    required this.accuracyPercent,
    required this.projectedScore,
    required this.maxScore,
    this.statusColor,
  });

  final String subjectName;
  final int readinessPercent;
  final double coveragePercent;
  final double accuracyPercent;
  final int projectedScore;
  final int maxScore;
  final Color? statusColor;
}

/// Algorithmic CBT Exam Readiness score calculator based on syllabus coverage,
/// active-recall FSRS card retention rate, CBT mock test scores, target exam date proximity,
/// per-subject mastery breakdown, and speed/time pressure diagnostics.
class CbtReadinessResult {
  const CbtReadinessResult({
    required this.scorePercent,
    required this.statusLabel,
    required this.statusColor,
    required this.syllabusCoverage,
    required this.fsrsRetentionRate,
    required this.mockScoreRatio,
    required this.projectedGrade,
    required this.projectedScoreRange,
    this.remediationSuggestion = '',
    this.weakestAreaLabel = '',
    this.targetExamType = 'JAMB',
    this.targetScoreProbability = 0.85,
    this.speedReadinessRatio = 0.85,
    this.speedDiagnosticLabel = 'Optimal Pace: 48s/item',
    this.targetScoreGoal = 300,
    this.projectedTotalScore = 295,
    this.subjectBreakdowns = const [],
  });

  /// Overall readiness index (0 to 100)
  final int scorePercent;

  /// Human readable diagnostic tag (e.g. "ON TRACK", "ACCELERATE PREP", "NEEDS TRIAGE")
  final String statusLabel;

  /// UI Color associated with the readiness status
  final Color statusColor;

  final double syllabusCoverage;
  final double fsrsRetentionRate;
  final double mockScoreRatio;

  /// Projected letter grade or score band (e.g., "A1", "B2", "320+", "First Class")
  final String projectedGrade;

  /// Projected CBT exam score range (e.g., "290 - 325 / 400" or "A1 (Distinction)")
  final String projectedScoreRange;

  /// Actionable Socratic recommendation to boost score
  final String remediationSuggestion;

  /// Diagnostic identification of the primary bottleneck
  final String weakestAreaLabel;

  /// Target exam scale format ('JAMB', 'WAEC', 'NECO', 'UNIVERSITY')
  final String targetExamType;

  /// Statistically projected target score attainment probability (0.0 to 1.0)
  final double targetScoreProbability;

  /// Speed & time-pressure readiness factor (0.0 to 1.0)
  final double speedReadinessRatio;

  /// Human readable pace diagnostic (e.g. "Optimal Pace: 45s/item" or "Time Risk: 85s/item")
  final String speedDiagnosticLabel;

  /// Target score goal set by scholar (e.g., 300 / 400 for JAMB)
  final int targetScoreGoal;

  /// Exact projected point score (e.g., 295 / 400)
  final int projectedTotalScore;

  /// Difference between target score goal and projected score
  int get scoreGap => projectedTotalScore - targetScoreGoal;

  /// Per-subject readiness breakdown
  final List<SubjectReadinessBreakdown> subjectBreakdowns;
}

/// Representation of a student's registered course for CBT readiness evaluation
class RegisteredCourseInput {
  const RegisteredCourseInput({
    required this.courseCode,
    required this.title,
    required this.syllabusCoverage,
    this.department = 'General',
    this.accuracyPercent,
    this.retentionRate,
    this.iconName = 'school',
    this.colorHex = '#6366F1',
  });

  final String courseCode;
  final String title;
  final double syllabusCoverage;
  final String department;
  final double? accuracyPercent;
  final double? retentionRate;
  final String iconName;
  final String colorHex;

  /// Helper to convert dynamic course lists (CuratedCourseModel, CuratedCourseEntity, Maps)
  static List<RegisteredCourseInput> convertCourses(List<dynamic>? courses) {
    if (courses == null || courses.isEmpty) return const [];
    final result = <RegisteredCourseInput>[];
    for (final c in courses) {
      if (c is RegisteredCourseInput) {
        result.add(c);
      } else if (c is CuratedCourseEntity) {
        result.add(
          RegisteredCourseInput(
            courseCode: c.courseCode,
            title: c.title.isNotEmpty ? c.title : c.courseCode,
            syllabusCoverage: c.syllabusCoverage,
            department: c.department,
            iconName: c.iconName,
            colorHex: c.colorHex,
          ),
        );
      } else if (c is CuratedCourseModel) {
        result.add(
          RegisteredCourseInput(
            courseCode: c.courseCode,
            title: c.title.isNotEmpty ? c.title : c.courseCode,
            syllabusCoverage: c.syllabusCoverage,
            department: c.department,
            iconName: c.iconName,
            colorHex: c.colorHex,
          ),
        );
      } else if (c != null) {
        final code = _extractString(c, 'courseCode') ?? _extractString(c, 'course_code') ?? '';
        final title = _extractString(c, 'title') ?? code;
        final cov = _extractDouble(c, 'syllabusCoverage') ?? _extractDouble(c, 'syllabus_coverage') ?? 0.75;
        final dept = _extractString(c, 'department') ?? 'General';
        final acc = _extractDouble(c, 'accuracyPercent');
        final ret = _extractDouble(c, 'retentionRate');
        final icon = _extractString(c, 'iconName') ?? 'school';
        final color = _extractString(c, 'colorHex') ?? '#6366F1';

        result.add(
          RegisteredCourseInput(
            courseCode: code,
            title: title.isNotEmpty ? title : code,
            syllabusCoverage: cov,
            department: dept,
            accuracyPercent: acc,
            retentionRate: ret,
            iconName: icon,
            colorHex: color,
          ),
        );
      }
    }
    return result;
  }

  static String? _extractString(dynamic obj, String key) {
    if (obj is Map) {
      final val = obj[key];
      return val is String ? val : val?.toString();
    }
    try {
      if (key == 'courseCode') return (obj as dynamic).courseCode as String?;
      if (key == 'course_code') return (obj as dynamic).course_code as String?;
      if (key == 'title') return (obj as dynamic).title as String?;
      if (key == 'department') return (obj as dynamic).department as String?;
      if (key == 'iconName') return (obj as dynamic).iconName as String?;
      if (key == 'colorHex') return (obj as dynamic).colorHex as String?;
    } on Object catch (_) {}
    return null;
  }

  static double? _extractDouble(dynamic obj, String key) {
    if (obj is Map) {
      final val = obj[key];
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }
    try {
      if (key == 'syllabusCoverage') return ((obj as dynamic).syllabusCoverage as num?)?.toDouble();
      if (key == 'syllabus_coverage') return ((obj as dynamic).syllabus_coverage as num?)?.toDouble();
      if (key == 'accuracyPercent') return ((obj as dynamic).accuracyPercent as num?)?.toDouble();
      if (key == 'retentionRate') return ((obj as dynamic).retentionRate as num?)?.toDouble();
    } on Object catch (_) {}
    return null;
  }
}

class CbtReadinessCalculator {
  const CbtReadinessCalculator();

  /// Computes a weighted 0-100% CBT readiness score and projects expected exam grade.
  /// Weights:
  /// - Syllabus Coverage: 30%
  /// - FSRS Active Recall Retention: 35%
  /// - CBT Mock Exam Performance: 25%
  /// - Time Urgency Balance: 10%
  CbtReadinessResult compute({
    required double syllabusCoverage,
    required double fsrsRetentionRate,
    required double mockScoreRatio,
    required int daysRemaining,
    String examType = 'JAMB',
    String? explicitWeakestTopic,
    double averageSecondsPerQuestion = 48.0,
    int targetScoreGoal = 300,
    List<SubjectReadinessBreakdown>? subjectBreakdowns,
    List<dynamic>? registeredCourses,
  }) {
    final convertedRegisteredCourses =
        RegisteredCourseInput.convertCourses(registeredCourses);

    var effectiveSyllabusCoverage = syllabusCoverage.clamp(0.0, 1.0);
    if (convertedRegisteredCourses.isNotEmpty) {
      final totalCov = convertedRegisteredCourses.fold<double>(
        0,
        (sum, item) => sum + item.syllabusCoverage.clamp(0.0, 1.0),
      );
      effectiveSyllabusCoverage =
          (totalCov / convertedRegisteredCourses.length).clamp(0.0, 1.0);
    }

    final cov = effectiveSyllabusCoverage;
    final ret = fsrsRetentionRate.clamp(0.0, 1.0);
    final mock = mockScoreRatio.clamp(0.0, 1.0);

    // Time factor: if exam is further out (> 30 days), lower penalty for uncompleted syllabus.
    final double timeFactor;
    if (daysRemaining <= 0) {
      timeFactor = 1.0;
    } else if (daysRemaining <= 7) {
      timeFactor = 0.70 + (cov * 0.30);
    } else if (daysRemaining <= 30) {
      timeFactor = 0.85 + (cov * 0.15);
    } else {
      timeFactor = 1.0;
    }

    // Speed / Pacing Factor:
    final double speedFactor;
    final String speedDiag;
    if (averageSecondsPerQuestion <= 55) {
      speedFactor = 1.0;
      speedDiag = 'Optimal Pace: ${averageSecondsPerQuestion.round()}s/item';
    } else if (averageSecondsPerQuestion <= 70) {
      speedFactor = 0.85;
      speedDiag = 'Moderate Pace: ${averageSecondsPerQuestion.round()}s/item';
    } else {
      speedFactor = 0.65;
      speedDiag = 'Time Risk: ${averageSecondsPerQuestion.round()}s/item (Slow)';
    }

    final rawWeighted =
        (cov * 0.28) +
        (ret * 0.32) +
        (mock * 0.25) +
        (timeFactor * 0.08) +
        (speedFactor * 0.07);
    final finalPercent = (rawWeighted * 100).round().clamp(0, 100);

    final String label;
    final Color color;
    String grade;
    String scoreRange;
    int projectedPoints;

    final lowerExam = examType.toLowerCase().trim();
    final isWaecOrNeco =
        lowerExam.contains('waec') ||
        lowerExam.contains('neco') ||
        lowerExam.contains('wassce');
    final isUniversity =
        lowerExam.contains('uni') ||
        lowerExam.contains('gpa') ||
        lowerExam.contains('degree');

    if (isWaecOrNeco) {
      projectedPoints = (finalPercent * 0.09).round().clamp(1, 9);
      if (finalPercent >= 85) {
        label = 'ON TRACK';
        color = const Color(0xFF10B981); // Emerald
        grade = 'A1';
        scoreRange = 'A1 (Excellent Distinction)';
      } else if (finalPercent >= 75) {
        label = 'ON TRACK';
        color = const Color(0xFF10B981);
        grade = 'B2';
        scoreRange = 'B2 (Very Good)';
      } else if (finalPercent >= 65) {
        label = 'ACCELERATE PREP';
        color = const Color(0xFFF59E0B);
        grade = 'B3';
        scoreRange = 'B3 (Good)';
      } else if (finalPercent >= 55) {
        label = 'ACCELERATE PREP';
        color = const Color(0xFFF59E0B);
        grade = 'C4';
        scoreRange = 'C4 (Credit)';
      } else if (finalPercent >= 45) {
        label = 'NEEDS TRIAGE';
        color = const Color(0xFFEF4444);
        grade = 'C6';
        scoreRange = 'C6 (Pass Credit)';
      } else {
        label = 'NEEDS TRIAGE';
        color = const Color(0xFFEF4444);
        grade = 'F9';
        scoreRange = 'F9 (Fail / Requires Remediation)';
      }
    } else if (isUniversity) {
      projectedPoints = ((finalPercent / 100.0) * 5.0 * 100).round();
      if (finalPercent >= 85) {
        label = 'ON TRACK';
        color = const Color(0xFF10B981);
        grade = '4.5+ GPA';
        scoreRange = 'First Class Honors (4.50 - 5.00)';
      } else if (finalPercent >= 75) {
        label = 'ON TRACK';
        color = const Color(0xFF10B981);
        grade = '4.0 GPA';
        scoreRange = 'Second Class Upper (3.50 - 4.49)';
      } else if (finalPercent >= 65) {
        label = 'ACCELERATE PREP';
        color = const Color(0xFFF59E0B);
        grade = '3.5 GPA';
        scoreRange = 'Second Class Upper (3.50 - 4.49)';
      } else if (finalPercent >= 55) {
        label = 'ACCELERATE PREP';
        color = const Color(0xFFF59E0B);
        grade = '3.0 GPA';
        scoreRange = 'Second Class Lower (2.40 - 3.49)';
      } else if (finalPercent >= 45) {
        label = 'NEEDS TRIAGE';
        color = const Color(0xFFEF4444);
        grade = '2.5 GPA';
        scoreRange = 'Second Class Lower (2.40 - 3.49)';
      } else {
        label = 'NEEDS TRIAGE';
        color = const Color(0xFFEF4444);
        grade = '< 2.0 GPA';
        scoreRange = 'Third Class / Pass';
      }
    } else {
      // Default JAMB 400-point scale
      projectedPoints = ((finalPercent / 100.0) * 400).round().clamp(100, 380);
      if (finalPercent >= 85) {
        label = 'ON TRACK';
        color = const Color(0xFF10B981);
        grade = '320+';
        scoreRange = '$projectedPoints / 400 (320 - 360 Band)';
      } else if (finalPercent >= 75) {
        label = 'ON TRACK';
        color = const Color(0xFF10B981);
        grade = '280+';
        scoreRange = '$projectedPoints / 400 (280 - 315 Band)';
      } else if (finalPercent >= 65) {
        label = 'ACCELERATE PREP';
        color = const Color(0xFFF59E0B);
        grade = '250+';
        scoreRange = '$projectedPoints / 400 (250 - 279 Band)';
      } else if (finalPercent >= 55) {
        label = 'ACCELERATE PREP';
        color = const Color(0xFFF59E0B);
        grade = '220+';
        scoreRange = '$projectedPoints / 400 (220 - 249 Band)';
      } else if (finalPercent >= 45) {
        label = 'NEEDS TRIAGE';
        color = const Color(0xFFEF4444);
        grade = '190+';
        scoreRange = '$projectedPoints / 400 (190 - 219 Band)';
      } else {
        label = 'NEEDS TRIAGE';
        color = const Color(0xFFEF4444);
        grade = '< 180';
        scoreRange = '$projectedPoints / 400 (< 180 Band)';
      }
    }

    // Build subject breakdowns based on registered courses if available
    final List<SubjectReadinessBreakdown> effectiveSubjectBreakdowns;
    RegisteredCourseInput? weakestCourseInput;
    var lowestCourseReadinessVal = 101;

    if (convertedRegisteredCourses.isNotEmpty) {
      final breakdowns = <SubjectReadinessBreakdown>[];
      for (final course in convertedRegisteredCourses) {
        final courseName = course.title.trim().isNotEmpty
            ? course.title.trim()
            : (course.courseCode.trim().isNotEmpty
                ? course.courseCode.trim()
                : 'Registered Course');

        final courseCov = course.syllabusCoverage.clamp(0.0, 1.0);
        final courseAcc = (course.accuracyPercent ?? mock).clamp(0.0, 1.0);
        final courseRet = (course.retentionRate ?? ret).clamp(0.0, 1.0);

        final courseReadinessVal =
            ((courseCov * 0.40) + (courseAcc * 0.35) + (courseRet * 0.25)) * 100;
        final courseReadinessPercent =
            courseReadinessVal.round().clamp(0, 100);

        final int subjectMaxScore;
        final int subjectProjectedScore;

        if (isWaecOrNeco || isUniversity) {
          subjectMaxScore = 100;
          subjectProjectedScore =
              (courseReadinessPercent * 0.95).round().clamp(0, 100);
        } else {
          subjectMaxScore =
              (400 / convertedRegisteredCourses.length).round().clamp(50, 200);
          subjectProjectedScore =
              ((courseReadinessPercent / 100.0) * subjectMaxScore)
                  .round()
                  .clamp(0, subjectMaxScore);
        }

        final Color statusColor;
        if (courseReadinessPercent >= 75) {
          statusColor = const Color(0xFF10B981);
        } else if (courseReadinessPercent >= 55) {
          statusColor = const Color(0xFFF59E0B);
        } else {
          statusColor = const Color(0xFFEF4444);
        }

        breakdowns.add(
          SubjectReadinessBreakdown(
            subjectName: courseName,
            readinessPercent: courseReadinessPercent,
            coveragePercent: courseCov,
            accuracyPercent: courseAcc,
            projectedScore: subjectProjectedScore,
            maxScore: subjectMaxScore,
            statusColor: statusColor,
          ),
        );

        if (courseReadinessPercent < lowestCourseReadinessVal) {
          lowestCourseReadinessVal = courseReadinessPercent;
          weakestCourseInput = course;
        }
      }
      effectiveSubjectBreakdowns = breakdowns;
    } else {
      effectiveSubjectBreakdowns =
          subjectBreakdowns ??
          _generateDefaultSubjectBreakdowns(
            examType: examType,
            overallScorePercent: finalPercent,
            cov: cov,
            ret: ret,
            mock: mock,
          );
    }

    // Determine primary bottleneck diagnostic
    var weakestArea = explicitWeakestTopic ?? '';
    if (weakestArea.isEmpty) {
      if (weakestCourseInput != null) {
        final courseName = weakestCourseInput.title.trim().isNotEmpty
            ? weakestCourseInput.title.trim()
            : weakestCourseInput.courseCode;
        weakestArea = '$courseName ($lowestCourseReadinessVal% readiness)';
      } else if (speedFactor < 0.8) {
        weakestArea = 'Time Pressure & Solving Speed';
      } else if (ret < cov && ret < mock) {
        weakestArea = 'FSRS Memory Retention';
      } else if (cov < ret && cov < mock) {
        weakestArea = 'Syllabus Module Coverage';
      } else {
        weakestArea = 'Mock Test Speed & Accuracy';
      }
    }

    // Actionable Socratic remediation suggestion
    final String remediation;
    if (finalPercent >= 85) {
      remediation =
          'Maintain momentum with a 10-minute timed mock sprint to lock in distinction status.';
    } else if (weakestCourseInput != null) {
      final courseName = weakestCourseInput.title.trim().isNotEmpty
          ? weakestCourseInput.title.trim()
          : weakestCourseInput.courseCode;
      remediation =
          'Focus on $courseName: Complete 1 topic module & review 15 FSRS flashcards to boost course readiness.';
    } else if (speedFactor < 0.8) {
      remediation =
          'Pacing Alert: Practice 15 timed sprint questions to improve your $speedDiag pace.';
    } else if (ret < 0.70) {
      remediation =
          'Review 15 high-priority FSRS flashcards to repair decaying memory stability.';
    } else if (cov < 0.60) {
      remediation =
          'Complete 1 new syllabus topic module to boost overall syllabus coverage.';
    } else {
      remediation =
          'Take a 15-question CBT Practice Test to improve timed exam confidence.';
    }

    final probability = (finalPercent / 100.0).clamp(0.20, 0.98);

    return CbtReadinessResult(
      scorePercent: finalPercent,
      statusLabel: label,
      statusColor: color,
      syllabusCoverage: cov,
      fsrsRetentionRate: ret,
      mockScoreRatio: mock,
      projectedGrade: grade,
      projectedScoreRange: scoreRange,
      remediationSuggestion: remediation,
      weakestAreaLabel: weakestArea,
      targetExamType: examType,
      targetScoreProbability: probability,
      speedReadinessRatio: speedFactor,
      speedDiagnosticLabel: speedDiag,
      targetScoreGoal: targetScoreGoal,
      projectedTotalScore: projectedPoints,
      subjectBreakdowns: effectiveSubjectBreakdowns,
    );
  }

  static List<SubjectReadinessBreakdown> _generateDefaultSubjectBreakdowns({
    required String examType,
    required int overallScorePercent,
    required double cov,
    required double ret,
    required double mock,
  }) {
    final lower = examType.toLowerCase();

    if (lower.contains('waec') || lower.contains('neco')) {
      return [
        SubjectReadinessBreakdown(
          subjectName: 'English Language',
          readinessPercent: (overallScorePercent * 1.02).round().clamp(0, 100),
          coveragePercent: (cov * 1.05).clamp(0.0, 1.0),
          accuracyPercent: (mock * 1.02).clamp(0.0, 1.0),
          projectedScore: 82,
          maxScore: 100,
          statusColor: const Color(0xFF10B981),
        ),
        SubjectReadinessBreakdown(
          subjectName: 'General Mathematics',
          readinessPercent: (overallScorePercent * 0.95).round().clamp(0, 100),
          coveragePercent: (cov * 0.92).clamp(0.0, 1.0),
          accuracyPercent: (mock * 0.94).clamp(0.0, 1.0),
          projectedScore: 76,
          maxScore: 100,
          statusColor: const Color(0xFF10B981),
        ),
        SubjectReadinessBreakdown(
          subjectName: 'Physics',
          readinessPercent: (overallScorePercent * 0.88).round().clamp(0, 100),
          coveragePercent: (cov * 0.85).clamp(0.0, 1.0),
          accuracyPercent: (ret * 0.88).clamp(0.0, 1.0),
          projectedScore: 68,
          maxScore: 100,
          statusColor: const Color(0xFFF59E0B),
        ),
        SubjectReadinessBreakdown(
          subjectName: 'Chemistry',
          readinessPercent: (overallScorePercent * 0.92).round().clamp(0, 100),
          coveragePercent: (cov * 0.90).clamp(0.0, 1.0),
          accuracyPercent: (mock * 0.91).clamp(0.0, 1.0),
          projectedScore: 74,
          maxScore: 100,
          statusColor: const Color(0xFF10B981),
        ),
        SubjectReadinessBreakdown(
          subjectName: 'Biology',
          readinessPercent: (overallScorePercent * 0.97).round().clamp(0, 100),
          coveragePercent: (cov * 0.98).clamp(0.0, 1.0),
          accuracyPercent: (ret * 0.96).clamp(0.0, 1.0),
          projectedScore: 80,
          maxScore: 100,
          statusColor: const Color(0xFF10B981),
        ),
      ];
    }

    if (lower.contains('uni') || lower.contains('degree')) {
      return [
        SubjectReadinessBreakdown(
          subjectName: 'MTH 101 (Calculus)',
          readinessPercent: (overallScorePercent * 0.96).round().clamp(0, 100),
          coveragePercent: cov,
          accuracyPercent: mock,
          projectedScore: 78,
          maxScore: 100,
          statusColor: const Color(0xFF10B981),
        ),
        SubjectReadinessBreakdown(
          subjectName: 'PHY 101 (General Physics)',
          readinessPercent: (overallScorePercent * 0.88).round().clamp(0, 100),
          coveragePercent: cov * 0.88,
          accuracyPercent: ret * 0.89,
          projectedScore: 71,
          maxScore: 100,
          statusColor: const Color(0xFFF59E0B),
        ),
        SubjectReadinessBreakdown(
          subjectName: 'CHM 101 (General Chemistry)',
          readinessPercent: (overallScorePercent * 0.94).round().clamp(0, 100),
          coveragePercent: cov * 0.93,
          accuracyPercent: mock * 0.95,
          projectedScore: 75,
          maxScore: 100,
          statusColor: const Color(0xFF10B981),
        ),
        SubjectReadinessBreakdown(
          subjectName: 'GST 101 (Use of English)',
          readinessPercent: (overallScorePercent * 1.02).round().clamp(0, 100),
          coveragePercent: (cov * 1.05).clamp(0.0, 1.0),
          accuracyPercent: (ret * 1.02).clamp(0.0, 1.0),
          projectedScore: 84,
          maxScore: 100,
          statusColor: const Color(0xFF10B981),
        ),
      ];
    }

    // Default JAMB UTME (4 subjects, 100 max each -> 400 total)
    final pEng = (overallScorePercent * 0.82).round().clamp(40, 92);
    final pMath = (overallScorePercent * 0.74).round().clamp(35, 88);
    final pPhy = (overallScorePercent * 0.70).round().clamp(30, 85);
    final pChm = (overallScorePercent * 0.76).round().clamp(35, 88);

    return [
      SubjectReadinessBreakdown(
        subjectName: 'Use of English',
        readinessPercent: (overallScorePercent * 1.03).round().clamp(0, 100),
        coveragePercent: (cov * 1.04).clamp(0.0, 1.0),
        accuracyPercent: (ret * 1.02).clamp(0.0, 1.0),
        projectedScore: pEng,
        maxScore: 100,
        statusColor: const Color(0xFF10B981),
      ),
      SubjectReadinessBreakdown(
        subjectName: 'Mathematics',
        readinessPercent: (overallScorePercent * 0.94).round().clamp(0, 100),
        coveragePercent: (cov * 0.92).clamp(0.0, 1.0),
        accuracyPercent: (mock * 0.95).clamp(0.0, 1.0),
        projectedScore: pMath,
        maxScore: 100,
        statusColor: const Color(0xFF10B981),
      ),
      SubjectReadinessBreakdown(
        subjectName: 'Physics',
        readinessPercent: (overallScorePercent * 0.86).round().clamp(0, 100),
        coveragePercent: (cov * 0.84).clamp(0.0, 1.0),
        accuracyPercent: (ret * 0.86).clamp(0.0, 1.0),
        projectedScore: pPhy,
        maxScore: 100,
        statusColor: const Color(0xFFF59E0B),
      ),
      SubjectReadinessBreakdown(
        subjectName: 'Chemistry',
        readinessPercent: (overallScorePercent * 0.92).round().clamp(0, 100),
        coveragePercent: (cov * 0.90).clamp(0.0, 1.0),
        accuracyPercent: (mock * 0.92).clamp(0.0, 1.0),
        projectedScore: pChm,
        maxScore: 100,
        statusColor: const Color(0xFF10B981),
      ),
    ];
  }
}
