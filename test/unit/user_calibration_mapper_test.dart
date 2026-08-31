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
  });
}
