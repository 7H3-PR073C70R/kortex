import 'dart:math' as math;

import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';

/// Semantic classification of CBT Readiness score bands
enum CbtReadinessStatusTier {
  diagnosticPending,
  onTrack,
  acceleratePrep,
  needsTriage;

  /// Default 32-bit ARGB color value for presentation layer mapping
  int get defaultColorValue {
    switch (this) {
      case CbtReadinessStatusTier.diagnosticPending:
        return 0xFF6366F1; // Indigo
      case CbtReadinessStatusTier.onTrack:
        return 0xFF10B981; // Emerald
      case CbtReadinessStatusTier.acceleratePrep:
        return 0xFFF59E0B; // Amber
      case CbtReadinessStatusTier.needsTriage:
        return 0xFFEF4444; // Red
    }
  }
}

/// Represents per-subject mastery diagnostic breakdown for CBT Readiness
class SubjectReadinessBreakdown {
  const SubjectReadinessBreakdown({
    required this.subjectName,
    required this.readinessPercent,
    required this.coveragePercent,
    required this.accuracyPercent,
    required this.projectedScore,
    required this.maxScore,
    this.projectedGrade = '',
    this.statusColorValue,
    this.isCalibrated = true,
    this.diagnosticCta = '',
    this.courseCode = '',
    this.hasPastQuestions = false,
    this.questionsAnswered = 0,
  });

  final String subjectName;
  final int readinessPercent;
  final double coveragePercent;
  final double accuracyPercent;
  final int projectedScore;
  final int maxScore;
  final String projectedGrade;

  /// 32-bit ARGB color value representing diagnostic status
  final int? statusColorValue;

  final bool isCalibrated;
  final String diagnosticCta;
  final String courseCode;
  final bool hasPastQuestions;

  /// Number of diagnostic or practice questions completed for this subject
  final int questionsAnswered;
}

/// Pure domain representation of CBT Exam Readiness result.
/// Contains zero UI framework dependencies (no Flutter/dart:ui types).
class CbtReadinessResult {
  const CbtReadinessResult({
    required this.scorePercent,
    required this.statusLabel,
    required this.statusTier,
    required this.statusColorValue,
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
    this.calibratedCourseCount = 0,
    this.totalCourseCount = 0,
    this.isCalibrated = true,
    this.totalQuestionsAnswered = 0,
    this.confidenceMargin = 0,
    this.isSampleSufficient = false,
    this.confidenceIntervalLabel = '',
  });

  /// True if the student has sufficient diagnostic/activity data to compute a readiness score
  final bool isCalibrated;

  /// Convenience alias matching clean code standards
  bool get hasSufficientData => isCalibrated;

  /// Total questions answered across quizzes and CBT practice exams
  final int totalQuestionsAnswered;

  /// Psychometric margin of error percentage points (e.g. 6 for ±6%)
  final int confidenceMargin;

  /// Whether the question sample size is psychometrically sufficient (n >= 30)
  final bool isSampleSufficient;

  /// Transparent sample size and confidence interval label for UI display
  /// e.g. "Readiness: 68% ± 6% (Based on 140 questions across 4 subjects)"
  /// or "Low sample size — complete a full mock to improve projection accuracy"
  final String confidenceIntervalLabel;

  /// Number of enrolled courses that have active study/quiz data
  final int calibratedCourseCount;

  /// Total number of enrolled courses evaluated
  final int totalCourseCount;

  /// True if all enrolled courses have diagnostic calibration
  bool get isFullyCalibrated =>
      totalCourseCount > 0 && calibratedCourseCount == totalCourseCount;

  /// Overall readiness index (0 to 100)
  final int scorePercent;

  /// Human readable diagnostic tag (e.g. "ON TRACK", "ACCELERATE PREP", "NEEDS TRIAGE")
  final String statusLabel;

  /// Semantic readiness status tier
  final CbtReadinessStatusTier statusTier;

  /// 32-bit ARGB color value representing readiness status (e.g. 0xFF10B981)
  final int statusColorValue;

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

  /// Helper to convert a dynamic course item (CuratedCourseEntity, Map, or Object)
  factory RegisteredCourseInput.fromDynamic(dynamic c) {
    if (c is RegisteredCourseInput) return c;
    if (c is CuratedCourseEntity) {
      return RegisteredCourseInput(
        courseCode: c.courseCode,
        title: c.title.isNotEmpty ? c.title : c.courseCode,
        syllabusCoverage: c.syllabusCoverage,
        department: c.department,
        accuracyPercent: c.accuracyPercent,
        retentionRate: c.retentionRate,
        iconName: c.iconName,
        colorHex: c.colorHex,
      );
    }
    final code = _extractString(c, 'courseCode') ??
        _extractString(c, 'course_code') ??
        '';
    final title = _extractString(c, 'title') ?? code;
    final cov = _extractDouble(c, 'syllabusCoverage') ??
        _extractDouble(c, 'syllabus_coverage') ??
        0.0;
    final dept = _extractString(c, 'department') ?? 'General';
    final acc = _extractDouble(c, 'accuracyPercent');
    final ret = _extractDouble(c, 'retentionRate');
    final icon = _extractString(c, 'iconName') ?? 'school';
    final color = _extractString(c, 'colorHex') ?? '#6366F1';

    return RegisteredCourseInput(
      courseCode: code,
      title: title.isNotEmpty ? title : code,
      syllabusCoverage: cov,
      department: dept,
      accuracyPercent: acc,
      retentionRate: ret,
      iconName: icon,
      colorHex: color,
    );
  }

