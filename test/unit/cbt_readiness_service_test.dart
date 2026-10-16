import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/domain/services/cbt_readiness_service.dart';

void main() {
  group('Pure CbtReadinessService Domain Engine Tests', () {
    const service = CbtReadinessService();

    test('Zero activity evaluates to 0% and Diagnostic Pending without service locator', () {
      final result = service.compute(
        syllabusCoverage: 0,
        fsrsRetentionRate: 0,
        mockScoreRatio: 0,
        daysRemaining: 45,
      );

      expect(result.scorePercent, equals(0));
      expect(result.isCalibrated, isFalse);
      expect(result.hasSufficientData, isFalse);
      expect(result.statusTier, equals(CbtReadinessStatusTier.diagnosticPending));
      expect(result.statusColorValue, equals(0xFF6366F1));
      expect(result.statusLabel, equals('DIAGNOSTIC PENDING'));
      expect(result.projectedTotalScore, equals(0));
      expect(result.subjectBreakdowns, isEmpty);
    });

    test('Computes readiness using pure immutable subject performance maps', () {
      const courses = [
        RegisteredCourseInput(
          courseCode: 'MTH101',
          title: 'General Mathematics',
          syllabusCoverage: 0.80,
        ),
        RegisteredCourseInput(
          courseCode: 'PHY101',
          title: 'Physics',
          syllabusCoverage: 0.60,
        ),
      ];

      final result = service.compute(
        syllabusCoverage: 0.70,
        fsrsRetentionRate: 0.85,
        mockScoreRatio: 0.75,
        daysRemaining: 25,
        registeredCourses: courses,
        subjectAccuracies: {'mth101': 0.80, 'phy101': 0.70},
        subjectRetentions: {'mth101': 0.85, 'phy101': 0.75},
      );

      expect(result.isCalibrated, isTrue);
      expect(result.calibratedCourseCount, equals(2));
      expect(result.totalCourseCount, equals(2));
      expect(result.isFullyCalibrated, isTrue);
      expect(result.subjectBreakdowns.length, equals(2));
      expect(result.subjectBreakdowns[0].statusColorValue, equals(0xFF10B981)); // Emerald (>=75%)
      expect(result.scorePercent, greaterThan(60));
    });

    test('Uncalibrated course receives Gray status color value 0xFF6B7280', () {
      const courses = [
        RegisteredCourseInput(
          courseCode: 'BIO101',
          title: 'Biology',
          syllabusCoverage: 0,
        ),
      ];

      final result = service.compute(
        syllabusCoverage: 0,
        fsrsRetentionRate: 0,
        mockScoreRatio: 0,
        daysRemaining: 30,
        registeredCourses: courses,
      );

      expect(result.subjectBreakdowns.length, equals(1));
      expect(result.subjectBreakdowns.first.isCalibrated, isFalse);
      expect(result.subjectBreakdowns.first.statusColorValue, equals(0xFF6B7280));
      expect(result.subjectBreakdowns.first.projectedGrade, equals('Uncalibrated'));
    });

    group('P1-03: Psychometrically Accurate Archetype Resolution', () {
      test('19+ realistic exam titles resolve with 100% accuracy', () {
        final expectedResolutions = <String, CbtTrackArchetype>{
          // Matriculation (JAMB/UTME/Post-UTME)
          'Unified Tertiary Matriculation Examination': CbtTrackArchetype.matriculation,
          'JAMB UTME 2025': CbtTrackArchetype.matriculation,
          'Joint Admissions and Matriculation Board': CbtTrackArchetype.matriculation,
          'Post-UTME Screening Exam': CbtTrackArchetype.matriculation,
          'Direct Entry Matriculation': CbtTrackArchetype.matriculation,
          'PUTME Practice Exam': CbtTrackArchetype.matriculation,

          // Secondary school (WAEC/WASSCE/NECO/Term exams)
          'Second Term Exam': CbtTrackArchetype.secondary,
          'First Term Examination': CbtTrackArchetype.secondary,
          'WASSCE May/June 2025': CbtTrackArchetype.secondary,
          'WAEC GCE Prep': CbtTrackArchetype.secondary,
          'NECO Senior School Certificate (SSCE)': CbtTrackArchetype.secondary,
          'NABTEB Technical Exam': CbtTrackArchetype.secondary,
          'BECE Junior WAEC': CbtTrackArchetype.secondary,
          'Senior Secondary School Mock': CbtTrackArchetype.secondary,
          'Junior Secondary JS3 Exam': CbtTrackArchetype.secondary,

          // General / Quizzes (Trap titles that must NOT match tertiary or professional)
          'Mastery Quiz': CbtTrackArchetype.matriculation,
          'Barbados Geography Test': CbtTrackArchetype.matriculation,
          'Uncertainty in Physics Unit Test': CbtTrackArchetype.matriculation,

          // Tertiary (BSc/MSc/HND/OND/University)
          'B.Sc Computer Science Degree': CbtTrackArchetype.tertiary,
          'University Semester Exam': CbtTrackArchetype.tertiary,
          'Polytechnic Higher National Diploma (HND)': CbtTrackArchetype.tertiary,
          'Ordinary National Diploma (OND)': CbtTrackArchetype.tertiary,
          'Undergraduate GPA Assessment': CbtTrackArchetype.tertiary,
          'Master of Science in Economics': CbtTrackArchetype.tertiary,

          // Professional (ICAN/Bar/PMP/ACCA/Licensure)
          'ICAN Professional Examination': CbtTrackArchetype.professional,
          'Nigerian Bar Exam Finals': CbtTrackArchetype.professional,
          'Bar Exam Prep': CbtTrackArchetype.professional,
          'PMP Certification Exam': CbtTrackArchetype.professional,
          'ACCA Foundation in Accountancy': CbtTrackArchetype.professional,
          'Medical Licensure Exam': CbtTrackArchetype.professional,
        };

        for (final entry in expectedResolutions.entries) {
          final resolved = CbtReadinessService.resolveArchetype(entry.key);
          expect(
            resolved,
            equals(entry.value),
            reason: 'Failed on exam title: "${entry.key}". Expected ${entry.value} but got $resolved',
          );
        }
      });
    });

    group('P1-03: Continuous Score Bands Without Gaps', () {
      test('Score bands cover all integer points from 0 to 400 without holes or mislabels', () {
        final testCases = <int, String>{
          179: '< 180 Band',
          180: '180 - 189 Band',
          185: '180 - 189 Band',
          189: '180 - 189 Band',
          190: '190 - 219 Band',
          219: '190 - 219 Band',
          220: '220 - 249 Band',
          249: '220 - 249 Band',
          250: '250 - 279 Band',
          279: '250 - 279 Band',
          280: '280 - 319 Band',
          315: '280 - 319 Band',
          316: '280 - 319 Band', // previously fell into 280-315 Band
          319: '280 - 319 Band',
          320: '320 - 400 Band',
          360: '320 - 400 Band',
          361: '320 - 400 Band', // previously fell into 320-360 Band
          400: '320 - 400 Band',
        };

        for (final entry in testCases.entries) {
          final pts = entry.key;
          final expectedBand = entry.value;

          // 1. Direct psychometric band resolver verification
          expect(
            CbtReadinessService.getJambBand(pts),
            equals(expectedBand),
            reason: 'For points $pts, expected getJambBand to return "$expectedBand"',
          );

          // 2. End-to-end engine compute verification
          final breakdowns = [
            SubjectReadinessBreakdown(
              subjectName: 'Use of English',
              courseCode: 'ENG',
              readinessPercent: (pts / 4).round(),
              coveragePercent: 0.8,
              accuracyPercent: 0.8,
              projectedScore: pts,
              maxScore: 400,
              projectedGrade: '$pts pts',
              statusColorValue: 0xFF10B981,
            ),
          ];

          final result = service.compute(
            syllabusCoverage: 0.8,
            fsrsRetentionRate: 0.8,
            mockScoreRatio: 0.8,
            daysRemaining: 15,
            subjectBreakdowns: breakdowns,
          );

          expect(
            result.projectedScoreRange,
            contains(expectedBand),
            reason: 'For points $pts, expected band "$expectedBand" but got "${result.projectedScoreRange}"',
          );

          if (pts >= 180 && pts < 200) {
            expect(result.projectedGrade, equals('180+'), reason: 'Points $pts should display 180+ pill');
          }
        }
      });
    });

    group('P1-03: JAMB 400-Point Ceiling Regardless of Course Count', () {
      test('JAMB max score is strictly 400 whether user registers 2, 3, 4, 9, or 12 courses', () {
        for (final count in [2, 3, 4, 9, 12]) {
          final courses = List.generate(
            count,
            (i) => RegisteredCourseInput(
              courseCode: 'SUB-$i',
              title: 'Subject $i',
              syllabusCoverage: 0.85,
              accuracyPercent: 0.80,
              retentionRate: 0.82,
            ),
          );

          final result = service.compute(
            syllabusCoverage: 0.85,
            fsrsRetentionRate: 0.82,
            mockScoreRatio: 0.80,
            daysRemaining: 20,
            registeredCourses: courses,
          );

          // Every single subject breakdown has maxScore of 100
          for (final sub in result.subjectBreakdowns) {
            expect(sub.maxScore, equals(100), reason: 'Each subject in JAMB must be scored out of 100 points');
            expect(sub.projectedScore, inInclusiveRange(0, 100));
          }

          // Total projected score must never exceed 400
          expect(result.projectedTotalScore, inInclusiveRange(0, 400));
          // Projected score range format must always show / 400
          expect(result.projectedScoreRange, contains('/ 400'), reason: 'JAMB score range must show / 400 for $count courses');
          expect(result.projectedScoreRange, isNot(contains('/ 200')));
          expect(result.projectedScoreRange, isNot(contains('/ 450')));
          expect(result.projectedScoreRange, isNot(contains('/ 600')));
          expect(result.projectedScoreRange, isNot(contains('/ 900')));
          expect(result.projectedScoreRange, isNot(contains('/ 1200')));
        }
      });
    });

    group('P1-03: WAEC / WASSCE Core Credit Pass Benchmark', () {
      test('Candidate with >= 5 credits including English & Math achieves ON TRACK', () {
        final courses = [
          const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.9, accuracyPercent: 0.85),
          const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.9, accuracyPercent: 0.85),
          const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.85, accuracyPercent: 0.80),
          const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.85, accuracyPercent: 0.80),
          const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.85, accuracyPercent: 0.75),
          const RegisteredCourseInput(courseCode: 'ECN', title: 'Economics', syllabusCoverage: 0.85, accuracyPercent: 0.75),
        ];

        final result = service.compute(
          syllabusCoverage: 0.85,
          fsrsRetentionRate: 0.80,
          mockScoreRatio: 0.80,
          daysRemaining: 30,
          examType: 'WASSCE',
          registeredCourses: courses,
        );

        expect(result.statusLabel, equals('ON TRACK'));
        expect(result.statusTier, equals(CbtReadinessStatusTier.onTrack));
        expect(result.projectedScoreRange, contains('6 / 6 Credits'));
        expect(result.projectedScoreRange, isNot(contains('Missing')));
      });

      test('Candidate with 5+ credits but failing English is NOT ON TRACK', () {
        final courses = [
          // Failing English (< 40% -> F9)
          const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.2, accuracyPercent: 0.25),
          // Passing Math and other 5 subjects
          const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.9, accuracyPercent: 0.85),
          const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.85, accuracyPercent: 0.80),
          const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.85, accuracyPercent: 0.80),
          const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.85, accuracyPercent: 0.75),
          const RegisteredCourseInput(courseCode: 'ECN', title: 'Economics', syllabusCoverage: 0.85, accuracyPercent: 0.75),
        ];

        final result = service.compute(
          syllabusCoverage: 0.80,
          fsrsRetentionRate: 0.75,
          mockScoreRatio: 0.75,
          daysRemaining: 30,
          examType: 'WASSCE',
          registeredCourses: courses,
        );

        // 5 credits exist, but English is failed: must NOT be ON TRACK!
        expect(result.statusLabel, isNot(equals('ON TRACK')));
        expect(result.statusTier, equals(CbtReadinessStatusTier.acceleratePrep));
        expect(result.projectedScoreRange, contains('Missing English Credit'));
        expect(result.remediationSuggestion, contains('WAEC Core Requirement: Focus on English'));
      });

      test('Candidate with 5+ credits but failing Mathematics is NOT ON TRACK', () {
        final courses = [
          // Passing English
          const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.9, accuracyPercent: 0.85),
          // Failing Math (< 40% -> F9)
          const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.2, accuracyPercent: 0.20),
          const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.85, accuracyPercent: 0.80),
          const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.85, accuracyPercent: 0.80),
          const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.85, accuracyPercent: 0.75),
          const RegisteredCourseInput(courseCode: 'ECN', title: 'Economics', syllabusCoverage: 0.85, accuracyPercent: 0.75),
        ];

        final result = service.compute(
          syllabusCoverage: 0.80,
          fsrsRetentionRate: 0.75,
          mockScoreRatio: 0.75,
          daysRemaining: 30,
          examType: 'WASSCE',
          registeredCourses: courses,
        );

        expect(result.statusLabel, isNot(equals('ON TRACK')));
        expect(result.statusTier, equals(CbtReadinessStatusTier.acceleratePrep));
        expect(result.projectedScoreRange, contains('Missing Math Credit'));
        expect(result.remediationSuggestion, contains('WAEC Core Requirement: Focus on Math'));
      });

      test('Candidate failing both English and Math is flagged with both deficiencies', () {
        final courses = [
          const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.2, accuracyPercent: 0.25),
          const RegisteredCourseInput(courseCode: 'MTH', title: 'General Mathematics', syllabusCoverage: 0.2, accuracyPercent: 0.20),
          const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.85, accuracyPercent: 0.80),
          const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.85, accuracyPercent: 0.80),
          const RegisteredCourseInput(courseCode: 'BIO', title: 'Biology', syllabusCoverage: 0.85, accuracyPercent: 0.75),
          const RegisteredCourseInput(courseCode: 'ECN', title: 'Economics', syllabusCoverage: 0.85, accuracyPercent: 0.75),
          const RegisteredCourseInput(courseCode: 'GEO', title: 'Geography', syllabusCoverage: 0.85, accuracyPercent: 0.75),
        ];

        final result = service.compute(
          syllabusCoverage: 0.80,
          fsrsRetentionRate: 0.75,
          mockScoreRatio: 0.75,
          daysRemaining: 30,
          examType: 'WASSCE',
          registeredCourses: courses,
        );

        expect(result.statusLabel, isNot(equals('ON TRACK')));
        expect(result.projectedScoreRange, contains('Missing English & Math Credit'));
        expect(result.remediationSuggestion, contains('English and Math'));
      });
    });

    group('P1-04: Decouple Accuracy from Retention & Transparent Confidence Intervals', () {
      test('Low sample size (< 30 questions) displays warning and marks isSampleSufficient = false', () {
        final resultZero = service.compute(
          syllabusCoverage: 0.60,
          fsrsRetentionRate: 0.85,
          mockScoreRatio: 0.70,
          daysRemaining: 30,
        );

        expect(resultZero.isSampleSufficient, isFalse);
        expect(resultZero.confidenceMargin, equals(0));
        expect(
          resultZero.confidenceIntervalLabel,
          equals('Low sample size — complete a full mock to improve projection accuracy'),
        );

        final resultLow = service.compute(
          syllabusCoverage: 0.60,
          fsrsRetentionRate: 0.85,
          mockScoreRatio: 0.70,
          daysRemaining: 30,
          totalQuestionsAnswered: 24,
        );

        expect(resultLow.isSampleSufficient, isFalse);
        expect(resultLow.confidenceMargin, equals(0));
        expect(
          resultLow.confidenceIntervalLabel,
          equals('Low sample size — complete a full mock to improve projection accuracy'),
        );
      });

      test('Sufficient sample size (>= 30 questions) computes accurate confidence interval label', () {
        final courses = [
          const RegisteredCourseInput(courseCode: 'ENG', title: 'English Language', syllabusCoverage: 0.70),
          const RegisteredCourseInput(courseCode: 'MTH', title: 'Mathematics', syllabusCoverage: 0.70),
          const RegisteredCourseInput(courseCode: 'PHY', title: 'Physics', syllabusCoverage: 0.65),
          const RegisteredCourseInput(courseCode: 'CHM', title: 'Chemistry', syllabusCoverage: 0.65),
        ];

        // Evaluating 140 questions across 4 subjects
        final result = service.compute(
          syllabusCoverage: 0.68,
          fsrsRetentionRate: 0.80,
          mockScoreRatio: 0.68,
          daysRemaining: 30,
          registeredCourses: courses,
          totalQuestionsAnswered: 140,
        );

        expect(result.isSampleSufficient, isTrue);
        expect(result.totalQuestionsAnswered, equals(140));
        expect(result.confidenceMargin, inInclusiveRange(5, 8));
        expect(
          result.confidenceIntervalLabel,
          matches(r'Readiness: \d+% ± \d+% \(Based on 140 questions across 4 subjects\)'),
        );
      });

      test('Flashcard retention rate is strictly decoupled from mock score accuracy', () {
        // High flashcard retention (0.95) with zero mock test practice (0)
        final resultNoMocks = service.compute(
          syllabusCoverage: 0.50,
          fsrsRetentionRate: 0.95,
          mockScoreRatio: 0,
          daysRemaining: 30,
        );

        expect(resultNoMocks.fsrsRetentionRate, equals(0.95));
        expect(resultNoMocks.mockScoreRatio, equals(0));

        // When student takes a mock test with 75% accuracy
        final resultWithMocks = service.compute(
          syllabusCoverage: 0.50,
          fsrsRetentionRate: 0.95,
          mockScoreRatio: 0.75,
          daysRemaining: 30,
        );

        expect(resultWithMocks.mockScoreRatio, equals(0.75));
        expect(resultWithMocks.scorePercent, greaterThan(resultNoMocks.scorePercent));
      });

      test('Per-subject question counts map into SubjectReadinessBreakdown', () {
        final courses = [
          const RegisteredCourseInput(courseCode: 'MTH 101', title: 'Mathematics', syllabusCoverage: 0.7),
          const RegisteredCourseInput(courseCode: 'ENG 101', title: 'English', syllabusCoverage: 0.8),
        ];

        final result = service.compute(
          syllabusCoverage: 0.75,
          fsrsRetentionRate: 0.85,
          mockScoreRatio: 0.80,
          daysRemaining: 30,
          registeredCourses: courses,
          subjectQuestionCounts: {'mth 101': 45, 'eng 101': 55},
        );

        expect(result.totalQuestionsAnswered, equals(100));
        expect(result.isSampleSufficient, isTrue);

        final mth = result.subjectBreakdowns.firstWhere((s) => s.courseCode == 'MTH 101');
        final eng = result.subjectBreakdowns.firstWhere((s) => s.courseCode == 'ENG 101');

        expect(mth.questionsAnswered, equals(45));
        expect(eng.questionsAnswered, equals(55));
      });
    });

  });
}
