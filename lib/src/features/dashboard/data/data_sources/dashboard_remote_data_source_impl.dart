import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/data/models/exam_countdown_model.dart';
import 'package:kortex/src/features/dashboard/data/models/study_deck_model.dart';

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  const DashboardRemoteDataSourceImpl(this._client);

  final DashboardApiClient _client;

  @override
  Future<DashboardFeedModel> getDashboardFeed() async {
    try {
      return await _client.getDashboardFeed();
    } on Object catch (_) {
      // Return robust fallback demo data for smooth development / offline presentation
      return _generateFallbackFeedModel();
    }
  }

  @override
  Future<List<StudyDeckModel>> getReviewQueue() async {
    try {
      return await _client.getReviewQueue();
    } on Object catch (_) {
      return _generateFallbackDecks();
    }
  }

  @override
  Future<String> startMockExam({
    required String examId,
    required String subject,
  }) async {
    try {
      final res = await _client.startMockExam({
        'examId': examId,
        'subject': subject,
      });
      final data = res.data;
      if (data is Map<String, dynamic> && data['sessionId'] != null) {
        return data['sessionId'].toString();
      }
      return 'mock_session_${DateTime.now().millisecondsSinceEpoch}';
    } on Object catch (_) {
      return 'mock_session_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  DashboardFeedModel _generateFallbackFeedModel() {
    final now = DateTime.now();
    final heatMap = List.generate(28, (i) {
      final day = now.subtract(Duration(days: 27 - i));
      final intensity = (i % 5 == 0)
          ? 4
          : (i % 3 == 0)
          ? 3
          : (i.isEven)
          ? 2
          : 1;
      return HeatMapDayModel(
        dateIso: day.toIso8601String(),
        intensityLevel: intensity,
        cardsReviewed: 12 + (i * 3),
        minutesStudied: 20 + (i * 5),
      );
    });

    return DashboardFeedModel(
      analyticsSummary: AnalyticsSummaryModel(
        currentStreakDays: 14,
        longestStreakDays: 28,
        weeklyMinutesStudied: 380,
        overallRetentionRate: 0.91,
        totalCardsMastered: 486,
        heatMapData: heatMap,
        xpPoints: 3450,
        academicRank: 'Neural Scholar IV',
      ),
      dueStudyDecks: _generateFallbackDecks(),
      curatedCourses: const [
        CuratedCourseModel(
          id: 'course_1',
          courseCode: 'MTH 301',
          title: 'Advanced Mathematical Methods & PDEs',
          department: 'Engineering / Mathematics',
          totalMaterials: 24,
          hasActivePastPapers: true,
          iconName: 'calculate_rounded',
          colorHex: '#3B82F6',
          syllabusCoverage: 0.85,
        ),
        CuratedCourseModel(
          id: 'course_2',
          courseCode: 'PHY 202',
          title: 'Electromagnetism & Wave Mechanics',
          department: 'Physical Sciences',
          totalMaterials: 18,
          hasActivePastPapers: true,
          iconName: 'bolt_rounded',
          colorHex: '#8B5CF6',
          syllabusCoverage: 0.70,
        ),
        CuratedCourseModel(
          id: 'course_3',
          courseCode: 'CSC 310',
          title: 'Data Structures, Algorithms & Automata',
          department: 'Computer Science',
          totalMaterials: 32,
          hasActivePastPapers: true,
          iconName: 'memory_rounded',
          colorHex: '#10B981',
          syllabusCoverage: 0.92,
        ),
        CuratedCourseModel(
          id: 'course_4',
          courseCode: 'CHM 201',
          title: 'Organic Reaction Mechanisms & Spectroscopy',
          department: 'Chemical Sciences',
          totalMaterials: 15,
          hasActivePastPapers: true,
          iconName: 'science_rounded',
          colorHex: '#F59E0B',
          syllabusCoverage: 0.65,
        ),
      ],
      targetExamCountdown: ExamCountdownModel(
        id: 'exam_jamb_2026',
        examName: 'Unified Tertiary Matriculation Exam (JAMB CBT)',
        targetDateIso: now.add(const Duration(days: 42)).toIso8601String(),
        syllabusProgress: 0.78,
        subjectTrack: 'Use of English, Mathematics, Physics, Chemistry',
        totalMockPapersAvailable: 40,
        completedMocksCount: 18,
        badgeTitle: 'HIGH YIELD PREP',
      ),
      unreadNotificationCount: 3,
      syllabotDailyInsight: 'Your active recall retention in Differential '
          'Equations is up 14% this week. '
          'Focus on Fourier series before Friday!',
    );
  }

  List<StudyDeckModel> _generateFallbackDecks() {
    final now = DateTime.now();
    return [
      StudyDeckModel(
        id: 'deck_1',
        title: 'Laplace & Fourier Transforms Quick Review',
        subject: 'MTH 301',
        totalCards: 45,
        dueCards: 18,
        retentionRate: 0.88,
        lastReviewedIso: now
            .subtract(const Duration(hours: 18))
            .toIso8601String(),
        category: 'STEM Active Recall',
        estimatedMinutes: 12,
        colorHex: '#3B82F6',
      ),
      StudyDeckModel(
        id: 'deck_2',
        title: "Maxwell's Equations & Vector Fields",
        subject: 'PHY 202',
        totalCards: 32,
        dueCards: 12,
        retentionRate: 0.94,
        lastReviewedIso: now
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        category: 'Spaced Repetition',
        estimatedMinutes: 8,
        colorHex: '#8B5CF6',
      ),
      StudyDeckModel(
        id: 'deck_3',
        title: 'Dynamic Programming & Graph Algorithms',
        subject: 'CSC 310',
        totalCards: 50,
        dueCards: 22,
        retentionRate: 0.82,
        lastReviewedIso: now
            .subtract(const Duration(days: 2))
            .toIso8601String(),
        category: 'Core Computer Science',
        estimatedMinutes: 15,
        colorHex: '#10B981',
      ),
      StudyDeckModel(
        id: 'deck_4',
        title: 'High-Yield Past Questions (2018-2024)',
        subject: 'WAEC / JAMB Physics',
        totalCards: 60,
        dueCards: 30,
        retentionRate: 0.79,
        lastReviewedIso: now
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        category: 'Exam Simulator',
        estimatedMinutes: 20,
        colorHex: '#EC4899',
      ),
    ];
  }
}