  final String courseCode;
  final String title;
  final double syllabusCoverage;
  final String department;
  final double? accuracyPercent;
  final double? retentionRate;
  final String iconName;
  final String colorHex;

  /// Helper to convert dynamic course lists (CuratedCourseEntity, Maps, Objects)
  static List<RegisteredCourseInput> convertCourses(List<dynamic>? courses) {
    if (courses == null || courses.isEmpty) return const [];
    return courses
        .where((c) => c != null)
        .map(RegisteredCourseInput.fromDynamic)
        .toList();
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
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
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
      if (key == 'syllabusCoverage') {
        return ((obj as dynamic).syllabusCoverage as num?)?.toDouble();
      }
      if (key == 'syllabus_coverage') {
        return ((obj as dynamic).syllabus_coverage as num?)?.toDouble();
      }
      if (key == 'accuracyPercent') {
        return ((obj as dynamic).accuracyPercent as num?)?.toDouble();
      }
      if (key == 'retentionRate') {
        return ((obj as dynamic).retentionRate as num?)?.toDouble();
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
    return null;
  }
}

enum CbtTrackArchetype {
  secondary,
  tertiary,
  professional,
  matriculation,
}

/// Pure domain CBT Readiness assessment engine.
/// Decoupled from all UI and Flutter framework packages.
class CbtReadinessService {
  const CbtReadinessService();

  static final RegExp _matriculationRegex = RegExp(
    r'\b(jamb|utme|post-?utme|putme|matric|matriculation|unified\s+tertiary\s+matriculation|joint\s+admissions?)\b',
    caseSensitive: false,
  );

  static final RegExp _secondaryRegex = RegExp(
    r'\b(waec|neco|wassce|ssce|gce|nabteb|bece|junior\s+waec|senior\s+waec|'
    r'(first|second|third|1st|2nd|3rd)\s+term|mid-?term|'
    r'jss\s*[1-3]?|sss\s*[1-3]?|js[1-3]|ss[1-3]|'
    r'senior\s+secondary|junior\s+secondary|secondary\s+school|high\s+school|'
    r'common\s+entrance|basic\s+education\s+certificate|'
    r'national\s+technical\s+certificate|national\s+business\s+certificate|ntc|nbc)\b',
    caseSensitive: false,
  );

  static final RegExp _professionalRegex = RegExp(
    r'\b(prof|professional|ican|acca|cfa|pmp|cissp|cisa|nclex|usmle|plab|comlex|'
    r'bar\s+exam(ination)?|bar\s+finals?|nigerian\s+bar|legal\s+bar|call\s+to\s+the\s+bar|'
    r'licensure|licen[sc]e|board\s+certification|chartered|practicing\s+licen[sc]e|vocational|tvet|'
    r'cert|certification|certificate)\b',
    caseSensitive: false,
  );

  static final RegExp _tertiaryRegex = RegExp(
    r'\b(bsc|b\.sc|msc|m\.sc|phd|ph\.d|ba|b\.a|ma|m\.a|llb|ll\.b|llm|ll\.m|beng|b\.eng|meng|m\.eng|'
    r'ond|o\.n\.d|hnd|h\.n\.d|pgd|p\.g\.d|'
    'bachelors?|masters?|doctorate|undergraduate|postgraduate|'
    r'university|universities|polytechnic|college\s+of\s+education|'
    r'ordinary\s+national\s+diploma|higher\s+national\s+diploma|'
    r'uni|gpa|cgpa|degree|semester)\b',
    caseSensitive: false,
  );

  static bool _isEnglishSubject(String name, String code) {
    final lowerName = name.toLowerCase().trim();
    final lowerCode = code.toLowerCase().trim();
    if (lowerName.contains('literature') || lowerCode.contains('lit')) {
      return false; // Literature in English is an elective subject, not core English Language
    }
    return lowerName.contains('english') ||
        lowerCode.contains('eng') ||
        lowerName.contains('use of english');
  }

  static bool _isMathSubject(String name, String code) {
    final lowerName = name.toLowerCase().trim();
    final lowerCode = code.toLowerCase().trim();
    if (lowerName.contains('further math') ||
        lowerCode.contains('fmth') ||
        lowerCode.contains('fmath')) {
      return false; // Further Mathematics is an elective subject, not core General Mathematics
    }
    return lowerName.contains('math') ||
        lowerCode.contains('mth') ||
        lowerCode.contains('mat');
  }

