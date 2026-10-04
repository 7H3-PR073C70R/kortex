import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';

void main() {
  group('CbtReadinessCalculator — Tailored to Registered Courses Test Suite', () {
    const calculator = CbtReadinessCalculator();

    test('Computes readiness using user registered courses (JAMB 4 courses)', () {
      final registeredCourses = [
        const RegisteredCourseInput(
          courseCode: 'ENG',
          title: 'Use of English',
          syllabusCoverage: 0.90,
          accuracyPercent: 0.85,
          retentionRate: 0.88,
        ),
        const RegisteredCourseInput(
          courseCode: 'MTH',
          title: 'General Mathematics',
          syllabusCoverage: 0.70,
          accuracyPercent: 0.75,
          retentionRate: 0.80,
        ),
        const RegisteredCourseInput(
          courseCode: 'PHY',
          title: 'Physics',
          syllabusCoverage: 0.50,
          accuracyPercent: 0.60,
          retentionRate: 0.65,
        ),
        const RegisteredCourseInput(
          courseCode: 'CHM',
          title: 'Chemistry',
          syllabusCoverage: 0.80,
          accuracyPercent: 0.82,
          retentionRate: 0.85,
        ),
      ];

      final result = calculator.compute(
        syllabusCoverage: 0.75,
        fsrsRetentionRate: 0.80,
        mockScoreRatio: 0.75,
        daysRemaining: 20,
        registeredCourses: registeredCourses,
      );

      // Verify all 4 registered courses are included in subject breakdowns
      expect(result.subjectBreakdowns.length, equals(4));
      expect(result.subjectBreakdowns[0].subjectName, equals('Use of English'));
      expect(
        result.subjectBreakdowns[1].subjectName,
        equals('General Mathematics'),
      );
      expect(result.subjectBreakdowns[2].subjectName, equals('Physics'));
      expect(result.subjectBreakdowns[3].subjectName, equals('Chemistry'));

      // Check max score per subject (400 total / 4 courses = 100 max score per course)
      for (final sub in result.subjectBreakdowns) {
        expect(sub.maxScore, equals(100));
        expect(sub.readinessPercent, greaterThanOrEqualTo(0));
        expect(sub.readinessPercent, lessThanOrEqualTo(100));
      }

      // Lowest course is Physics
      expect(result.weakestAreaLabel, contains('Physics'));
      expect(result.remediationSuggestion, contains('Physics'));

      // Overall syllabus coverage is average across registered courses: (0.9 + 0.7 + 0.5 + 0.8) / 4 = 0.725
      expect(result.syllabusCoverage, closeTo(0.725, 0.01));
    });

    test('Computes readiness using WASSCE / WAEC 9 registered courses', () {
      final waecCourses = List.generate(
        9,
        (i) => RegisteredCourseInput(
          courseCode: 'WAEC-SUBJ-$i',
          title: 'Subject $i',
          syllabusCoverage: 0.60 + (i * 0.04),
          accuracyPercent: 0.65 + (i * 0.03),
        ),
      );

      final result = calculator.compute(
        syllabusCoverage: 0.70,
        fsrsRetentionRate: 0.75,
        mockScoreRatio: 0.70,
        daysRemaining: 15,
        examType: 'WASSCE',
        registeredCourses: waecCourses,
      );

      expect(result.subjectBreakdowns.length, equals(9));
      expect(result.targetExamType, equals('WASSCE'));
      // WASSCE projected grade format
      expect(result.projectedGrade, matches(RegExp(r'^(A1|B2|B3|C4|C6|F9)$')));
    });

    test(
      'Computes readiness for University degree registered courses (GPA scale)',
      () {
        final uniCourses = [
          const RegisteredCourseInput(
            courseCode: 'GST 101',
            title: 'Use of English & Communication',
            syllabusCoverage: 0.95,
            accuracyPercent: 0.92,
          ),
          const RegisteredCourseInput(
            courseCode: 'MTH 101',
            title: 'Elementary Mathematics I',
            syllabusCoverage: 0.85,
            accuracyPercent: 0.88,
          ),
          const RegisteredCourseInput(
            courseCode: 'COS 101',
            title: 'Introduction to Computer Science',
            syllabusCoverage: 0.90,
            accuracyPercent: 0.94,
          ),
        ];

        final result = calculator.compute(
          syllabusCoverage: 0.90,
          fsrsRetentionRate: 0.91,
          mockScoreRatio: 0.91,
          daysRemaining: 10,
          examType: 'University GPA Degree',
          registeredCourses: uniCourses,
        );

        expect(result.subjectBreakdowns.length, equals(3));
        expect(result.projectedGrade, contains('GPA'));
        expect(result.statusLabel, equals('ON TRACK'));
      },
    );

    test(
      'Handles empty registered courses gracefully by falling back to default scale',
      () {
        final result = calculator.compute(
          syllabusCoverage: 0.80,
          fsrsRetentionRate: 0.85,
          mockScoreRatio: 0.82,
          daysRemaining: 30,
          registeredCourses: const [],
        );

        expect(result.subjectBreakdowns, isNotEmpty);
        expect(result.scorePercent, greaterThan(0));
      },
    );

    test(
      'Accurately flags lagging registered course as primary diagnostic bottleneck',
      () {
        final courses = [
          const RegisteredCourseInput(
            courseCode: 'BIO',
            title: 'Biology',
            syllabusCoverage: 0.95,
            accuracyPercent: 0.90,
          ),
          const RegisteredCourseInput(
            courseCode: 'CHM',
            title: 'Chemistry',
            syllabusCoverage: 0.30, // Lagging course
            accuracyPercent: 0.35,
          ),
        ];

        final result = calculator.compute(
          syllabusCoverage: 0.60,
          fsrsRetentionRate: 0.70,
          mockScoreRatio: 0.65,
          daysRemaining: 14,
          registeredCourses: courses,
        );

        expect(result.weakestAreaLabel, contains('Chemistry'));
        expect(result.remediationSuggestion, contains('Chemistry'));
      },
    );

    test(
      'Safely converts CuratedCourseEntity and CuratedCourseModel without runtime error',
      () {
        const entity = CuratedCourseEntity(
          id: '1',
          courseCode: 'BIO 101',
          title: 'General Biology',
          department: 'Biological Sciences',
          totalMaterials: 10,
          hasActivePastPapers: true,
          iconName: 'eco',
          colorHex: '#10B981',
          syllabusCoverage: 0.85,
        );

        final result = calculator.compute(
          syllabusCoverage: 0.85,
          fsrsRetentionRate: 0.85,
          mockScoreRatio: 0.85,
          daysRemaining: 14,
          registeredCourses: [entity],
        );

        expect(result.subjectBreakdowns.length, equals(1));
        expect(
          result.subjectBreakdowns.first.subjectName,
          equals('General Biology'),
        );
        expect(result.subjectBreakdowns.first.coveragePercent, equals(0.85));
      },
    );

    test(
      'Evaluates courses individually and does not bleed score from one course to unattempted courses',
      () {
        final courses = [
          const RegisteredCourseInput(
            courseCode: 'MTH',
            title: 'Mathematics',
            syllabusCoverage: 0,
            accuracyPercent: 0.32,
            retentionRate: 0.32,
          ),
          const RegisteredCourseInput(
            courseCode: 'ENG',
            title: 'English Language',
            syllabusCoverage: 0,
          ),
          const RegisteredCourseInput(
            courseCode: 'YOR',
            title: 'Yoruba',
            syllabusCoverage: 0,
          ),
          const RegisteredCourseInput(
            courseCode: 'ARB',
            title: 'Arabic',
            syllabusCoverage: 0,
          ),
        ];

        final result = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0.32,
          mockScoreRatio: 0.32,
          daysRemaining: 14,
          registeredCourses: courses,
        );

        expect(result.subjectBreakdowns.length, equals(4));

        final math = result.subjectBreakdowns.firstWhere(
          (s) => s.subjectName == 'Mathematics',
        );
        final eng = result.subjectBreakdowns.firstWhere(
          (s) => s.subjectName == 'English Language',
        );
        final yor = result.subjectBreakdowns.firstWhere(
          (s) => s.subjectName == 'Yoruba',
        );
        final arb = result.subjectBreakdowns.firstWhere(
          (s) => s.subjectName == 'Arabic',
        );

        // Math has its own recorded performance
        expect(math.accuracyPercent, equals(0.32));
        expect(math.projectedScore, equals(19));

        // Unattempted courses remain at 0% performance instead of copying Math
        expect(eng.accuracyPercent, equals(0.0));
        expect(eng.projectedScore, equals(0));

        expect(yor.accuracyPercent, equals(0.0));
        expect(yor.projectedScore, equals(0));

        expect(arb.accuracyPercent, equals(0.0));
        expect(arb.projectedScore, equals(0));

        // Total projected score is sum of individual courses (19 + 0 + 0 + 0 = 19 / 400)
        expect(result.projectedTotalScore, equals(19));
        expect(result.projectedScoreRange, contains('19 / 400'));
      },
    );

    test(
      'Computes readiness for BSC and MSC tracks using tertiary 5.0 GPA scale',
      () {
        final bscCourses = [
          const RegisteredCourseInput(
            courseCode: 'CSC 301',
            title: 'Operating Systems',
            syllabusCoverage: 0.80,
            accuracyPercent: 0.85,
            retentionRate: 0.88,
          ),
          const RegisteredCourseInput(
            courseCode: 'CSC 303',
            title: 'Database Systems',
            syllabusCoverage: 0.75,
            accuracyPercent: 0.80,
            retentionRate: 0.82,
          ),
        ];

        final bscResult = calculator.compute(
          syllabusCoverage: 0.77,
          fsrsRetentionRate: 0.85,
          mockScoreRatio: 0.82,
          daysRemaining: 60,
          examType: 'BSC',
          registeredCourses: bscCourses,
        );

        expect(bscResult.targetExamType, equals('BSC'));
        expect(bscResult.projectedGrade, contains('GPA'));
        expect(bscResult.projectedScoreRange, contains('5.00 GPA'));
        expect(bscResult.statusLabel, equals('ON TRACK'));

        final mscResult = calculator.compute(
          syllabusCoverage: 0.70,
          fsrsRetentionRate: 0.75,
          mockScoreRatio: 0.72,
          daysRemaining: 45,
          examType: 'MSC',
          registeredCourses: bscCourses,
        );

        expect(mscResult.projectedGrade, contains('GPA'));
        expect(mscResult.statusLabel, isIn(['ON TRACK', 'ACCELERATE PREP']));
      },
    );

    test(
      'Computes readiness for Professional certifications with Distinction / Merit / Pass scale',
      () {
        final profCourses = [
          const RegisteredCourseInput(
            courseCode: 'ICAN-01',
            title: 'Financial Accounting',
            syllabusCoverage: 0.85,
            accuracyPercent: 0.88,
            retentionRate: 0.86,
          ),
          const RegisteredCourseInput(
            courseCode: 'ICAN-02',
            title: 'Taxation & Fiscal Policy',
            syllabusCoverage: 0.78,
            accuracyPercent: 0.82,
            retentionRate: 0.80,
          ),
        ];

        final result = calculator.compute(
          syllabusCoverage: 0.81,
          fsrsRetentionRate: 0.83,
          mockScoreRatio: 0.85,
          daysRemaining: 30,
          examType: 'Professional',
          registeredCourses: profCourses,
        );

        expect(result.targetExamType, equals('Professional'));
        expect(result.projectedGrade, isIn(['Distinction', 'Merit', 'Pass']));
        expect(result.projectedScoreRange, contains('Projected'));
        expect(result.statusLabel, equals('ON TRACK'));
      },
    );

    test(
      'Inherits baseline FSRS retention & mock score when newly registered courses have no overrides',
      () {
        // Simulates freshly curated WAEC courses with 0% syllabus completed and 0 overrides
        final waecCourses = [
          const RegisteredCourseInput(
            courseCode: 'ENG',
            title: 'English Language',
            syllabusCoverage: 0,
          ),
          const RegisteredCourseInput(
            courseCode: 'MTH',
            title: 'General Mathematics',
            syllabusCoverage: 0,
          ),
          const RegisteredCourseInput(
            courseCode: 'BIO',
            title: 'Biology',
            syllabusCoverage: 0,
          ),
        ];

        final result = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0.53,
          mockScoreRatio: 0.48,
          daysRemaining: 68, // Real WAEC countdown, not hardcoded 14
          examType: 'WAEC',
          registeredCourses: waecCourses,
        );

        // Does NOT collapse to 0% or F9 because student has 53% retention and 48% mock accuracy!
        expect(result.scorePercent, greaterThanOrEqualTo(35));
        expect(result.scorePercent, lessThanOrEqualTo(65));
        expect(result.statusLabel, equals('ACCELERATE PREP'));
        // Projected score range reflects credits
        expect(result.projectedScoreRange, contains('Credits'));
      },
    );

    test(
      'Returns DIAGNOSTIC PENDING with 0 score when user has newly registered courses and zero activity',
      () {
        final freshCourses = [
          const RegisteredCourseInput(
            courseCode: 'ENG',
            title: 'Use of English',
            syllabusCoverage: 0,
          ),
          const RegisteredCourseInput(
            courseCode: 'MTH',
            title: 'Mathematics',
            syllabusCoverage: 0,
          ),
          const RegisteredCourseInput(
            courseCode: 'PHY',
            title: 'Physics',
            syllabusCoverage: 0,
          ),
          const RegisteredCourseInput(
            courseCode: 'CHM',
            title: 'Chemistry',
            syllabusCoverage: 0,
          ),
        ];

        final result = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0,
          mockScoreRatio: 0,
          daysRemaining: 45,
          registeredCourses: freshCourses,
        );

        expect(result.scorePercent, equals(0));
        expect(result.projectedTotalScore, equals(0));
        expect(result.statusLabel, equals('DIAGNOSTIC PENDING'));
        expect(result.projectedScoreRange, contains('Diagnostics Pending'));
        expect(result.calibratedCourseCount, equals(0));
        expect(result.totalCourseCount, equals(4));
        expect(result.isFullyCalibrated, isFalse);

        for (final sub in result.subjectBreakdowns) {
          expect(sub.isCalibrated, isFalse);
          expect(sub.diagnosticCta, equals('Take 10-Item Diagnostic'));
          expect(sub.projectedGrade, equals('Uncalibrated'));
        }
      },
    );

    test(
      'Correctly tracks calibratedCourseCount and partial calibration status',
      () {
        final courses = [
          const RegisteredCourseInput(
            courseCode: 'ENG',
            title: 'Use of English',
            syllabusCoverage: 0.80,
            accuracyPercent: 0.85,
            retentionRate: 0.82,
          ),
          const RegisteredCourseInput(
            courseCode: 'MTH',
            title: 'Mathematics',
            syllabusCoverage: 0,
          ),
        ];

        final result = calculator.compute(
          syllabusCoverage: 0.40,
          fsrsRetentionRate: 0.82,
          mockScoreRatio: 0.85,
          daysRemaining: 30,
          registeredCourses: courses,
        );

        expect(result.calibratedCourseCount, equals(1));
        expect(result.totalCourseCount, equals(2));
        expect(result.isFullyCalibrated, isFalse);
        expect(result.subjectBreakdowns[0].isCalibrated, isTrue);
        expect(result.subjectBreakdowns[1].isCalibrated, isFalse);
        expect(result.subjectBreakdowns[1].diagnosticCta, equals('Take 10-Item Diagnostic'));
        expect(result.projectedScoreRange, contains('1 of 2 Calibrated'));
      },
    );
  });
}
