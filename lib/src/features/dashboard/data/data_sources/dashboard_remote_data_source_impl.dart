import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/data/models/study_deck_model.dart';

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  const DashboardRemoteDataSourceImpl(
    this._client, {
    UserActivityService? userActivityService,
  }) : _userActivityService = userActivityService;

  final DashboardApiClient _client;
  final UserActivityService? _userActivityService;

  @override
  Future<DashboardFeedModel> getDashboardFeed() async {
    final liveAnalytics = _userActivityService?.getAnalyticsSummary();
    try {
      final feed = await _client.getDashboardFeed(const {});
      if (liveAnalytics != null &&
          (liveAnalytics.currentStreakDays > 0 ||
              liveAnalytics.totalCardsMastered > 0 ||
              liveAnalytics.weeklyMinutesStudied > 0 ||
              liveAnalytics.overallRetentionRate > 0 ||
              liveAnalytics.xpPoints > 0)) {
        return feed.copyWith(analyticsSummary: liveAnalytics);
      }
      return feed;
    } on Object catch (_) {
      return _generateFallbackFeedModel(liveAnalytics);
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
  Future<List<CuratedCourseModel>> getCatalogCourses() async {
    try {
      final courses = await _client.getCuratedCoursesCatalog();
      if (courses.isNotEmpty) return courses;
      return _generateDefaultCatalogCourses();
    } on Object catch (_) {
      return _generateDefaultCatalogCourses();
    }
  }

  @override
  Future<void> syncUserCourses(List<Map<String, dynamic>> courses) async {
    try {
      await _client.syncUserCourses({
        'p_courses': courses,
      });
    } on Object catch (_) {}
  }

  @override
  Future<void> autoCurateExamCourses({
    required String examName,
    required List<String> subjects,
  }) async {
    try {
      await _client.autoCurateExamCourses({
        'p_exam_name': examName,
        'p_subjects': subjects,
      });
    } on Object catch (_) {}
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

  DashboardFeedModel _generateFallbackFeedModel(
    AnalyticsSummaryModel? liveAnalytics,
  ) {
    final analytics =
        liveAnalytics ??
        _userActivityService?.getAnalyticsSummary() ??
        AnalyticsSummaryModel(
          currentStreakDays: 0,
          longestStreakDays: 0,
          weeklyMinutesStudied: 0,
          overallRetentionRate: 0,
          totalCardsMastered: 0,
          heatMapData: _generateEmptyHeatMap(),
          xpPoints: 0,
          academicRank: 'Neural Scholar I',
        );

    final streak = analytics.currentStreakDays;
    final insight = streak > 0
        ? 'Great momentum! You are on a $streak-day study streak. Keep up the active recall!'
        : 'Welcome to Kortexify! Start your first study session to activate your neural memory retention tracking.';

    return DashboardFeedModel(
      analyticsSummary: analytics,
      dueStudyDecks: const [],
      curatedCourses: const [],
      syllabotDailyInsight: insight,
    );
  }

  List<HeatMapDayModel> _generateEmptyHeatMap() {
    final now = DateTime.now();
    return List.generate(28, (i) {
      final day = now.subtract(Duration(days: 27 - i));
      return HeatMapDayModel(
        dateIso: day.toIso8601String(),
        intensityLevel: 0,
        cardsReviewed: 0,
        minutesStudied: 0,
      );
    });
  }

  List<StudyDeckModel> _generateFallbackDecks() {
    return const [];
  }

  List<CuratedCourseModel> _generateDefaultCatalogCourses() {
    return const [
      // Social Sciences & Humanities
      CuratedCourseModel(
        id: '00000000-0000-0000-0001-000000000001',
        courseCode: 'ENG 101',
        title: 'Academic Writing, Rhetoric & Critical Analysis',
        department: 'English & Literary Studies',
        totalMaterials: 14,
        hasActivePastPapers: true,
        iconName: 'menu_book',
        colorHex: '#F59E0B',
        syllabusCoverage: 0.80,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0002-000000000001',
        courseCode: 'ECN 101',
        title: 'Principles of Microeconomics & Market Dynamics',
        department: 'Economics',
        totalMaterials: 22,
        hasActivePastPapers: true,
        iconName: 'trending_up',
        colorHex: '#10B981',
        syllabusCoverage: 0.85,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0002-000000000002',
        courseCode: 'SOC 101',
        title: 'Introduction to Social Structure & Human Behavior',
        department: 'Sociology',
        totalMaterials: 15,
        hasActivePastPapers: false,
        iconName: 'groups',
        colorHex: '#059669',
        syllabusCoverage: 0.72,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0002-000000000003',
        courseCode: 'POL 201',
        title: 'Comparative Government & Political Institutions',
        department: 'Political Science',
        totalMaterials: 18,
        hasActivePastPapers: true,
        iconName: 'account_balance',
        colorHex: '#047857',
      ),

      // Law & Legal Studies
      CuratedCourseModel(
        id: '00000000-0000-0000-0003-000000000001',
        courseCode: 'LAW 101',
        title: 'Nigerian & Common Legal Systems, Precedence & Method',
        department: 'Faculty of Law',
        totalMaterials: 28,
        hasActivePastPapers: true,
        iconName: 'gavel',
        colorHex: '#8B5CF6',
        syllabusCoverage: 0.82,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0003-000000000002',
        courseCode: 'LAW 201',
        title: 'Law of Contract & Commercial Obligations',
        department: 'Faculty of Law',
        totalMaterials: 25,
        hasActivePastPapers: true,
        iconName: 'policy',
        colorHex: '#7C3AED',
        syllabusCoverage: 0.88,
      ),

      // Business & Accounting
      CuratedCourseModel(
        id: '00000000-0000-0000-0004-000000000001',
        courseCode: 'ACC 101',
        title: 'Financial Accounting Principles & Balance Sheets',
        department: 'Accounting',
        totalMaterials: 26,
        hasActivePastPapers: true,
        iconName: 'receipt_long',
        colorHex: '#3B82F6',
        syllabusCoverage: 0.80,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0004-000000000002',
        courseCode: 'MGT 201',
        title: 'Organizational Behavior & Strategic Leadership',
        department: 'Business Administration',
        totalMaterials: 19,
        hasActivePastPapers: false,
        iconName: 'corporate_fare',
        colorHex: '#2563EB',
        syllabusCoverage: 0.74,
      ),

      // Medicine & Health
      CuratedCourseModel(
        id: '00000000-0000-0000-0005-000000000001',
        courseCode: 'ANAT 201',
        title: 'Gross Human Anatomy: Thorax, Abdomen & Musculoskeletal',
        department: 'Medicine & Surgery',
        totalMaterials: 34,
        hasActivePastPapers: true,
        iconName: 'accessibility_new',
        colorHex: '#EC4899',
        syllabusCoverage: 0.90,
      ),

      // STEM & Computing
      CuratedCourseModel(
        id: '00000000-0000-0000-0000-000000000004',
        courseCode: 'CS 201',
        title: 'Data Structures, Graph Algorithms & Asymptotic Complexity',
        department: 'Computer Science & Software Engineering',
        totalMaterials: 40,
        hasActivePastPapers: true,
        iconName: 'code',
        colorHex: '#8B5CF6',
        syllabusCoverage: 0.88,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0000-000000000001',
        courseCode: 'MTH 301',
        title: 'Advanced Engineering Mathematics & Laplace Calculus',
        department: 'Electrical & Electronic Engineering',
        totalMaterials: 24,
        hasActivePastPapers: true,
        iconName: 'calculate',
        colorHex: '#6366F1',
        syllabusCoverage: 0.85,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0000-000000000002',
        courseCode: 'PHY 202',
        title: 'Electromagnetism & Maxwell Equations',
        department: 'Physics & Applied Sciences',
        totalMaterials: 18,
        hasActivePastPapers: true,
        iconName: 'bolt',
        colorHex: '#06B6D4',
        syllabusCoverage: 0.78,
      ),

      // Standardized Exam Prep (WAEC / JAMB / SAT)
      CuratedCourseModel(
        id: '00000000-0000-0000-0006-000000000001',
        courseCode: 'W-MATH',
        title: 'WAEC/JAMB General Mathematics: Algebra & Geometry',
        department: 'Secondary School Board',
        totalMaterials: 42,
        hasActivePastPapers: true,
        iconName: 'calculate',
        colorHex: '#6366F1',
        syllabusCoverage: 0.95,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0006-000000000002',
        courseCode: 'W-ENG',
        title: 'WAEC/JAMB English Language: Lexis & Structure',
        department: 'Secondary School Board',
        totalMaterials: 38,
        hasActivePastPapers: true,
        iconName: 'auto_stories',
        colorHex: '#F59E0B',
        syllabusCoverage: 0.92,
      ),
      CuratedCourseModel(
        id: '00000000-0000-0000-0006-000000000006',
        courseCode: 'W-GOV',
        title: 'WAEC/JAMB Government: Constitutional Development',
        department: 'Secondary School Board',
        totalMaterials: 28,
        hasActivePastPapers: true,
        iconName: 'account_balance',
        colorHex: '#8B5CF6',
        syllabusCoverage: 0.85,
      ),
    ];
  }
}