  /// Psychometrically accurate archetype resolver.
  /// Uses explicit word boundaries and precedence rules:
  /// 1. Matriculation (JAMB/UTME/Post-UTME) takes top precedence.
  /// 2. Secondary (WAEC/WASSCE/NECO/NABTEB/Term exams).
  /// 3. Professional (ICAN/ACCA/Bar exams/Licensure).
  /// 4. Tertiary (University/BSc/MSc/HND/OND).
  /// 5. Defaults cleanly to matriculation.
  static CbtTrackArchetype resolveArchetype(String examType) {
    final clean = examType.trim();
    if (clean.isEmpty) return CbtTrackArchetype.matriculation;
    final lower = clean.toLowerCase();

    if (_matriculationRegex.hasMatch(lower)) {
      return CbtTrackArchetype.matriculation;
    }

    if (_secondaryRegex.hasMatch(lower)) {
      return CbtTrackArchetype.secondary;
    }

    if (_professionalRegex.hasMatch(lower)) {
      return CbtTrackArchetype.professional;
    }

    if (_tertiaryRegex.hasMatch(lower)) {
      return CbtTrackArchetype.tertiary;
    }

    return CbtTrackArchetype.matriculation;
  }

  static String getTertiaryDegreeClass(double gpa) {
    if (gpa >= 4.50) return 'First Class Honors';
    if (gpa >= 3.50) return 'Second Class Upper';
    if (gpa >= 2.40) return 'Second Class Lower';
    if (gpa >= 1.50) return 'Third Class';
    return 'Pass / Academic Warning';
  }

  static String getProfessionalGrade(int percent) {
    if (percent >= 85) return 'Distinction';
    if (percent >= 70) return 'Merit';
    if (percent >= 50) return 'Pass';
    return 'Unsatisfactory';
  }

  static String getWaecGrade(int percent) {
    if (percent >= 75) return 'A1';
    if (percent >= 70) return 'B2';
    if (percent >= 65) return 'B3';
    if (percent >= 60) return 'C4';
    if (percent >= 55) return 'C5';
    if (percent >= 50) return 'C6';
    if (percent >= 45) return 'D7';
    if (percent >= 40) return 'E8';
    return 'F9';
  }

  static String getWaecGradeLabel(String grade) {
    switch (grade) {
      case 'A1':
        return 'A1 - Excellent';
      case 'B2':
        return 'B2 - Very Good';
      case 'B3':
        return 'B3 - Good';
      case 'C4':
        return 'C4 - Credit';
      case 'C5':
        return 'C5 - Credit';
      case 'C6':
        return 'C6 - Credit';
      case 'D7':
        return 'D7 - Pass';
      case 'E8':
        return 'E8 - Pass';
      case 'F9':
      default:
        return 'F9 - Fail';
    }
  }

  static bool isWaecCredit(String grade) {
    return grade == 'A1' ||
        grade == 'B2' ||
        grade == 'B3' ||
        grade == 'C4' ||
        grade == 'C5' ||
        grade == 'C6';
  }

  static ({double accuracy, double retention})? _resolveCoursePerformance({
    required RegisteredCourseInput course,
    Map<String, double>? subjectAccuracies,
    Map<String, double>? subjectRetentions,
  }) {
    if (course.accuracyPercent != null && course.retentionRate != null) {
      return (
        accuracy: course.accuracyPercent!,
        retention: course.retentionRate!,
      );
    }

    final codeKey = course.courseCode.trim().toLowerCase();
    final titleKey = course.title.trim().toLowerCase();

    // 1. Check explicit subject performance maps passed via pure parameters
    if (subjectAccuracies != null) {
      for (final entry in subjectAccuracies.entries) {
        final key = entry.key.trim().toLowerCase();
        if (key.isNotEmpty &&
            (key == codeKey ||
                key == titleKey ||
                titleKey.contains(key) ||
                key.contains(titleKey) ||
                (codeKey.isNotEmpty &&
                    (codeKey.contains(key) || key.contains(codeKey))))) {
          final acc = entry.value;
          final ret = subjectRetentions?[entry.key] ?? acc;
          return (accuracy: acc, retention: ret);
        }
      }
    }

    // 2. Fallback to course explicit single property if present
    if (course.accuracyPercent != null || course.retentionRate != null) {
      final acc = course.accuracyPercent ?? course.retentionRate ?? 0.0;
      final ret = course.retentionRate ?? course.accuracyPercent ?? 0.0;
      return (
        accuracy: acc,
        retention: ret,
      );
    }

    // 3. No activity data for this specific course (uncalibrated)
    return null;
  }

  static String _getJambBandString(int points) {
    if (points >= 320) return '320 - 400 Band';
    if (points >= 280) return '280 - 319 Band';
    if (points >= 250) return '250 - 279 Band';
    if (points >= 220) return '220 - 249 Band';
    if (points >= 190) return '190 - 219 Band';
    if (points >= 180) return '180 - 189 Band';
    return '< 180 Band';
  }

  /// Resolves the continuous psychometric score band string for JAMB on a 0-400 point scale.
  static String getJambBand(int points) => _getJambBandString(points);

