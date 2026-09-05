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
            dueCards: (m['dueCards'] as int?) ?? 0,
            retentionRate: (m['masteryRate'] as num?)?.toDouble() ?? 0.8,
            lastReviewedIso: DateTime.now().toIso8601String(),
            category: (m['category'] as String?) ?? 'General',
            colorHex: m['colorHex'] as String?,
          );
        }).where((d) => d.dueCards > 0).toList();
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
      if (feed.dueStudyDecks.isNotEmpty) {
        feed = feed.copyWith(
          dueStudyDecks: feed.dueStudyDecks.where((d) => d.dueCards > 0).toList(),
        );
      } else if (localDecks.isNotEmpty) {
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
  Future<void> deleteCuratedCourse(String courseId) async {
    try {
      final current = _getLocallySavedCourses();
      final updated = current.where((c) => c.id != courseId).toList();
      final jsonStr = jsonEncode(updated.map((c) => c.toJson()).toList());
      await _storage?.savePreference(
        key: PrefKeys.userCuratedCourses,
        data: jsonStr,
      );
      await _client.syncUserCourses({
        'p_courses': updated.map((c) => c.toJson()).toList(),
      });
    } on Object catch (_) {}
  }

  @override
  Future<void> deleteAllCuratedCourses() async {
    try {
      await _storage?.deletePreference(key: PrefKeys.userCuratedCourses);
      await _client.syncUserCourses({
        'p_courses': <Map<String, dynamic>>[],
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
    const curatedSubjects = [
      // Core
      (code: 'MTH', title: 'Mathematics', stream: 'Core', icon: 'calculate', color: '#6366F1', materials: 48, coverage: 0.95),
      (code: 'ENG', title: 'English Language', stream: 'Core', icon: 'auto_stories', color: '#F59E0B', materials: 52, coverage: 0.92),
      (code: 'CIV', title: 'Civic Education', stream: 'Core', icon: 'policy', color: '#10B981', materials: 26, coverage: 0.88),
      (code: 'DPR', title: 'Data Processing', stream: 'Core', icon: 'terminal', color: '#8B5CF6', materials: 28, coverage: 0.85),
      (code: 'CMP', title: 'Computer Studies', stream: 'Core', icon: 'laptop', color: '#06B6D4', materials: 30, coverage: 0.87),

      // Sciences
      (code: 'PHY', title: 'Physics', stream: 'Sciences', icon: 'bolt', color: '#06B6D4', materials: 44, coverage: 0.90),
      (code: 'CHM', title: 'Chemistry', stream: 'Sciences', icon: 'biotech', color: '#EC4899', materials: 40, coverage: 0.89),
      (code: 'BIO', title: 'Biology', stream: 'Sciences', icon: 'eco', color: '#10B981', materials: 46, coverage: 0.91),
      (code: 'FMTH', title: 'Further Mathematics', stream: 'Sciences', icon: 'functions', color: '#4F46E5', materials: 35, coverage: 0.85),
      (code: 'AGR', title: 'Agricultural Science', stream: 'Sciences', icon: 'agriculture', color: '#84CC16', materials: 29, coverage: 0.86),
      (code: 'TD', title: 'Technical Drawing', stream: 'Sciences', icon: 'architecture', color: '#F97316', materials: 24, coverage: 0.82),
      (code: 'ANH', title: 'Animal Husbandry', stream: 'Sciences', icon: 'pets', color: '#A855F7', materials: 25, coverage: 0.84),
      (code: 'PHE', title: 'Physical Education', stream: 'Sciences', icon: 'fitness_center', color: '#14B8A6', materials: 22, coverage: 0.80),

      // Commercial
      (code: 'ECN', title: 'Economics', stream: 'Commercial', icon: 'trending_up', color: '#3B82F6', materials: 38, coverage: 0.87),
      (code: 'COM', title: 'Commerce', stream: 'Commercial', icon: 'storefront', color: '#0284C7', materials: 30, coverage: 0.82),
      (code: 'ACC', title: 'Accounts - Principles of Accounts', stream: 'Commercial', icon: 'receipt_long', color: '#2563EB', materials: 34, coverage: 0.84),
      (code: 'BKP', title: 'Book Keeping', stream: 'Commercial', icon: 'menu_book', color: '#0D9488', materials: 26, coverage: 0.81),
      (code: 'MKT', title: 'Marketing', stream: 'Commercial', icon: 'campaign', color: '#E11D48', materials: 27, coverage: 0.83),
      (code: 'INS', title: 'Insurance', stream: 'Commercial', icon: 'shield', color: '#6D28D9', materials: 24, coverage: 0.80),
      (code: 'OFP', title: 'Office Practice', stream: 'Commercial', icon: 'business_center', color: '#475569', materials: 22, coverage: 0.79),

      // Arts & Humanities
      (code: 'LIT', title: 'Literature in English', stream: 'Arts', icon: 'menu_book', color: '#D97706', materials: 36, coverage: 0.89),
      (code: 'GOV', title: 'Government', stream: 'Arts', icon: 'account_balance', color: '#8B5CF6', materials: 32, coverage: 0.86),
      (code: 'GEO', title: 'Geography', stream: 'Arts', icon: 'public', color: '#0D9488', materials: 28, coverage: 0.80),
      (code: 'HIS', title: 'History', stream: 'Arts', icon: 'history_edu', color: '#78350F', materials: 25, coverage: 0.82),
      (code: 'CRK', title: 'Christian Religious Knowledge (CRK)', stream: 'Arts', icon: 'church', color: '#B45309', materials: 29, coverage: 0.85),
      (code: 'IRK', title: 'Islamic Religious Knowledge (IRK)', stream: 'Arts', icon: 'mosque', color: '#047857', materials: 29, coverage: 0.85),
      (code: 'FRE', title: 'French', stream: 'Arts', icon: 'translate', color: '#3B82F6', materials: 26, coverage: 0.81),
      (code: 'YOR', title: 'Yoruba', stream: 'Arts', icon: 'language', color: '#EA580C', materials: 24, coverage: 0.80),
      (code: 'IGB', title: 'Igbo', stream: 'Arts', icon: 'language', color: '#16A34A', materials: 24, coverage: 0.80),
      (code: 'HAU', title: 'Hausa', stream: 'Arts', icon: 'language', color: '#9333EA', materials: 24, coverage: 0.80),
      (code: 'ARA', title: 'Arabic', stream: 'Arts', icon: 'translate', color: '#059669', materials: 22, coverage: 0.78),
      (code: 'ART', title: 'Fine Arts', stream: 'Arts', icon: 'palette', color: '#BE185D', materials: 25, coverage: 0.83),
      (code: 'MUS', title: 'Music', stream: 'Arts', icon: 'music_note', color: '#6366F1', materials: 23, coverage: 0.80),
      (code: 'HEC', title: 'Home Economics', stream: 'Arts', icon: 'home', color: '#CA8A04', materials: 25, coverage: 0.81),
      (code: 'FDN', title: 'Food and Nutrition', stream: 'Arts', icon: 'restaurant', color: '#E11D48', materials: 26, coverage: 0.82),
      (code: 'CCP', title: 'Catering Craft Practice', stream: 'Arts', icon: 'dinner_dining', color: '#D97706', materials: 24, coverage: 0.79),
      (code: 'HMG', title: 'Home Management', stream: 'Arts', icon: 'roofing', color: '#475569', materials: 23, coverage: 0.78),
    ];

    final highSchoolCourses = <CuratedCourseModel>[];
    for (final exam in const ['WAEC', 'JAMB', 'NECO']) {
      final examLower = exam.toLowerCase();
      for (final s in curatedSubjects) {
        highSchoolCourses.add(
          CuratedCourseModel(
            id: '$examLower-${s.code.toLowerCase()}',
            courseCode: s.code,
            title: s.title,
            department: '$exam - ${s.stream}',
            totalMaterials: s.materials,
            hasActivePastPapers: true,
            iconName: s.icon,
            colorHex: s.color,
            syllabusCoverage: s.coverage,
          ),
        );
      }
    }

    return [
      ...highSchoolCourses,

      // ═══════════════════════════════════════════════════════════════════════
      // 3. SAT Standardized Prep
      // ═══════════════════════════════════════════════════════════════════════
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
      const CuratedCourseModel(
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
