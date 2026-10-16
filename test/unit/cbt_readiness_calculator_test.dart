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
      'Handles empty registered courses gracefully by not fabricating fake breakdowns',
      () {
        final result = calculator.compute(
          syllabusCoverage: 0.80,
          fsrsRetentionRate: 0.85,
          mockScoreRatio: 0.82,
          daysRemaining: 30,
          registeredCourses: const [],
        );

        expect(result.subjectBreakdowns, isEmpty);
        expect(result.scorePercent, greaterThan(0));
        expect(result.isCalibrated, isTrue);
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

    test(
      'P0-01: Zero study, no test, no registered courses returns DIAGNOSTIC PENDING with 0% score and empty breakdowns',
      () {
        // Ported directly from audit scenario: Zero study, no test, exam in 60 days
        final result = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0,
          mockScoreRatio: 0,
          daysRemaining: 60,
          registeredCourses: const [],
        );

        expect(result.isCalibrated, isFalse);
        expect(result.hasSufficientData, isFalse);
        expect(result.scorePercent, equals(0));
        expect(result.projectedTotalScore, equals(0));
        expect(result.statusLabel, equals('DIAGNOSTIC PENDING'));
        expect(result.projectedGrade, equals('Pending'));
        expect(result.projectedScoreRange, contains('Pending Diagnostic'));
        expect(result.subjectBreakdowns, isEmpty);
        expect(result.targetScoreProbability, equals(0.0));
      },
    );

    test(
      'P0-01: Unattempted exam from countdown banner yields 0% instead of fabricated 59% (236/400)',
      () {
        // Countdown banner with unattempted exam passes 0.0 retention and mock
        final result = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0,
          mockScoreRatio: 0,
          daysRemaining: 60,
          explicitWeakestTopic: 'JAMB UTME 2026',
        );

        expect(result.isCalibrated, isFalse);
        expect(result.scorePercent, equals(0));
        expect(result.projectedTotalScore, equals(0));
        expect(result.statusLabel, equals('DIAGNOSTIC PENDING'));
        expect(result.subjectBreakdowns, isEmpty);
      },
    );

    test(
      'P0-02: Taking an honest test strictly scores higher than the zero-study baseline (monotonicity invariant)',
      () {
        final zeroStudy = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0,
          mockScoreRatio: 0,
          daysRemaining: 60,
        );


        // Student covered 50% of syllabus and honestly scored 40% on mock
        final realStudy = calculator.compute(
          syllabusCoverage: 0.50,
          fsrsRetentionRate: 0.40,
          mockScoreRatio: 0.40,
          daysRemaining: 60,
        );

        expect(zeroStudy.isCalibrated, isFalse);
        expect(zeroStudy.scorePercent, equals(0));

        expect(realStudy.isCalibrated, isTrue);
        expect(realStudy.scorePercent, greaterThan(0));
        expect(realStudy.scorePercent, greaterThan(zeroStudy.scorePercent));
      },
    );
  });

  group('P3-01: Comprehensive Table-Driven Readiness Calculator Audit Scenarios', () {
    const calculator = CbtReadinessCalculator();

    group('Scenario 1: Zero study, no test, exam in 60 days (No 59% / 236 False Projection)', () {
      final uncalibratedCases = <({
        String description,
        List<RegisteredCourseInput> registeredCourses,
        String? examType,
        String? explicitWeakestTopic,
      })>[
        (
          description: 'Empty registered courses, default examType',
          registeredCourses: const <RegisteredCourseInput>[],
          examType: null,
          explicitWeakestTopic: null,
        ),
        (
          description: '4 uncalibrated JAMB registered courses (0% coverage, null accuracy/retention)',
          registeredCourses: const [
            RegisteredCourseInput(courseCode: 'ENG', title: 'Use of English', syllabusCoverage: 0),
            RegisteredCourseInput(courseCode: 'MTH', title: 'Mathematics', syllabusCoverage: 0),
            RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0),
            RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0),
          ],
          examType: 'JAMB',
          explicitWeakestTopic: null,
        ),
        (
          description: 'Uncalibrated exam with explicit weakest topic from countdown banner',
          registeredCourses: const <RegisteredCourseInput>[],
          examType: 'JAMB UTME 2026',
          explicitWeakestTopic: 'JAMB UTME 2026',
        ),
        (
          description: '9 uncalibrated WAEC courses',
          registeredCourses: List.generate(
            9,
            (i) => RegisteredCourseInput(courseCode: 'W$i', title: 'WAEC Subject $i', syllabusCoverage: 0),
          ),
          examType: 'WAEC',
          explicitWeakestTopic: null,
        ),
      ];

      for (final testCase in uncalibratedCases) {
        test('Evaluates to 0% and DIAGNOSTIC PENDING for: ${testCase.description}', () {
          final result = calculator.compute(
            syllabusCoverage: 0,
            fsrsRetentionRate: 0,
            mockScoreRatio: 0,
            daysRemaining: 60,
            examType: testCase.examType ?? 'JAMB',
            explicitWeakestTopic: testCase.explicitWeakestTopic,
            registeredCourses: testCase.registeredCourses,
          );

          expect(result.isCalibrated, isFalse, reason: 'Must not be marked calibrated with zero activity');
          expect(result.hasSufficientData, isFalse, reason: 'Must flag insufficient data');
          expect(result.scorePercent, equals(0), reason: 'Must be 0%, NOT 59%');
          expect(result.scorePercent, isNot(equals(59)), reason: 'Audited bug: 59% synthetic default was purged');
          expect(result.projectedTotalScore, equals(0), reason: 'Total projected points must be 0, NOT 236');
          expect(result.statusLabel, equals('DIAGNOSTIC PENDING'));
          expect(result.statusTier, equals(CbtReadinessStatusTier.diagnosticPending));
          expect(result.statusColorValue, equals(0xFF6366F1));
          expect(result.calibratedCourseCount, equals(0));
          expect(result.isFullyCalibrated, isFalse);
        });
      }
    });

    group('Scenario 2: Zero study, exam in 5 days (High Urgency - No 57% False Floor)', () {
      final urgentDeadlines = <int>[5, 4, 3, 2, 1, 0];

      for (final days in urgentDeadlines) {
        test('Zero study with $days days remaining strictly returns 0% (NOT 57%)', () {
          final result = calculator.compute(
            syllabusCoverage: 0,
            fsrsRetentionRate: 0,
            mockScoreRatio: 0,
            daysRemaining: days,
          );

          expect(result.isCalibrated, isFalse);
          expect(result.hasSufficientData, isFalse);
          expect(result.scorePercent, equals(0));
          expect(result.scorePercent, isNot(equals(57)), reason: 'Audited bug: 57% urgency floor was purged');
          expect(result.projectedTotalScore, equals(0));
          expect(result.statusLabel, equals('DIAGNOSTIC PENDING'));
          expect(result.statusTier, equals(CbtReadinessStatusTier.diagnosticPending));
        });
      }
    });

    group('Scenario 3: Covered 50%, scored 40% (Monotonicity Invariant Test Table)', () {
      final studyProgressionTable = <({
        double coverage,
        double mockScore,
        double retention,
        String tierName,
      })>[
        (coverage: 0.00, mockScore: 0.00, retention: 0.00, tierName: 'Zero Study Baseline'),
        (coverage: 0.15, mockScore: 0.20, retention: 0.25, tierName: 'Nascent Study (15% cov, 20% mock)'),
        (coverage: 0.35, mockScore: 0.35, retention: 0.35, tierName: 'Early Study (35% cov, 35% mock)'),
        (coverage: 0.50, mockScore: 0.40, retention: 0.45, tierName: 'Audited Scenario (50% cov, 40% mock)'),
        (coverage: 0.70, mockScore: 0.65, retention: 0.70, tierName: 'Solid Study (70% cov, 65% mock)'),
        (coverage: 0.85, mockScore: 0.80, retention: 0.85, tierName: 'Advanced Study (85% cov, 80% mock)'),
        (coverage: 0.98, mockScore: 0.95, retention: 0.96, tierName: 'Mastery Study (98% cov, 95% mock)'),
      ];

      test('Readiness score strictly increases monotonically as active study and mock accuracy advance', () {
        var previousScore = -1;

        for (final row in studyProgressionTable) {
          final result = calculator.compute(
            syllabusCoverage: row.coverage,
            mockScoreRatio: row.mockScore,
            fsrsRetentionRate: row.retention,
            daysRemaining: 40,
          );

          final currentScore = result.scorePercent;

          if (row.coverage == 0.0 && row.mockScore == 0.0) {
            expect(currentScore, equals(0), reason: '${row.tierName} must be 0%');
            expect(result.isCalibrated, isFalse);
          } else {
            expect(currentScore, greaterThan(0), reason: '${row.tierName} must score strictly > 0%');
            expect(result.isCalibrated, isTrue);
            expect(
              currentScore,
              greaterThan(previousScore),
              reason: '${row.tierName} ($currentScore%) must be strictly higher than previous ($previousScore%)',
            );
          }

          // Specific verification for audited row: 50% coverage, 40% mock
          if (row.coverage == 0.50 && row.mockScore == 0.40) {
            expect(currentScore, greaterThan(0));
            expect(result.statusTier, isNot(equals(CbtReadinessStatusTier.diagnosticPending)));
          }

          previousScore = currentScore;
        }
      });
    });

    group('Scenario 4: All 19+ Realistic Exam Titles Correctly Classified (No Substring False Positives)', () {
      final examClassificationMatrix = <String, CbtTrackArchetype>{
        // Matriculation
        'Unified Tertiary Matriculation Examination': CbtTrackArchetype.matriculation,
        'JAMB UTME 2025': CbtTrackArchetype.matriculation,
        'Joint Admissions and Matriculation Board': CbtTrackArchetype.matriculation,
        'Post-UTME Screening Exam': CbtTrackArchetype.matriculation,
        'Direct Entry Matriculation': CbtTrackArchetype.matriculation,
        'PUTME Practice Exam': CbtTrackArchetype.matriculation,

        // Secondary School (WAEC/NECO/Term exams)
        'Second Term Exam': CbtTrackArchetype.secondary,
        'First Term Examination': CbtTrackArchetype.secondary,
        'WASSCE May/June 2025': CbtTrackArchetype.secondary,
        'WAEC GCE Prep': CbtTrackArchetype.secondary,
        'NECO Senior School Certificate (SSCE)': CbtTrackArchetype.secondary,
        'NABTEB Technical Exam': CbtTrackArchetype.secondary,
        'BECE Junior WAEC': CbtTrackArchetype.secondary,
        'Senior Secondary School Mock': CbtTrackArchetype.secondary,
        'Junior Secondary JS3 Exam': CbtTrackArchetype.secondary,

        // Substring Traps (Must NOT trigger tertiary or professional)
        'Mastery Quiz': CbtTrackArchetype.matriculation,
        'Barbados Geography Test': CbtTrackArchetype.matriculation,
        'Uncertainty in Physics Unit Test': CbtTrackArchetype.matriculation,

        // Tertiary (Degree / GPA)
        'B.Sc Computer Science Degree': CbtTrackArchetype.tertiary,
        'University Semester Exam': CbtTrackArchetype.tertiary,
        'Polytechnic Higher National Diploma (HND)': CbtTrackArchetype.tertiary,
        'Ordinary National Diploma (OND)': CbtTrackArchetype.tertiary,
        'Undergraduate GPA Assessment': CbtTrackArchetype.tertiary,
        'Master of Science in Economics': CbtTrackArchetype.tertiary,

        // Professional Licensures
        'ICAN Professional Examination': CbtTrackArchetype.professional,
        'Nigerian Bar Exam Finals': CbtTrackArchetype.professional,
        'Bar Exam Prep': CbtTrackArchetype.professional,
        'PMP Certification Exam': CbtTrackArchetype.professional,
        'ACCA Foundation in Accountancy': CbtTrackArchetype.professional,
        'Medical Licensure Exam': CbtTrackArchetype.professional,
      };

      for (final entry in examClassificationMatrix.entries) {
        test('Title "${entry.key}" classifies strictly as ${entry.value}', () {
          final resolvedArchetype = CbtReadinessCalculator.resolveArchetype(entry.key);
          expect(
            resolvedArchetype,
            equals(entry.value),
            reason: 'Classification failed for "${entry.key}". Expected ${entry.value} but got $resolvedArchetype',
          );

          // Verify end-to-end compute with this exam title applies appropriate grading scheme
          final result = calculator.compute(
            syllabusCoverage: 0.75,
            fsrsRetentionRate: 0.80,
            mockScoreRatio: 0.75,
            daysRemaining: 30,
            examType: entry.key,
          );

          switch (entry.value) {
            case CbtTrackArchetype.matriculation:
              expect(result.projectedScoreRange, contains('/ 400'));
            case CbtTrackArchetype.secondary:
              expect(result.projectedGrade, matches(RegExp(r'^(A1|B2|B3|C4|C5|C6|D7|E8|F9)$')));
            case CbtTrackArchetype.tertiary:
              expect(result.projectedGrade, contains('GPA'));
              expect(result.projectedScoreRange, contains('GPA'));
            case CbtTrackArchetype.professional:
              expect(result.projectedGrade, isIn(['Distinction', 'Merit', 'Pass', 'Referral']));
          }
        });
      }
    });

    group('Scenario 5: Grade Band Boundary Checks (Continuous Bands Without Gaps)', () {
      final boundaryChecks = <({
        int points,
        String expectedBand,
        String? expectedGradePill,
      })>[
        (points: 179, expectedBand: '< 180 Band', expectedGradePill: '< 180'),
        (points: 180, expectedBand: '180 - 189 Band', expectedGradePill: '180+'),
        (points: 185, expectedBand: '180 - 189 Band', expectedGradePill: '180+'),
        (points: 189, expectedBand: '180 - 189 Band', expectedGradePill: '180+'),
        (points: 190, expectedBand: '190 - 219 Band', expectedGradePill: '180+'),
        (points: 219, expectedBand: '190 - 219 Band', expectedGradePill: null),
        (points: 220, expectedBand: '220 - 249 Band', expectedGradePill: null),
        (points: 249, expectedBand: '220 - 249 Band', expectedGradePill: null),
        (points: 250, expectedBand: '250 - 279 Band', expectedGradePill: null),
        (points: 279, expectedBand: '250 - 279 Band', expectedGradePill: null),
        (points: 280, expectedBand: '280 - 319 Band', expectedGradePill: '280+'),
        (points: 315, expectedBand: '280 - 319 Band', expectedGradePill: '280+'),
        (points: 316, expectedBand: '280 - 319 Band', expectedGradePill: '280+'), // Critical audit boundary
        (points: 319, expectedBand: '280 - 319 Band', expectedGradePill: '280+'),
        (points: 320, expectedBand: '320 - 400 Band', expectedGradePill: '320+'),
        (points: 360, expectedBand: '320 - 400 Band', expectedGradePill: '320+'),
        (points: 361, expectedBand: '320 - 400 Band', expectedGradePill: '320+'), // Critical audit boundary
        (points: 400, expectedBand: '320 - 400 Band', expectedGradePill: '320+'),
      ];

      for (final check in boundaryChecks) {
        test('Points ${check.points} correctly resolves to ${check.expectedBand}', () {
          // Direct band helper check
          expect(
            CbtReadinessCalculator.getJambBand(check.points),
            equals(check.expectedBand),
            reason: 'Direct band helper failed for ${check.points} points',
          );

          // Full compute check with synthetic breakdown
          final result = calculator.compute(
            syllabusCoverage: 0.8,
            fsrsRetentionRate: 0.8,
            mockScoreRatio: 0.8,
            daysRemaining: 20,
            subjectBreakdowns: [
              SubjectReadinessBreakdown(
                subjectName: 'Use of English',
                courseCode: 'ENG',
                readinessPercent: (check.points / 4).round(),
                coveragePercent: 0.8,
                accuracyPercent: 0.8,
                projectedScore: check.points,
                maxScore: 400,
                projectedGrade: '${check.points} pts',
              ),
            ],
          );

          expect(
            result.projectedScoreRange,
            contains(check.expectedBand),
            reason: 'Computed score range for ${check.points} must contain "${check.expectedBand}"',
          );

          if (check.expectedGradePill != null) {
            expect(
              result.projectedGrade,
              equals(check.expectedGradePill),
              reason: 'Computed grade pill for ${check.points} must be "${check.expectedGradePill}"',
            );
          }
        });
      }
    });

    group('Scenario 6: JAMB Multi-Subject Normalization (Strict 400 Max Score Ceiling)', () {
      final courseCountScenarios = <int>[1, 2, 3, 4, 6, 8, 9, 12];

      for (final count in courseCountScenarios) {
        test('Normalizes $count registered courses to strict 400 max score ceiling', () {
          final courses = List.generate(
            count,
            (i) => RegisteredCourseInput(
              courseCode: 'SUBJ-$i',
              title: 'Subject $i',
              syllabusCoverage: 0.95,
              accuracyPercent: 0.90,
              retentionRate: 0.92,
            ),
          );

          final result = calculator.compute(
            syllabusCoverage: 0.95,
            fsrsRetentionRate: 0.92,
            mockScoreRatio: 0.90,
            daysRemaining: 15,
            registeredCourses: courses,
          );

          expect(result.subjectBreakdowns.length, equals(count));

          for (final sub in result.subjectBreakdowns) {
            expect(sub.maxScore, equals(100), reason: 'Each JAMB subject must be scaled out of 100 points');
            expect(sub.projectedScore, inInclusiveRange(0, 100));
          }

          expect(result.projectedTotalScore, inInclusiveRange(0, 400), reason: 'Total score must never exceed 400');
          expect(result.projectedScoreRange, contains('/ 400'), reason: 'Score range must format with / 400');

          // Ensure old divergent denominators are never output
          final prohibitedDenominators = ['/ 100', '/ 200', '/ 300', '/ 450', '/ 600', '/ 800', '/ 900', '/ 1200'];
          for (final badDenom in prohibitedDenominators) {
            if (badDenom != '/ 400') {
              expect(result.projectedScoreRange, isNot(contains(badDenom)), reason: 'Prohibited denominator: $badDenom');
            }
          }
        });
      }
    });

    group('Scenario 7: WAEC / WASSCE Core 5 Credits Requirement (English & Maths Mandatory)', () {
      final waecCandidateProfiles = <({
        String description,
        List<RegisteredCourseInput> courses,
        String expectedStatusLabel,
        CbtReadinessStatusTier expectedTier,
        String? expectedRangeAnnotation,
      })>[
        (
          description: 'Candidate with 5+ credits including English (A1) and Maths (B2) -> ON TRACK',
          courses: [
            const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.90, accuracyPercent: 0.85),
            const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.85, accuracyPercent: 0.80),
            const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'ECN', title: 'Economics', syllabusCoverage: 0.70, accuracyPercent: 0.65),
            const RegisteredCourseInput(courseCode: 'AGR', title: 'Agricultural Science', syllabusCoverage: 0.70, accuracyPercent: 0.65),
          ],
          expectedStatusLabel: 'ON TRACK',
          expectedTier: CbtReadinessStatusTier.onTrack,
          expectedRangeAnnotation: null,
        ),
        (
          description: 'Candidate with 7 credits but English is D7 (45% pass, not credit) -> ACCELERATE PREP',
          courses: [
            const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.40, accuracyPercent: 0.45), // D7 (non-credit)
            const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.85, accuracyPercent: 0.80), // B2
            const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'ECN', title: 'Economics', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'GEO', title: 'Geography', syllabusCoverage: 0.80, accuracyPercent: 0.75),
          ],
          expectedStatusLabel: 'ACCELERATE PREP',
          expectedTier: CbtReadinessStatusTier.acceleratePrep,
          expectedRangeAnnotation: 'Missing English Credit',
        ),
        (
          description: 'Candidate with 7 credits but Mathematics is E8 (40% pass, not credit) -> ACCELERATE PREP',
          courses: [
            const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.85, accuracyPercent: 0.82), // B2
            const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.35, accuracyPercent: 0.40), // E8 (non-credit)
            const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'ECN', title: 'Economics', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'GEO', title: 'Geography', syllabusCoverage: 0.80, accuracyPercent: 0.75),
          ],
          expectedStatusLabel: 'ACCELERATE PREP',
          expectedTier: CbtReadinessStatusTier.acceleratePrep,
          expectedRangeAnnotation: 'Missing Math Credit',
        ),
        (
          description: 'Candidate with credits in sciences but BOTH English and Maths are F9 (25%) -> ACCELERATE PREP',
          courses: [
            const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.20, accuracyPercent: 0.25), // F9
            const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.20, accuracyPercent: 0.25), // F9
            const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'ECN', title: 'Economics', syllabusCoverage: 0.80, accuracyPercent: 0.75),
            const RegisteredCourseInput(courseCode: 'GEO', title: 'Geography', syllabusCoverage: 0.80, accuracyPercent: 0.75),
          ],
          expectedStatusLabel: 'ACCELERATE PREP',
          expectedTier: CbtReadinessStatusTier.acceleratePrep,
          expectedRangeAnnotation: 'Missing English & Math Credit',
        ),
        (
          description: 'Candidate with only 2 credits overall and low overall aggregate (failing benchmark) -> NEEDS TRIAGE',
          courses: [
            const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.50, accuracyPercent: 0.52), // Credit (C6)
            const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.50, accuracyPercent: 0.50), // Credit (C6)
            const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.10, accuracyPercent: 0.10), // F9
            const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.10, accuracyPercent: 0.10), // F9
            const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.10, accuracyPercent: 0.10), // F9
          ],
          expectedStatusLabel: 'NEEDS TRIAGE',
          expectedTier: CbtReadinessStatusTier.needsTriage,
          expectedRangeAnnotation: null,
        ),
      ];

      for (final profile in waecCandidateProfiles) {
        test(profile.description, () {
          final isTriageProfile = profile.expectedTier == CbtReadinessStatusTier.needsTriage;
          final result = calculator.compute(
            syllabusCoverage: isTriageProfile ? 0.25 : 0.60,
            fsrsRetentionRate: isTriageProfile ? 0.25 : 0.65,
            mockScoreRatio: isTriageProfile ? 0.25 : 0.60,
            daysRemaining: 25,
            examType: 'WASSCE',
            registeredCourses: profile.courses,
          );

          expect(
            result.statusLabel,
            equals(profile.expectedStatusLabel),
            reason: 'Status label failed for ${profile.description}',
          );
          expect(
            result.statusTier,
            equals(profile.expectedTier),
            reason: 'Status tier failed for ${profile.description}',
          );

          if (profile.expectedRangeAnnotation != null) {
            expect(
              result.projectedScoreRange,
              contains(profile.expectedRangeAnnotation),
              reason: 'Score range must note "${profile.expectedRangeAnnotation}" for ${profile.description}',
            );
          }
        });
      }
    });

    group('Scenario 8: Dynamic Course Conversion Edge Cases & Malformed Data Defense', () {
      test('convertCourses safely handles null and empty inputs', () {
        expect(RegisteredCourseInput.convertCourses(null), isEmpty);
        expect(RegisteredCourseInput.convertCourses([]), isEmpty);
        expect(RegisteredCourseInput.convertCourses([null, null]), isEmpty);
      });

      test('fromDynamic parses CuratedCourseEntity, snake_case maps, and string numbers correctly', () {
        final dynamicInputs = <dynamic>[
          const CuratedCourseEntity(
            id: 'bio-101',
            courseCode: 'BIO101',
            title: 'Introductory Biology',
            syllabusCoverage: 0.85,
            department: 'Biological Sciences',
            totalMaterials: 12,
            hasActivePastPapers: true,
            accuracyPercent: 0.80,
            retentionRate: 0.78,
            iconName: 'biotech',
            colorHex: '#10B981',
          ),
          {
            'course_code': 'CHM101',
            'title': 'General Chemistry',
            'syllabus_coverage': '0.70',
            'department': 'Physical Sciences',
            'accuracyPercent': '0.65',
            'retentionRate': 0.60,
            'iconName': 'science',
            'colorHex': '#F59E0B',
          },
          {
            'courseCode': 'PHY101',
            'title': 'General Physics I',
            'syllabusCoverage': 0.55,
            'accuracyPercent': 0.50,
          },
        ];

        final converted = RegisteredCourseInput.convertCourses(dynamicInputs);
        expect(converted.length, equals(3));

        expect(converted[0].courseCode, equals('BIO101'));
        expect(converted[0].title, equals('Introductory Biology'));
        expect(converted[0].syllabusCoverage, equals(0.85));
        expect(converted[0].accuracyPercent, equals(0.80));
        expect(converted[0].retentionRate, equals(0.78));

        expect(converted[1].courseCode, equals('CHM101'));
        expect(converted[1].title, equals('General Chemistry'));
        expect(converted[1].syllabusCoverage, equals(0.70));
        expect(converted[1].accuracyPercent, equals(0.65));
        expect(converted[1].retentionRate, equals(0.60));

        expect(converted[2].courseCode, equals('PHY101'));
        expect(converted[2].title, equals('General Physics I'));
        expect(converted[2].syllabusCoverage, equals(0.55));
        expect(converted[2].accuracyPercent, equals(0.50));
      });

      test('fromDynamic handles malformed objects with graceful fallbacks and no uncaught exceptions', () {
        final malformedInputs = <dynamic>[
          {'invalid_key': 12345},
          {'courseCode': null, 'title': null, 'syllabusCoverage': 'not_a_number'},
        ];

        final converted = RegisteredCourseInput.convertCourses(malformedInputs);
        expect(converted.length, equals(2));
        expect(converted[0].courseCode, isEmpty);
        expect(converted[0].title, isEmpty);
        expect(converted[0].syllabusCoverage, equals(0.0));
        expect(converted[1].syllabusCoverage, equals(0.0));
      });
    });

    group('Scenario 9: Psychometric Sample Size & Standard Error of Proportion (Confidence Interval)', () {
      final sampleSizeCases = <({
        int questions,
        bool expectedSufficient,
        int minMargin,
        int maxMargin,
        String description,
      })>[
        (questions: 0, expectedSufficient: false, minMargin: 0, maxMargin: 0, description: 'Zero questions answered'),
        (questions: 15, expectedSufficient: false, minMargin: 0, maxMargin: 0, description: '15 questions (below n=30 threshold)'),
        (questions: 29, expectedSufficient: false, minMargin: 0, maxMargin: 0, description: '29 questions (boundary below threshold)'),
        (questions: 30, expectedSufficient: true, minMargin: 10, maxMargin: 15, description: '30 questions (exact threshold)'),
        (questions: 100, expectedSufficient: true, minMargin: 6, maxMargin: 9, description: '100 questions (moderate sample)'),
        (questions: 400, expectedSufficient: true, minMargin: 3, maxMargin: 5, description: '400 questions (full mock sample)'),
        (questions: 2000, expectedSufficient: true, minMargin: 2, maxMargin: 2, description: '2000 questions (reaches 2% floor clamp)'),
      ];

      for (final testCase in sampleSizeCases) {
        test('Evaluates sample size for ${testCase.description}', () {
          final result = calculator.compute(
            syllabusCoverage: 0.70,
            fsrsRetentionRate: 0.70,
            mockScoreRatio: 0.70,
            daysRemaining: 30,
            totalQuestionsAnswered: testCase.questions,
          );

          expect(result.isSampleSufficient, equals(testCase.expectedSufficient));
          expect(result.confidenceMargin, inInclusiveRange(testCase.minMargin, testCase.maxMargin));

          if (!testCase.expectedSufficient) {
            expect(result.confidenceIntervalLabel, contains('Low sample size'));
          } else {
            expect(
              result.confidenceIntervalLabel,
              matches(RegExp(r'Readiness: \d+% ± \d+% \(Based on ' + testCase.questions.toString() + r' questions across 1 subject\)')),
            );
          }
        });
      }

      test('Auto-sums subjectQuestionCounts map when totalQuestionsAnswered is 0', () {
        final result = calculator.compute(
          syllabusCoverage: 0.80,
          fsrsRetentionRate: 0.80,
          mockScoreRatio: 0.80,
          daysRemaining: 30,
          subjectQuestionCounts: const {
            'eng': 20,
            'mth': 15,
            'phy': 15,
          },
          registeredCourses: const [
            RegisteredCourseInput(courseCode: 'ENG', title: 'English', syllabusCoverage: 0.8),
            RegisteredCourseInput(courseCode: 'MTH', title: 'Mathematics', syllabusCoverage: 0.8),
            RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.8),
          ],
        );

        expect(result.totalQuestionsAnswered, equals(50));
        expect(result.isSampleSufficient, isTrue);
        expect(result.confidenceIntervalLabel, contains('50 questions across 3 subjects'));
      });
    });

    group('Scenario 10: Speed & Pacing Factor Edge Cases & Boundary Thresholds', () {
      final speedTestCases = <({
        double secondsPerItem,
        double expectedSpeedFactor,
        String expectedDiagnosticLabel,
      })>[
        (secondsPerItem: 20.0, expectedSpeedFactor: 1.0, expectedDiagnosticLabel: 'Optimal Pace: 20s/item'),
        (secondsPerItem: 55.0, expectedSpeedFactor: 1.0, expectedDiagnosticLabel: 'Optimal Pace: 55s/item'),
        (secondsPerItem: 55.1, expectedSpeedFactor: 0.85, expectedDiagnosticLabel: 'Moderate Pace: 55s/item'),
        (secondsPerItem: 65.0, expectedSpeedFactor: 0.85, expectedDiagnosticLabel: 'Moderate Pace: 65s/item'),
        (secondsPerItem: 70.0, expectedSpeedFactor: 0.85, expectedDiagnosticLabel: 'Moderate Pace: 70s/item'),
        (secondsPerItem: 70.1, expectedSpeedFactor: 0.65, expectedDiagnosticLabel: 'Time Risk: 70s/item (Slow)'),
        (secondsPerItem: 120.0, expectedSpeedFactor: 0.65, expectedDiagnosticLabel: 'Time Risk: 120s/item (Slow)'),
      ];

      for (final tc in speedTestCases) {
        test('Pacing ${tc.secondsPerItem}s/item yields factor ${tc.expectedSpeedFactor}', () {
          final result = calculator.compute(
            syllabusCoverage: 0.70,
            fsrsRetentionRate: 0.70,
            mockScoreRatio: 0.70,
            daysRemaining: 30,
            averageSecondsPerQuestion: tc.secondsPerItem,
          );

          expect(result.speedReadinessRatio, equals(tc.expectedSpeedFactor));
          expect(result.speedDiagnosticLabel, equals(tc.expectedDiagnosticLabel));
        });
      }

      test('Pacing time risk triggers pacing alert remediation when speed is the bottleneck', () {
        final result = calculator.compute(
          syllabusCoverage: 0.70,
          fsrsRetentionRate: 0.70,
          mockScoreRatio: 0.70,
          daysRemaining: 15,
          averageSecondsPerQuestion: 85, // Slow pace triggers speedFactor 0.65 < 0.8
        );

        expect(result.speedReadinessRatio, equals(0.65));
        expect(result.weakestAreaLabel, equals('Time Pressure & Solving Speed'));
        expect(result.remediationSuggestion, contains('Pacing Alert: Practice 15 timed sprint questions'));
      });
    });

    group('Scenario 11: Time Factor & Days Remaining Urgency Curves', () {
      final daysProgressionCases = <({
        int daysRemaining,
        double coverage,
        String description,
      })>[
        (daysRemaining: 0, coverage: 0.30, description: 'Exam day (0 days) with 30% coverage'),
        (daysRemaining: 5, coverage: 0.30, description: 'Panic week (5 days) with 30% coverage'),
        (daysRemaining: 25, coverage: 0.30, description: 'Final month (25 days) with 30% coverage'),
        (daysRemaining: 60, coverage: 0.30, description: 'Long runway (60 days) with 30% coverage'),
      ];

      test('Low coverage scores higher on distant exams than on impending exams due to time factor penalty', () {
        final results = daysProgressionCases.map((tc) {
          return calculator.compute(
            syllabusCoverage: tc.coverage,
            fsrsRetentionRate: 0.60,
            mockScoreRatio: 0.60,
            daysRemaining: tc.daysRemaining,
          );
        }).toList();

        // 60 days remaining (distant) should score >= 25 days >= 5 days
        expect(results[3].scorePercent, greaterThanOrEqualTo(results[2].scorePercent));
        expect(results[2].scorePercent, greaterThanOrEqualTo(results[1].scorePercent));
      });
    });

    group('Scenario 12: Partial Course Calibration & Diagnostic CTA Resolution', () {
      test('Identifies uncalibrated courses, sets Gray color 0xFF6B7280 and assigns Take 10-Item Diagnostic CTA', () {
        const courses = [
          RegisteredCourseInput(
            courseCode: 'ENG',
            title: 'Use of English',
            syllabusCoverage: 0.80,
            accuracyPercent: 0.85,
            retentionRate: 0.80,
          ),
          RegisteredCourseInput(
            courseCode: 'MTH',
            title: 'Mathematics',
            syllabusCoverage: 0.70,
            accuracyPercent: 0.75,
            retentionRate: 0.70,
          ),
          RegisteredCourseInput(
            courseCode: 'PHY',
            title: 'Physics',
            syllabusCoverage: 0,
          ),
          RegisteredCourseInput(
            courseCode: 'CHM',
            title: 'Chemistry',
            syllabusCoverage: 0,
          ),
        ];

        final result = calculator.compute(
          syllabusCoverage: 0.75,
          fsrsRetentionRate: 0.75,
          mockScoreRatio: 0.75,
          daysRemaining: 30,
          registeredCourses: courses,
        );

        expect(result.calibratedCourseCount, equals(2));
        expect(result.totalCourseCount, equals(4));
        expect(result.isFullyCalibrated, isFalse);

        final eng = result.subjectBreakdowns.firstWhere((b) => b.courseCode == 'ENG');
        final mth = result.subjectBreakdowns.firstWhere((b) => b.courseCode == 'MTH');
        final phy = result.subjectBreakdowns.firstWhere((b) => b.courseCode == 'PHY');
        final chm = result.subjectBreakdowns.firstWhere((b) => b.courseCode == 'CHM');

        expect(eng.isCalibrated, isTrue);
        expect(eng.diagnosticCta, isEmpty);
        expect(eng.projectedScore, greaterThan(0));

        expect(mth.isCalibrated, isTrue);
        expect(mth.diagnosticCta, isEmpty);
        expect(mth.projectedScore, greaterThan(0));

        expect(phy.isCalibrated, isFalse);
        expect(phy.diagnosticCta, equals('Take 10-Item Diagnostic'));
        expect(phy.projectedScore, equals(0));
        expect(phy.statusColorValue, equals(0xFF6B7280)); // Gray

        expect(chm.isCalibrated, isFalse);
        expect(chm.diagnosticCta, equals('Take 10-Item Diagnostic'));
        expect(chm.projectedScore, equals(0));
        expect(chm.statusColorValue, equals(0xFF6B7280)); // Gray

        expect(result.projectedScoreRange, contains('- 2 of 4 Calibrated'));
        expect(result.remediationSuggestion, contains('Calibrate Physics: Complete a 10-item diagnostic quiz'));
      });
    });

    group('Scenario 13: Tertiary GPA Degrees & Professional Certifications Matrix', () {
      final directGpaBoundaries = <({double gpa, String expectedClass})>[
        (gpa: 5.00, expectedClass: 'First Class Honors'),
        (gpa: 4.50, expectedClass: 'First Class Honors'),
        (gpa: 4.49, expectedClass: 'Second Class Upper'),
        (gpa: 3.50, expectedClass: 'Second Class Upper'),
        (gpa: 3.49, expectedClass: 'Second Class Lower'),
        (gpa: 2.40, expectedClass: 'Second Class Lower'),
        (gpa: 2.39, expectedClass: 'Third Class'),
        (gpa: 1.50, expectedClass: 'Third Class'),
        (gpa: 1.49, expectedClass: 'Pass / Academic Warning'),
        (gpa: 0.00, expectedClass: 'Pass / Academic Warning'),
      ];

      for (final tc in directGpaBoundaries) {
        test('Direct GPA boundary ${tc.gpa} evaluates to ${tc.expectedClass}', () {
          expect(CbtReadinessService.getTertiaryDegreeClass(tc.gpa), equals(tc.expectedClass));
        });
      }

      final gpaCases = <({
        double mockScore,
        String expectedDegreeClass,
      })>[
        (mockScore: 0.95, expectedDegreeClass: 'First Class Honors'),
        (mockScore: 0.70, expectedDegreeClass: 'Second Class Upper'),
        (mockScore: 0.45, expectedDegreeClass: 'Second Class Lower'),
        (mockScore: 0.25, expectedDegreeClass: 'Third Class'),
        (mockScore: 0.05, expectedDegreeClass: 'Pass / Academic Warning'),
      ];

      for (final tc in gpaCases) {
        test('Tertiary exam with mock ${tc.mockScore} resolves to ${tc.expectedDegreeClass}', () {
          final result = calculator.compute(
            syllabusCoverage: tc.mockScore,
            fsrsRetentionRate: tc.mockScore,
            mockScoreRatio: tc.mockScore,
            daysRemaining: 40,
            examType: 'University Semester Degree Examination',
          );

          expect(result.projectedScoreRange, contains(tc.expectedDegreeClass));
          expect(result.projectedGrade, contains('GPA'));
        });
      }

      final directProfBoundaries = <({int percent, String expectedGrade})>[
        (percent: 100, expectedGrade: 'Distinction'),
        (percent: 85, expectedGrade: 'Distinction'),
        (percent: 84, expectedGrade: 'Merit'),
        (percent: 70, expectedGrade: 'Merit'),
        (percent: 69, expectedGrade: 'Pass'),
        (percent: 50, expectedGrade: 'Pass'),
        (percent: 49, expectedGrade: 'Unsatisfactory'),
        (percent: 0, expectedGrade: 'Unsatisfactory'),
      ];

      for (final tc in directProfBoundaries) {
        test('Direct professional grade boundary ${tc.percent}% evaluates to ${tc.expectedGrade}', () {
          expect(CbtReadinessService.getProfessionalGrade(tc.percent), equals(tc.expectedGrade));
        });
      }

      final professionalCases = <({
        double mockScore,
        String expectedGrade,
      })>[
        (mockScore: 0.90, expectedGrade: 'Distinction'),
        (mockScore: 0.75, expectedGrade: 'Merit'),
        (mockScore: 0.55, expectedGrade: 'Pass'),
        (mockScore: 0.35, expectedGrade: 'Unsatisfactory'),
      ];

      for (final tc in professionalCases) {
        test('Professional exam with mock ${tc.mockScore} resolves to ${tc.expectedGrade}', () {
          final result = calculator.compute(
            syllabusCoverage: tc.mockScore,
            fsrsRetentionRate: tc.mockScore,
            mockScoreRatio: tc.mockScore,
            daysRemaining: 40,
            examType: 'ICAN Professional Examination',
          );

          expect(result.projectedGrade, equals(tc.expectedGrade));
        });
      }
    });

    group('Scenario 14: Socratic Remediation Strategy Priority Tree', () {
      test('Priority 1: Uncalibrated WAEC student receives subject diagnostic suggestion', () {
        final result = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0,
          mockScoreRatio: 0,
          daysRemaining: 40,
          examType: 'WAEC',
        );
        expect(result.remediationSuggestion, contains('Complete a 10-item diagnostic quiz per subject'));
      });

      test('Priority 2: Uncalibrated JAMB student receives course diagnostic suggestion', () {
        final result = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0,
          mockScoreRatio: 0,
          daysRemaining: 40,
        );
        expect(result.remediationSuggestion, contains('Complete a 10-item diagnostic quiz per course'));
      });

      test('Priority 3: High performer (>=85%) receives distinction sprint suggestion', () {
        final result = calculator.compute(
          syllabusCoverage: 0.90,
          fsrsRetentionRate: 0.90,
          mockScoreRatio: 0.90,
          daysRemaining: 20,
        );
        expect(result.remediationSuggestion, contains('Maintain momentum with a 10-minute timed mock sprint'));
      });

      test('Priority 4: Low retention (<70%) triggers flashcard review suggestion', () {
        final result = calculator.compute(
          syllabusCoverage: 0.80,
          fsrsRetentionRate: 0.60,
          mockScoreRatio: 0.75,
          daysRemaining: 20,
        );
        expect(result.remediationSuggestion, contains('Review 15 high-priority flashcards to refresh fading topics'));
      });

      test('Priority 5: Low coverage (<60%) triggers syllabus topic module suggestion', () {
        final result = calculator.compute(
          syllabusCoverage: 0.50,
          fsrsRetentionRate: 0.75,
          mockScoreRatio: 0.75,
          daysRemaining: 20,
        );
        expect(result.remediationSuggestion, contains('Complete 1 new syllabus topic module to boost overall syllabus coverage'));
      });
    });

    group('Scenario 15: Presentation UI Extensions (Colors & Status Icons)', () {
      test('CbtReadinessResultUiExtension maps tiers to exact brand colors and icons', () {
        final pending = calculator.compute(
          syllabusCoverage: 0,
          fsrsRetentionRate: 0,
          mockScoreRatio: 0,
          daysRemaining: 30,
        );
        expect(pending.statusColor.toARGB32(), equals(0xFF6366F1));

        final onTrack = calculator.compute(
          syllabusCoverage: 0.85,
          fsrsRetentionRate: 0.85,
          mockScoreRatio: 0.85,
          daysRemaining: 30,
        );
        expect(onTrack.statusColor.toARGB32(), equals(0xFF10B981));

        final triage = calculator.compute(
          syllabusCoverage: 0.20,
          fsrsRetentionRate: 0.20,
          mockScoreRatio: 0.20,
          daysRemaining: 30,
        );
        expect(triage.statusColor.toARGB32(), equals(0xFFEF4444));
      });

      test('SubjectReadinessBreakdownUiExtension returns Color or null cleanly', () {
        const calibrated = SubjectReadinessBreakdown(
          subjectName: 'Math',
          readinessPercent: 80,
          coveragePercent: 0.8,
          accuracyPercent: 0.8,
          projectedScore: 80,
          maxScore: 100,
          statusColorValue: 0xFF10B981,
        );
        expect(calibrated.statusColor?.toARGB32(), equals(0xFF10B981));

        const uncalibrated = SubjectReadinessBreakdown(
          subjectName: 'Physics',
          readinessPercent: 0,
          coveragePercent: 0,
          accuracyPercent: 0,
          projectedScore: 0,
          maxScore: 100,
        );
        expect(uncalibrated.statusColor, isNull);
      });
    });
  });
}
