import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';

void main() {
  group('User Track Calibration & Analytics Mapper Test Suite', () {
    test(
      'High School Track (JAMB) maps correctly to HighSchool focus',
      () {
        const profile = UserProfileEntity(
          id: 'user_hs_1',
          email: 'jamb_student@kortex.app',
          targetTrack: 'JAMB',
          dailyCardTarget: 30,
          isOnboarded: true,
        );

        final calibration = CalibrationProfile(
          focus: AcademicFocus.highSchool,
          highSchoolExam: profile.targetTrack,
          isCalibrated: profile.isOnboarded,
        );

        final feed = DashboardFeedEntity(
          calibrationProfile: calibration,
          analyticsSummary: const AnalyticsSummaryEntity(
            currentStreakDays: 7,
            longestStreakDays: 14,
            weeklyMinutesStudied: 210,
            overallRetentionRate: 0.85,
            totalCardsMastered: 140,
            heatMapData: [],
            xpPoints: 850,
            academicRank: 'Neural Adept',
          ),
          targetExamCountdown: ExamCountdownEntity(
            id: 'exam_jamb_2026',
            examName: 'UTME / JAMB Exam',
            targetDate: DateTime.now().add(const Duration(days: 90)),
            syllabusProgress: 0.65,
            subjectTrack: 'JAMB',
            totalMockPapersAvailable: 25,
            completedMocksCount: 8,
          ),
          dueStudyDecks: const [],
          curatedCourses: const [],
        );

        expect(feed.isHighSchoolCandidate, isTrue);
        expect(feed.isHigherEdStudent, isFalse);
        expect(feed.isProfileUncalibrated, isFalse);
        expect(feed.targetExamCountdown?.examName, contains('JAMB'));
        expect(feed.analyticsSummary.overallRetentionRate, equals(0.85));
      },
    );

    test(
      'Higher Education Track (University) maps correctly to HigherEducation',
      () {
        const profile = UserProfileEntity(
          id: 'user_uni_1',
          email: 'engineering@university.edu',
          targetTrack: 'University',
          dailyCardTarget: 50,
          retentionBenchmark: 0.90,
          isOnboarded: true,
        );

        final calibration = CalibrationProfile(
          higherEdField: 'Electrical Engineering',
          higherEdLevel: HigherEdLevel.bsc,
          isCalibrated: profile.isOnboarded,
        );

        final feed = DashboardFeedEntity(
          calibrationProfile: calibration,
          analyticsSummary: const AnalyticsSummaryEntity(
            currentStreakDays: 12,
            longestStreakDays: 30,
            weeklyMinutesStudied: 480,
            overallRetentionRate: 0.92,
            totalCardsMastered: 350,
            heatMapData: [],
            xpPoints: 2100,
            academicRank: 'Master Scholar',
          ),
          dueStudyDecks: const [],
          curatedCourses: const [],
        );

        expect(feed.isHigherEdStudent, isTrue);
        expect(feed.isHighSchoolCandidate, isFalse);
        expect(feed.isProfileUncalibrated, isFalse);
        expect(feed.analyticsSummary.totalCardsMastered, equals(350));
      },
    );

    test('Default Course Tracks contain required properties and icons', () {
      const tracks = CourseTrackEntity.defaultTracks;
      expect(tracks.length, greaterThanOrEqualTo(4));

      final waec = tracks.firstWhere((t) => t.id == 'WAEC');
      expect(waec.name, equals('WAEC / WASSCE'));
      expect(waec.defaultDailyTarget, equals(20));

      final jamb = tracks.firstWhere((t) => t.id == 'JAMB');
      expect(jamb.name, equals('JAMB / UTME'));
      expect(jamb.defaultDailyTarget, equals(25));
    });

    test(
      'isProfileUncalibrated is false when isCalibrated is false BUT track is selected and courses are enrolled',
      () {
        const calibration = CalibrationProfile(
          highSchoolExam: 'JAMB / UTME',
        );

        const dummyCourse = CuratedCourseEntity(
          id: 'c1',
          courseCode: 'MTH101',
          title: 'General Mathematics',
          department: 'Mathematics',
          totalMaterials: 10,
          hasActivePastPapers: true,
          iconName: 'school',
          colorHex: '#6366F1',
        );

        const feed = DashboardFeedEntity(
          calibrationProfile: calibration,
          analyticsSummary: AnalyticsSummaryEntity(
            currentStreakDays: 1,
            longestStreakDays: 1,
            weeklyMinutesStudied: 10,
            overallRetentionRate: 0.8,
            totalCardsMastered: 5,
            heatMapData: [],
            xpPoints: 50,
            academicRank: 'Novice',
          ),
          dueStudyDecks: [],
          curatedCourses: [dummyCourse],
        );

        expect(feed.hasTrackSelected, isTrue);
        expect(feed.curatedCourses.isNotEmpty, isTrue);
        expect(feed.isProfileUncalibrated, isFalse);
      },
    );

    test(
      'isProfileUncalibrated is true when track is selected BUT no courses enrolled and isCalibrated is false',
      () {
        const calibration = CalibrationProfile(
          highSchoolExam: 'JAMB / UTME',
        );

        const feed = DashboardFeedEntity(
          calibrationProfile: calibration,
          analyticsSummary: AnalyticsSummaryEntity(
            currentStreakDays: 0,
            longestStreakDays: 0,
            weeklyMinutesStudied: 0,
            overallRetentionRate: 0,
            totalCardsMastered: 0,
            heatMapData: [],
            xpPoints: 0,
            academicRank: 'Novice',
          ),
          dueStudyDecks: [],
          curatedCourses: [],
        );

        expect(feed.hasTrackSelected, isTrue);
        expect(feed.curatedCourses.isEmpty, isTrue);
        expect(feed.isProfileUncalibrated, isTrue);
      },
    );
  });
}
