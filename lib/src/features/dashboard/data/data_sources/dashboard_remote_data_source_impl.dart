import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/data/models/study_deck_model.dart';

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  DashboardRemoteDataSourceImpl(
    this._client, {
    UserActivityService? userActivityService,
    LocalStorageService? storageService,
  })  : _userActivityService = userActivityService,
        _storageService = storageService;

  final DashboardApiClient _client;
  final UserActivityService? _userActivityService;
  final LocalStorageService? _storageService;

  LocalStorageService? get _storage {
    if (_storageService != null) return _storageService;
    try {
      return locator<LocalStorageService>();
    } on Object catch (_) {
      return null;
    }
  }

  List<CuratedCourseModel> _getLocallySavedCourses() {
    try {
      final raw = _storage?.getPreference(key: PrefKeys.userCuratedCourses);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) => CuratedCourseModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on Object catch (_) {}
    return const [];
  }

  List<StudyDeckModel> _getLocallySavedDecks() {
    try {
      final raw = _storage?.getPreference(key: PrefKeys.persistedUserDecks);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) {
          final m = e as Map<String, dynamic>;
          return StudyDeckModel(
            id: (m['id'] as String?) ?? 'deck',
            title: (m['title'] as String?) ?? 'Study Deck',
            subject: (m['subject'] as String?) ?? 'General Studies',
            totalCards: (m['totalCards'] as int?) ?? 10,
            dueCards: (m['dueCards'] as int?) ?? 5,
            retentionRate: (m['masteryRate'] as num?)?.toDouble() ?? 0.8,
            lastReviewedIso: DateTime.now().toIso8601String(),
            category: (m['category'] as String?) ?? 'General',
            colorHex: m['colorHex'] as String?,
          );
        }).toList();
      }
    } on Object catch (_) {}
    return const [];
  }

  @override
  Future<DashboardFeedModel> getDashboardFeed() async {
    final liveAnalytics = _userActivityService?.getAnalyticsSummary();
    final localCourses = _getLocallySavedCourses();
    final localDecks = _getLocallySavedDecks();

    try {
      var feed = await _client.getDashboardFeed(const {});
      if (feed.curatedCourses.isEmpty && localCourses.isNotEmpty) {
        feed = feed.copyWith(curatedCourses: localCourses);
      }
      if (feed.dueStudyDecks.isEmpty && localDecks.isNotEmpty) {
        feed = feed.copyWith(dueStudyDecks: localDecks);
      }
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
      final decks = await _client.getReviewQueue();
      if (decks.isNotEmpty) return decks;
      return _getLocallySavedDecks();
    } on Object catch (_) {
      return _getLocallySavedDecks();
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
    // 1. Instantly persist to Hive local storage for resilient offline/restart capability
    try {
      final catalog = _generateDefaultCatalogCourses();
      final catalogMap = {for (final c in catalog) c.id: c};

      final models = courses.map((m) {
        final id = (m['id'] as String?) ?? 'course_${DateTime.now().microsecondsSinceEpoch}';
        final catalogMatch = catalogMap[id];

        return CuratedCourseModel(
          id: id,
          courseCode: (m['courseCode'] as String?) ?? catalogMatch?.courseCode ?? 'CRS',
          title: (m['title'] as String?) ?? catalogMatch?.title ?? '',
          department: (m['department'] as String?) ?? catalogMatch?.department ?? 'General Studies',
          totalMaterials: catalogMatch?.totalMaterials ?? 15,
          hasActivePastPapers: catalogMatch?.hasActivePastPapers ?? true,
          iconName: catalogMatch?.iconName ?? 'school',
          colorHex: catalogMatch?.colorHex ?? '#6366F1',
          syllabusCoverage: catalogMatch?.syllabusCoverage ?? 0.70,
        );
      }).toList();

      final jsonStr = jsonEncode(models.map((c) => c.toJson()).toList());
      await _storage?.savePreference(
        key: PrefKeys.userCuratedCourses,
        data: jsonStr,
      );
    } on Object catch (_) {}

    // 2. Sync to Supabase RPC
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
        : 'Welcome to Kortex! Select your curriculum courses or start a study session to activate neural retention tracking.';

    return DashboardFeedModel(
      analyticsSummary: analytics,
      dueStudyDecks: _getLocallySavedDecks(),
      curatedCourses: _getLocallySavedCourses(),
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

  List<CuratedCourseModel> _generateDefaultCatalogCourses() {
    return const [
      // ═══════════════════════════════════════════════════════════════════════
      // 1. WAEC / WASSCE Core & Track Subjects
      // ═══════════════════════════════════════════════════════════════════════
      CuratedCourseModel(
        id: 'waec-math-core',
        courseCode: 'W-MATH',
        title: 'General Mathematics (Core)',
        department: 'WAEC - Core',
        totalMaterials: 48,
        hasActivePastPapers: true,
        iconName: 'calculate',
        colorHex: '#6366F1',
        syllabusCoverage: 0.95,
      ),
      CuratedCourseModel(
        id: 'waec-eng-lang',
        courseCode: 'W-ENG',
        title: 'English Language & Oral English',
        department: 'WAEC - Core',
        totalMaterials: 52,
        hasActivePastPapers: true,
        iconName: 'auto_stories',
        colorHex: '#F59E0B',
        syllabusCoverage: 0.92,
      ),
      CuratedCourseModel(
        id: 'waec-civic-edu',
        courseCode: 'W-CIV',
        title: 'Civic Education & Governance',
        department: 'WAEC - Core',
        totalMaterials: 26,
        hasActivePastPapers: true,
        iconName: 'policy',
        colorHex: '#10B981',
        syllabusCoverage: 0.88,
      ),
      CuratedCourseModel(
        id: 'waec-physics',
        courseCode: 'W-PHY',
        title: 'Physics: Mechanics, Waves & Electricity',
        department: 'WAEC - Sciences',
        totalMaterials: 44,
        hasActivePastPapers: true,
        iconName: 'bolt',
        colorHex: '#06B6D4',
        syllabusCoverage: 0.90,
      ),
      CuratedCourseModel(
        id: 'waec-chemistry',
        courseCode: 'W-CHM',
        title: 'Chemistry: Organic, Physical & Qualitative Analysis',
        department: 'WAEC - Sciences',
        totalMaterials: 40,
        hasActivePastPapers: true,
        iconName: 'biotech',
        colorHex: '#EC4899',
        syllabusCoverage: 0.89,
      ),
      CuratedCourseModel(
        id: 'waec-biology',
        courseCode: 'W-BIO',
        title: 'Biology: Physiology, Genetics & Ecology',
        department: 'WAEC - Sciences',
        totalMaterials: 46,
        hasActivePastPapers: true,
        iconName: 'eco',
        colorHex: '#10B981',
        syllabusCoverage: 0.91,
      ),
      CuratedCourseModel(
        id: 'waec-further-math',
        courseCode: 'W-FMTH',
        title: 'Further Mathematics & Vectors',
        department: 'WAEC - Sciences',
        totalMaterials: 35,
        hasActivePastPapers: true,
        iconName: 'functions',
        colorHex: '#4F46E5',
        syllabusCoverage: 0.85,
      ),
      CuratedCourseModel(
        id: 'waec-agric-sci',
        courseCode: 'W-AGR',
        title: 'Agricultural Science & Crop Production',
        department: 'WAEC - Sciences',
        totalMaterials: 29,
        hasActivePastPapers: true,
        iconName: 'agriculture',
        colorHex: '#84CC16',
        syllabusCoverage: 0.86,
      ),
      CuratedCourseModel(
        id: 'waec-economics',
        courseCode: 'W-ECN',
        title: 'Economics: Micro, Macro & Trade',
        department: 'WAEC - Commercial',
        totalMaterials: 38,
        hasActivePastPapers: true,
        iconName: 'trending_up',
        colorHex: '#3B82F6',
        syllabusCoverage: 0.87,
      ),
      CuratedCourseModel(
        id: 'waec-fin-acc',
        courseCode: 'W-ACC',
        title: 'Financial Accounting & Balance Sheets',
        department: 'WAEC - Commercial',
        totalMaterials: 34,
        hasActivePastPapers: true,
        iconName: 'receipt_long',
        colorHex: '#2563EB',
        syllabusCoverage: 0.84,
      ),
      CuratedCourseModel(
        id: 'waec-commerce',
        courseCode: 'W-COM',
        title: 'Commerce, Banking & Insurance',
        department: 'WAEC - Commercial',
        totalMaterials: 30,
        hasActivePastPapers: true,
        iconName: 'storefront',
        colorHex: '#0284C7',
        syllabusCoverage: 0.82,
      ),
      CuratedCourseModel(
        id: 'waec-literature',
        courseCode: 'W-LIT',
        title: 'Literature in English: African & Non-African',
        department: 'WAEC - Arts',
        totalMaterials: 36,
        hasActivePastPapers: true,
        iconName: 'menu_book',
        colorHex: '#D97706',
        syllabusCoverage: 0.89,
      ),
      CuratedCourseModel(
        id: 'waec-government',
        courseCode: 'W-GOV',
        title: 'Government: Constitutions & Political Systems',
        department: 'WAEC - Arts',
        totalMaterials: 32,
        hasActivePastPapers: true,
        iconName: 'account_balance',
        colorHex: '#8B5CF6',
        syllabusCoverage: 0.86,
      ),
      CuratedCourseModel(
        id: 'waec-geography',
        courseCode: 'W-GEO',
        title: 'Geography: Physical, Regional & Map Work',
        department: 'WAEC - Arts',
        totalMaterials: 28,
        hasActivePastPapers: true,
        iconName: 'public',
        colorHex: '#0D9488',
        syllabusCoverage: 0.80,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // 2. JAMB / UTME CBT Examination Tracks
      // ═══════════════════════════════════════════════════════════════════════
      CuratedCourseModel(
        id: 'jamb-use-of-eng',
        courseCode: 'J-ENG',
        title: 'JAMB: Use of English & Comprehension Drills',
        department: 'JAMB - Core',
        totalMaterials: 60,
        hasActivePastPapers: true,
        iconName: 'record_voice_over',
        colorHex: '#F59E0B',
        syllabusCoverage: 0.98,
      ),
      CuratedCourseModel(
        id: 'jamb-cbt-math',
        courseCode: 'J-MTH',
        title: 'JAMB: Mathematics CBT Speed & Accuracy',
        department: 'JAMB - Sciences',
        totalMaterials: 50,
        hasActivePastPapers: true,
        iconName: 'calculate',
        colorHex: '#6366F1',
        syllabusCoverage: 0.94,
      ),
      CuratedCourseModel(
        id: 'jamb-cbt-phy',
        courseCode: 'J-PHY',
        title: 'JAMB: Physics CBT Drills & Formula Mastery',
        department: 'JAMB - Sciences',
        totalMaterials: 45,
        hasActivePastPapers: true,
        iconName: 'bolt',
        colorHex: '#06B6D4',
        syllabusCoverage: 0.92,
      ),
      CuratedCourseModel(
        id: 'jamb-cbt-chm',
        courseCode: 'J-CHM',
        title: 'JAMB: Chemistry CBT Drills & Equations',
        department: 'JAMB - Sciences',
        totalMaterials: 42,
        hasActivePastPapers: true,
        iconName: 'biotech',
        colorHex: '#EC4899',
        syllabusCoverage: 0.90,
      ),
      CuratedCourseModel(
        id: 'jamb-cbt-bio',
        courseCode: 'J-BIO',
        title: 'JAMB: Biology CBT Drills & Diagrammatic Questions',
        department: 'JAMB - Sciences',
        totalMaterials: 45,
        hasActivePastPapers: true,
        iconName: 'eco',
        colorHex: '#10B981',
        syllabusCoverage: 0.91,
      ),
      CuratedCourseModel(
        id: 'jamb-cbt-ecn',
        courseCode: 'J-ECN',
        title: 'JAMB: Economics CBT Drills & Calculations',
        department: 'JAMB - Commercial',
        totalMaterials: 35,
        hasActivePastPapers: true,
        iconName: 'trending_up',
        colorHex: '#3B82F6',
        syllabusCoverage: 0.88,
      ),
      CuratedCourseModel(
        id: 'jamb-cbt-gov',
        courseCode: 'J-GOV',
        title: 'JAMB: Government CBT Objective Questions',
        department: 'JAMB - Arts',
        totalMaterials: 34,
        hasActivePastPapers: true,
        iconName: 'account_balance',
        colorHex: '#8B5CF6',
        syllabusCoverage: 0.89,
      ),
      CuratedCourseModel(
        id: 'jamb-cbt-lit',
        courseCode: 'J-LIT',
        title: 'JAMB: Literature in English Prescribed Texts',
        department: 'JAMB - Arts',
        totalMaterials: 30,
        hasActivePastPapers: true,
        iconName: 'menu_book',
        colorHex: '#D97706',
        syllabusCoverage: 0.85,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // 3. SAT Standardized Prep
      // ═══════════════════════════════════════════════════════════════════════
      CuratedCourseModel(
        id: 'sat-math-algebra',
        courseCode: 'SAT-MTH',
        title: 'SAT: Digital Math - Algebra & Advanced Math',
        department: 'SAT Prep',
        totalMaterials: 35,
        hasActivePastPapers: true,
        iconName: 'calculate',
        colorHex: '#6366F1',
        syllabusCoverage: 0.90,
      ),
      CuratedCourseModel(
        id: 'sat-reading-writing',
        courseCode: 'SAT-RW',
        title: 'SAT: Reading & Writing - Information & Ideas',
        department: 'SAT Prep',
        totalMaterials: 38,
        hasActivePastPapers: true,
        iconName: 'auto_stories',
        colorHex: '#F59E0B',
        syllabusCoverage: 0.92,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // 4. University & Higher Education Disciplines
      // ═══════════════════════════════════════════════════════════════════════
      CuratedCourseModel(
        id: 'csc-201-data-structures',
        courseCode: 'CSC 201',
        title: 'Data Structures, Graph Algorithms & Asymptotic Complexity',
        department: 'Computer Science',
        totalMaterials: 40,
        hasActivePastPapers: true,
        iconName: 'terminal',
        colorHex: '#8B5CF6',
        syllabusCoverage: 0.88,
      ),
      CuratedCourseModel(
        id: 'csc-101-intro-computing',
        courseCode: 'CSC 101',
        title: 'Introduction to Computer Systems & Discrete Structures',
        department: 'Computer Science',
        totalMaterials: 32,
        hasActivePastPapers: true,
        iconName: 'laptop',
        colorHex: '#6366F1',
        syllabusCoverage: 0.85,
      ),
      CuratedCourseModel(
        id: 'med-anat-201',
        courseCode: 'ANAT 201',
        title: 'Gross Human Anatomy: Thorax, Abdomen & Musculoskeletal',
        department: 'Medicine & Health',
        totalMaterials: 36,
        hasActivePastPapers: true,
        iconName: 'medical_services',
        colorHex: '#EC4899',
        syllabusCoverage: 0.90,
      ),
      CuratedCourseModel(
        id: 'med-phs-201',
        courseCode: 'PHS 201',
        title: 'Medical Physiology: Cardiovascular & Renal Systems',
        department: 'Medicine & Health',
        totalMaterials: 30,
        hasActivePastPapers: true,
        iconName: 'favorite',
        colorHex: '#EF4444',
        syllabusCoverage: 0.87,
      ),
      CuratedCourseModel(
        id: 'law-101-nigerian-legal',
        courseCode: 'LAW 101',
        title: 'Legal Systems, Precedence, Statutes & Methods',
        department: 'Law & Legal Studies',
        totalMaterials: 28,
        hasActivePastPapers: true,
        iconName: 'gavel',
        colorHex: '#7C3AED',
        syllabusCoverage: 0.82,
      ),
      CuratedCourseModel(
        id: 'law-201-contract-law',
        courseCode: 'LAW 201',
        title: 'Law of Contract & Commercial Obligations',
        department: 'Law & Legal Studies',
        totalMaterials: 25,
        hasActivePastPapers: true,
        iconName: 'policy',
        colorHex: '#8B5CF6',
        syllabusCoverage: 0.88,
      ),
      CuratedCourseModel(
        id: 'eng-mth-301',
        courseCode: 'MTH 301',
        title: 'Engineering Mathematics: Differential Equations & Laplace',
        department: 'Engineering',
        totalMaterials: 24,
        hasActivePastPapers: true,
        iconName: 'engineering',
        colorHex: '#0EA5E9',
        syllabusCoverage: 0.85,
      ),
      CuratedCourseModel(
        id: 'eng-eee-201',
        courseCode: 'EEE 201',
        title: 'Circuit Theory & Linear Electrical Networks',
        department: 'Engineering',
        totalMaterials: 22,
        hasActivePastPapers: true,
        iconName: 'settings_input_component',
        colorHex: '#06B6D4',
        syllabusCoverage: 0.83,
      ),
      CuratedCourseModel(
        id: 'bus-acc-101',
        courseCode: 'ACC 101',
        title: 'Financial Accounting Principles & Balance Sheets',
        department: 'Business & Management',
        totalMaterials: 26,
        hasActivePastPapers: true,
        iconName: 'receipt_long',
        colorHex: '#3B82F6',
        syllabusCoverage: 0.80,
      ),
      CuratedCourseModel(
        id: 'bus-mgt-201',
        courseCode: 'MGT 201',
        title: 'Organizational Behavior & Strategic Leadership',
        department: 'Business & Management',
        totalMaterials: 19,
        hasActivePastPapers: false,
        iconName: 'corporate_fare',
        colorHex: '#2563EB',
        syllabusCoverage: 0.74,
      ),
      CuratedCourseModel(
        id: 'soc-soc-101',
        courseCode: 'SOC 101',
        title: 'Introduction to Social Structure & Human Behavior',
        department: 'Social Sciences',
        totalMaterials: 15,
        hasActivePastPapers: false,
        iconName: 'groups',
        colorHex: '#059669',
        syllabusCoverage: 0.72,
      ),
    ];
  }
}