  /// Computes a weighted 0-100% CBT readiness score and projects expected exam performance.
  /// Pure function: all dependencies and metrics are supplied via immutable arguments.
  CbtReadinessResult compute({
    required double syllabusCoverage,
    required double fsrsRetentionRate,
    required double mockScoreRatio,
    required int daysRemaining,
    String examType = 'JAMB',
    CbtTrackArchetype? explicitArchetype,
    String? explicitWeakestTopic,
    double averageSecondsPerQuestion = 48.0,
    int targetScoreGoal = 300,
    List<SubjectReadinessBreakdown>? subjectBreakdowns,
    List<dynamic>? registeredCourses,
    Map<String, double>? subjectAccuracies,
    Map<String, double>? subjectRetentions,
    Map<String, int>? subjectQuestionCounts,
    int totalQuestionsAnswered = 0,
  }) {
    var effectiveTotalQuestions = totalQuestionsAnswered;
    if (effectiveTotalQuestions <= 0 &&
        subjectQuestionCounts != null &&
        subjectQuestionCounts.isNotEmpty) {
      effectiveTotalQuestions =
          subjectQuestionCounts.values.fold(0, (a, b) => a + b);
    }

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

    final archetype = explicitArchetype ?? resolveArchetype(examType);
    final isWaecOrNeco = archetype == CbtTrackArchetype.secondary;
    final isUniversity = archetype == CbtTrackArchetype.tertiary;
    final isProfessional = archetype == CbtTrackArchetype.professional;

    final targetExamDisplay = switch (explicitArchetype) {
      null => examType,
      _ when examType != 'JAMB' => examType,
      CbtTrackArchetype.secondary => 'WAEC / WASSCE',
      CbtTrackArchetype.tertiary => 'University Degree (GPA)',
      CbtTrackArchetype.professional => 'Professional Certification',
      CbtTrackArchetype.matriculation => 'JAMB',
    };

    // Build subject breakdowns based on registered courses if available
    final List<SubjectReadinessBreakdown> effectiveSubjectBreakdowns;
    RegisteredCourseInput? weakestCourseInput;
    SubjectReadinessBreakdown? weakestBreakdown;
    var lowestCourseReadinessVal = 101;
    var totalProjectedPoints = 0;
    var totalMaxPoints = 0;
    var calibratedCoursesCount = 0;

    if (convertedRegisteredCourses.isNotEmpty) {
      final hasAnyExplicitCoursePerf = convertedRegisteredCourses.any(
        (c) =>
            _resolveCoursePerformance(
              course: c,
              subjectAccuracies: subjectAccuracies,
              subjectRetentions: subjectRetentions,
            ) !=
            null ||
            c.accuracyPercent != null ||
            c.retentionRate != null,
      );

      final breakdowns = <SubjectReadinessBreakdown>[];
      for (final course in convertedRegisteredCourses) {
        final courseName = course.title.trim().isNotEmpty
            ? course.title.trim()
            : (course.courseCode.trim().isNotEmpty
                ? course.courseCode.trim()
                : 'Registered Course');

        final resolvedPerf = _resolveCoursePerformance(
          course: course,
          subjectAccuracies: subjectAccuracies,
          subjectRetentions: subjectRetentions,
        );

        final courseCodeKey = course.courseCode.trim().toLowerCase();
        final courseTitleKey = course.title.trim().toLowerCase();
        final courseQuestions = subjectQuestionCounts?[courseCodeKey] ??
            subjectQuestionCounts?[courseTitleKey] ??
            0;

        final courseCov = course.syllabusCoverage.clamp(0.0, 1.0);
        final double courseAcc;
        final double courseRet;
        final bool isCourseCalibrated;
        final String diagnosticCta;

        if (resolvedPerf != null) {
          isCourseCalibrated = true;
          courseAcc = resolvedPerf.accuracy.clamp(0.0, 1.0);
          courseRet = resolvedPerf.retention.clamp(0.0, 1.0);
          diagnosticCta = '';
        } else if (course.accuracyPercent != null ||
            course.retentionRate != null) {
          isCourseCalibrated = true;
          courseAcc = (course.accuracyPercent ??
                  course.retentionRate ??
                  0.0)
              .clamp(0.0, 1.0);
          courseRet = (course.retentionRate ??
                  course.accuracyPercent ??
                  0.0)
              .clamp(0.0, 1.0);
          diagnosticCta = '';
        } else if (hasAnyExplicitCoursePerf) {
          // Explicit per-course performance exists elsewhere, keep unattempted course at 0.0
          isCourseCalibrated = false;
          courseAcc = 0.0;
          courseRet = 0.0;
          diagnosticCta = 'Take 10-Item Diagnostic';
        } else {
          // No per-course overrides exist; inherit student's aggregate baseline if active
          final hasAggregate = mockScoreRatio > 0.0 || fsrsRetentionRate > 0.0;
          isCourseCalibrated = hasAggregate;
          courseAcc = mockScoreRatio.clamp(0.0, 1.0);
          courseRet = fsrsRetentionRate.clamp(0.0, 1.0);
          diagnosticCta = hasAggregate ? '' : 'Take 10-Item Diagnostic';
        }

        if (isCourseCalibrated) {
          calibratedCoursesCount++;
        }

        final double covWeight;
        final double accWeight;
        final double retWeight;

        if (daysRemaining > 45) {
          covWeight = 0.20;
          accWeight = 0.45;
          retWeight = 0.35;
        } else if (daysRemaining > 20) {
          covWeight = 0.30;
          accWeight = 0.40;
          retWeight = 0.30;
        } else {
          covWeight = 0.40;
          accWeight = 0.35;
          retWeight = 0.25;
        }


        final courseReadinessVal =
            ((courseCov * covWeight) +
                (courseAcc * accWeight) +
                (courseRet * retWeight)) *
            100;
        final courseReadinessPercent =
            courseReadinessVal.round().clamp(0, 100);

        final int subjectMaxScore;
        final int subjectProjectedScore;
        final String subjectGrade;
        final int statusColorValue;

        if (!isCourseCalibrated && courseCov == 0.0 && courseAcc == 0.0) {
          // Completely uncalibrated course with zero activity
          statusColorValue = 0xFF6B7280; // Gray
          if (isWaecOrNeco) {
            subjectMaxScore = 100;
            subjectProjectedScore = 0;
            subjectGrade = 'Uncalibrated';
          } else if (isUniversity) {
            subjectMaxScore = 100;
            subjectProjectedScore = 0;
            subjectGrade = '0.0 GP';
          } else if (isProfessional) {
            subjectMaxScore = 100;
            subjectProjectedScore = 0;
            subjectGrade = 'Uncalibrated';
          } else {
            subjectMaxScore = 100;
            subjectProjectedScore = 0;
            subjectGrade = 'Uncalibrated';
          }
        } else {
          if (isWaecOrNeco) {
            subjectMaxScore = 100;
            subjectProjectedScore = courseReadinessPercent;
            subjectGrade = getWaecGrade(courseReadinessPercent);
          } else if (isUniversity) {
            subjectMaxScore = 100;
            subjectProjectedScore = courseReadinessPercent;
            final gpaVal = (courseReadinessPercent / 100.0) * 5.0;
            subjectGrade = '${gpaVal.toStringAsFixed(1)} GP';
          } else if (isProfessional) {
            subjectMaxScore = 100;
            subjectProjectedScore = courseReadinessPercent;
            subjectGrade = getProfessionalGrade(courseReadinessPercent);
          } else {
            // JAMB: strictly 100 max points per subject
            subjectMaxScore = 100;
            subjectProjectedScore =
                ((courseReadinessPercent / 100.0) * 100)
                    .round()
                    .clamp(0, 100);
            subjectGrade = '$subjectProjectedScore pts';
          }

          if (courseReadinessPercent >= 75) {
            statusColorValue = 0xFF10B981; // Emerald
          } else if (courseReadinessPercent >= 55) {
            statusColorValue = 0xFFF59E0B; // Amber
          } else {
            statusColorValue = 0xFFEF4444; // Red
          }
        }

        totalProjectedPoints += subjectProjectedScore;
        totalMaxPoints += subjectMaxScore;

        final breakdown = SubjectReadinessBreakdown(
          subjectName: courseName,
          courseCode: course.courseCode,
          readinessPercent: courseReadinessPercent,
          coveragePercent: courseCov,
          accuracyPercent: courseAcc,
          projectedScore: subjectProjectedScore,
          maxScore: subjectMaxScore,
          projectedGrade: subjectGrade,
          statusColorValue: statusColorValue,
          isCalibrated: isCourseCalibrated,
          diagnosticCta: diagnosticCta,
          questionsAnswered: courseQuestions,
        );
        breakdowns.add(breakdown);

        if (courseReadinessPercent < lowestCourseReadinessVal) {
          lowestCourseReadinessVal = courseReadinessPercent;
          weakestCourseInput = course;
          weakestBreakdown = breakdown;
        }
      }
      effectiveSubjectBreakdowns = breakdowns;
    } else if (subjectBreakdowns != null && subjectBreakdowns.isNotEmpty) {
      effectiveSubjectBreakdowns = subjectBreakdowns;
      calibratedCoursesCount =
          subjectBreakdowns.where((b) => b.isCalibrated).length;
      for (final b in subjectBreakdowns) {
        totalProjectedPoints += b.projectedScore;
        totalMaxPoints += b.maxScore;
        if (b.readinessPercent < lowestCourseReadinessVal) {
          lowestCourseReadinessVal = b.readinessPercent;
          weakestBreakdown = b;
        }
      }
    } else {
      effectiveSubjectBreakdowns = const [];
      calibratedCoursesCount = 0;
    }

    final hasAnyActivity =
        calibratedCoursesCount > 0 || mock > 0.0 || ret > 0.0 || cov > 0.0;
    final isAllUncalibrated = !hasAnyActivity;

    final int finalPercent;
    final int projectedPoints;

    if (isAllUncalibrated) {
      finalPercent = 0;
      projectedPoints = 0;
    } else if (effectiveSubjectBreakdowns.isNotEmpty && totalMaxPoints > 0) {
      finalPercent =
          ((totalProjectedPoints / totalMaxPoints) * 100).round().clamp(0, 100);
      if (isWaecOrNeco) {
        projectedPoints = totalProjectedPoints;
      } else if (isUniversity) {
        projectedPoints = ((finalPercent / 100.0) * 5.0 * 100).round();
      } else if (isProfessional) {
        projectedPoints = finalPercent;
      } else {
        // JAMB: Standard 4-subject exam capped strictly at 400.
        // Scale exact points ratio directly to 400-point ceiling without double-rounding precision loss.
        projectedPoints =
            ((totalProjectedPoints / totalMaxPoints) * 400).round().clamp(0, 400);
      }
    } else {
      final double rawWeighted;

      if (isWaecOrNeco) {
        rawWeighted = (cov * 0.35) +
            (ret * 0.25) +
            (mock * 0.25) +
            (timeFactor * 0.08) +
            (speedFactor * 0.07);
      } else if (isUniversity) {
        rawWeighted = (cov * 0.40) +
            (ret * 0.25) +
            (mock * 0.20) +
            (timeFactor * 0.08) +
            (speedFactor * 0.07);
      } else if (isProfessional) {
        rawWeighted = (cov * 0.30) +
            (ret * 0.20) +
            (mock * 0.35) +
            (timeFactor * 0.08) +
            (speedFactor * 0.07);
      } else {
        // JAMB
        rawWeighted = (cov * 0.30) +
            (ret * 0.25) +
            (mock * 0.30) +
            (timeFactor * 0.08) +
            (speedFactor * 0.07);
      }

      finalPercent = (rawWeighted * 100).round().clamp(0, 100);
      projectedPoints = isWaecOrNeco
          ? (finalPercent * 0.09).round().clamp(1, 9)
          : (isUniversity
              ? ((finalPercent / 100.0) * 5.0 * 100).round()
              : (isProfessional
                  ? finalPercent
                  : ((finalPercent / 100.0) * 400).round().clamp(0, 400)));
    }

    final String label;
    final CbtReadinessStatusTier tier;
    final int colorVal;
    String grade;
    String scoreRange;
    final missingCoreList = <String>[];

    if (isAllUncalibrated) {
      label = 'DIAGNOSTIC PENDING';
      tier = CbtReadinessStatusTier.diagnosticPending;
      colorVal = tier.defaultColorValue;
      grade = 'Pending';
      if (isWaecOrNeco) {
        final courseTotal = convertedRegisteredCourses.isNotEmpty
            ? convertedRegisteredCourses.length
            : 0;
        scoreRange = courseTotal > 0
            ? '0 / $courseTotal Credits (Diagnostics Pending)'
            : 'Pending Diagnostic (Not Enough Data)';
      } else if (isUniversity) {
        scoreRange = '0.00 / 5.00 GPA (Diagnostics Pending)';
      } else if (isProfessional) {
        scoreRange = '0% Projected (Diagnostics Pending)';
      } else {
        scoreRange = convertedRegisteredCourses.isNotEmpty
            ? '0 / 400 (Diagnostics Pending)'
            : 'Pending Diagnostic (Not Enough Data)';
      }
    } else if (isWaecOrNeco) {
      final creditsCount = effectiveSubjectBreakdowns
          .where(
            (b) => isWaecCredit(
              b.projectedGrade.isNotEmpty
                  ? b.projectedGrade
                  : getWaecGrade(b.readinessPercent),
            ),
          )
          .length;
      final totalCount = effectiveSubjectBreakdowns.isNotEmpty
          ? effectiveSubjectBreakdowns.length
          : 1;

      final averageGrade = getWaecGrade(finalPercent);
      grade = averageGrade;

      final hasBreakdowns = effectiveSubjectBreakdowns.isNotEmpty;
      final hasEnglish = effectiveSubjectBreakdowns.any(
        (b) => _isEnglishSubject(b.subjectName, b.courseCode),
      );
      final hasEnglishCredit = effectiveSubjectBreakdowns.any(
        (b) =>
            _isEnglishSubject(b.subjectName, b.courseCode) &&
            isWaecCredit(
              b.projectedGrade.isNotEmpty
                  ? b.projectedGrade
                  : getWaecGrade(b.readinessPercent),
            ),
      );

      final hasMath = effectiveSubjectBreakdowns.any(
        (b) => _isMathSubject(b.subjectName, b.courseCode),
      );
      final hasMathCredit = effectiveSubjectBreakdowns.any(
        (b) =>
            _isMathSubject(b.subjectName, b.courseCode) &&
            isWaecCredit(
              b.projectedGrade.isNotEmpty
                  ? b.projectedGrade
                  : getWaecGrade(b.readinessPercent),
            ),
      );

      // Core WAEC Requirement: At least 5 credits that MUST include English Language and General Mathematics.
      final bool meetsCoreWaecRequirements;
      if (hasBreakdowns) {
        if (totalCount >= 5) {
          meetsCoreWaecRequirements =
              creditsCount >= 5 && hasEnglishCredit && hasMathCredit;
        } else {
          final englishOk = !hasEnglish || hasEnglishCredit;
          final mathOk = !hasMath || hasMathCredit;
          meetsCoreWaecRequirements =
              englishOk && mathOk && (finalPercent >= 70 || creditsCount == totalCount);
        }
      } else {
        meetsCoreWaecRequirements = finalPercent >= 70;
      }

      final passThreshold = daysRemaining > 30 ? 35 : 40;
      if (meetsCoreWaecRequirements) {
        label = 'ON TRACK';
        tier = CbtReadinessStatusTier.onTrack;
      } else if (finalPercent >= passThreshold || creditsCount >= 3) {
        label = 'ACCELERATE PREP';
        tier = CbtReadinessStatusTier.acceleratePrep;
      } else {
        label = 'NEEDS TRIAGE';
        tier = CbtReadinessStatusTier.needsTriage;
      }
      colorVal = tier.defaultColorValue;

      final gradeLabel = getWaecGradeLabel(averageGrade);
      final isPartial = calibratedCoursesCount > 0 &&
          calibratedCoursesCount < convertedRegisteredCourses.length;
      final calSuffix = isPartial
          ? ' - $calibratedCoursesCount of ${convertedRegisteredCourses.length} Calibrated'
          : '';

      if (hasBreakdowns && totalCount >= 5) {
        if (!hasEnglishCredit) missingCoreList.add('English');
        if (!hasMathCredit) missingCoreList.add('Math');
      } else if (hasBreakdowns) {
        if (hasEnglish && !hasEnglishCredit) missingCoreList.add('English');
        if (hasMath && !hasMathCredit) missingCoreList.add('Math');
      }

      final coreWarning = missingCoreList.isNotEmpty
          ? ' - Missing ${missingCoreList.join(' & ')} Credit'
          : '';

      if (meetsCoreWaecRequirements &&
          (creditsCount >= 5 || (totalCount < 5 && creditsCount == totalCount))) {
        scoreRange =
            '$creditsCount / $totalCount Credits ($gradeLabel$calSuffix)';
      } else if (missingCoreList.isNotEmpty) {
        scoreRange =
            '$creditsCount / $totalCount Credits ($gradeLabel$coreWarning / Requires Remediation$calSuffix)';
      } else {
        scoreRange =
            '$creditsCount / $totalCount Credits ($gradeLabel / Requires Remediation$calSuffix)';
      }
    } else if (isUniversity) {
      final gpaVal = (finalPercent / 100.0) * 5.0;
      final degreeClass = getTertiaryDegreeClass(gpaVal);
      final passThreshold = daysRemaining > 30 ? 40 : 45;
      if (finalPercent >= 70) {
        label = 'ON TRACK';
        tier = CbtReadinessStatusTier.onTrack;
      } else if (finalPercent >= passThreshold) {
        label = 'ACCELERATE PREP';
        tier = CbtReadinessStatusTier.acceleratePrep;
      } else {
        label = 'NEEDS TRIAGE';
        tier = CbtReadinessStatusTier.needsTriage;
      }
      colorVal = tier.defaultColorValue;
      grade = '${gpaVal.toStringAsFixed(2)} GPA';
      final isPartial = calibratedCoursesCount > 0 &&
          calibratedCoursesCount < convertedRegisteredCourses.length;
      final calSuffix = isPartial
          ? ' - $calibratedCoursesCount of ${convertedRegisteredCourses.length} Calibrated'
          : '';
      scoreRange =
          '$degreeClass (${gpaVal.toStringAsFixed(2)} / 5.00 GPA$calSuffix)';
    } else if (isProfessional) {
      final profGrade = getProfessionalGrade(finalPercent);
      final passThreshold = daysRemaining > 30 ? 40 : 50;
      if (finalPercent >= 70) {
        label = 'ON TRACK';
        tier = CbtReadinessStatusTier.onTrack;
      } else if (finalPercent >= passThreshold) {
        label = 'ACCELERATE PREP';
        tier = CbtReadinessStatusTier.acceleratePrep;
      } else {
        label = 'NEEDS TRIAGE';
        tier = CbtReadinessStatusTier.needsTriage;
      }
      colorVal = tier.defaultColorValue;
      grade = profGrade;
      final isPartial = calibratedCoursesCount > 0 &&
          calibratedCoursesCount < convertedRegisteredCourses.length;
      final calSuffix = isPartial
          ? ' - $calibratedCoursesCount of ${convertedRegisteredCourses.length} Calibrated'
          : '';
      scoreRange = '$finalPercent% Projected ($profGrade$calSuffix)';
    } else {
      // Default JAMB 400-point scale
      const maxTarget = 400;
      final bandStr = _getJambBandString(projectedPoints);
      final isPartial = calibratedCoursesCount > 0 &&
          calibratedCoursesCount < convertedRegisteredCourses.length;
      final calSuffix = isPartial
          ? ' - $calibratedCoursesCount of ${convertedRegisteredCourses.length} Calibrated'
          : '';

      if (finalPercent >= 70 || projectedPoints >= 280) {
        label = 'ON TRACK';
        tier = CbtReadinessStatusTier.onTrack;
        grade = projectedPoints >= 320 ? '320+' : '280+';
        scoreRange = '$projectedPoints / $maxTarget ($bandStr$calSuffix)';
      } else if (finalPercent >= 50 || projectedPoints >= 200) {
        label = 'ACCELERATE PREP';
        tier = CbtReadinessStatusTier.acceleratePrep;
        grade = projectedPoints >= 250 ? '250+' : '220+';
        scoreRange = '$projectedPoints / $maxTarget ($bandStr$calSuffix)';
      } else {
        label = 'NEEDS TRIAGE';
        tier = CbtReadinessStatusTier.needsTriage;
        grade = projectedPoints >= 180 ? '180+' : '< 180';
        scoreRange = '$projectedPoints / $maxTarget ($bandStr$calSuffix)';
      }
      colorVal = tier.defaultColorValue;
    }

    // Determine primary bottleneck diagnostic
    var weakestArea = explicitWeakestTopic ?? '';
    if (weakestArea.isEmpty) {
      if (isAllUncalibrated) {
        weakestArea = 'Diagnostic Assessment Required';
      } else if (weakestBreakdown != null && !weakestBreakdown.isCalibrated) {
        weakestArea =
            '${weakestBreakdown.subjectName} (Diagnostic Calibration Pending)';
      } else if (weakestCourseInput != null) {
        final courseName = weakestCourseInput.title.trim().isNotEmpty
            ? weakestCourseInput.title.trim()
            : weakestCourseInput.courseCode;
        weakestArea = '$courseName ($lowestCourseReadinessVal% readiness)';
      } else if (speedFactor < 0.8) {
        weakestArea = 'Time Pressure & Solving Speed';
      } else if (ret < cov && ret < mock) {
        weakestArea = 'Memory Retention';
      } else if (cov < ret && cov < mock) {
        weakestArea = 'Syllabus Module Coverage';
      } else {
        weakestArea = 'Mock Test Speed & Accuracy';
      }
    }

    // Actionable Socratic remediation suggestion
    final String remediation;
    if (isAllUncalibrated) {
      remediation = isWaecOrNeco
          ? 'Complete a 10-item diagnostic quiz per subject to unlock your projected grades.'
          : 'Complete a 10-item diagnostic quiz per course to calibrate your CBT readiness index.';
    } else if (isWaecOrNeco && missingCoreList.isNotEmpty) {
      remediation =
          'WAEC Core Requirement: Focus on ${missingCoreList.join(' and ')} to secure mandatory credit passes for university admission.';
    } else if (finalPercent >= 85) {
      remediation =
          'Maintain momentum with a 10-minute timed mock sprint to lock in distinction status.';
    } else if (weakestBreakdown != null && !weakestBreakdown.isCalibrated) {
      remediation =
          'Calibrate ${weakestBreakdown.subjectName}: Complete a 10-item diagnostic quiz to unlock accurate readiness tracking.';
    } else if (weakestCourseInput != null) {
      final courseName = weakestCourseInput.title.trim().isNotEmpty
          ? weakestCourseInput.title.trim()
          : weakestCourseInput.courseCode;
      remediation =
          'Focus on $courseName: Complete 1 topic module & review 15 flashcards to boost course readiness.';
    } else if (speedFactor < 0.8) {
      remediation =
          'Pacing Alert: Practice 15 timed sprint questions to improve your $speedDiag pace.';
    } else if (ret < 0.70) {
      remediation =
          'Review 15 high-priority flashcards to refresh fading topics.';
    } else if (cov < 0.60) {
      remediation =
          'Complete 1 new syllabus topic module to boost overall syllabus coverage.';
    } else {
      remediation =
          'Take a 15-question CBT Practice Test to improve timed exam confidence.';
    }

    final probability = isAllUncalibrated
        ? 0.0
        : (finalPercent / 100.0).clamp(0.20, 0.98);

    final int evaluatedSubjectsCount;
    if (convertedRegisteredCourses.isNotEmpty) {
      evaluatedSubjectsCount = math.max(1, convertedRegisteredCourses.length);
    } else if (effectiveSubjectBreakdowns.isNotEmpty) {
      evaluatedSubjectsCount = math.max(1, effectiveSubjectBreakdowns.length);
    } else {
      evaluatedSubjectsCount = 1;
    }

    final isSampleSufficient =
        !isAllUncalibrated && effectiveTotalQuestions >= 30;
    final int confidenceMargin;
    final String confidenceIntervalLabel;

    if (isAllUncalibrated || effectiveTotalQuestions < 30) {
      confidenceMargin = 0;
      confidenceIntervalLabel =
          'Low sample size — complete a full mock to improve projection accuracy';
    } else {
      // Psychometric standard error of proportion at 90% confidence (Z = 1.645)
      final p = (finalPercent / 100.0).clamp(0.10, 0.90);
      final standardError =
          math.sqrt((p * (1.0 - p)) / effectiveTotalQuestions);
      confidenceMargin = (1.645 * standardError * 100).round().clamp(2, 15);
      final subjectPlural = evaluatedSubjectsCount == 1 ? 'subject' : 'subjects';
      confidenceIntervalLabel =
          'Readiness: $finalPercent% ± $confidenceMargin% (Based on $effectiveTotalQuestions questions across $evaluatedSubjectsCount $subjectPlural)';
    }

    return CbtReadinessResult(
      scorePercent: finalPercent,
      statusLabel: label,
      statusTier: tier,
      statusColorValue: colorVal,
      syllabusCoverage: cov,
      fsrsRetentionRate: ret,
      mockScoreRatio: mock,
      projectedGrade: grade,
      projectedScoreRange: scoreRange,
      remediationSuggestion: remediation,
      weakestAreaLabel: weakestArea,
      targetExamType: targetExamDisplay,
      targetScoreProbability: probability,
      speedReadinessRatio: speedFactor,
      speedDiagnosticLabel: speedDiag,
      targetScoreGoal: targetScoreGoal,
      projectedTotalScore: projectedPoints,
      subjectBreakdowns: effectiveSubjectBreakdowns,
      calibratedCourseCount: calibratedCoursesCount,
      totalCourseCount: convertedRegisteredCourses.isNotEmpty
          ? convertedRegisteredCourses.length
          : effectiveSubjectBreakdowns.length,
      isCalibrated: !isAllUncalibrated,
      totalQuestionsAnswered: effectiveTotalQuestions,
      confidenceMargin: confidenceMargin,
      isSampleSufficient: isSampleSufficient,
      confidenceIntervalLabel: confidenceIntervalLabel,
    );
  }
}

/// Backwards compatibility alias
typedef CbtReadinessCalculator = CbtReadinessService;
