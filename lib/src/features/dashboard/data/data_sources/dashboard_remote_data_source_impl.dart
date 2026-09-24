import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:drift/drift.dart' show Value;
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/data/models/study_deck_model.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/domain/logic/deck_title_resolver.dart';

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  DashboardRemoteDataSourceImpl(
    this._client, {
    UserActivityService? userActivityService,
    LocalStorageService? storageService,
    AppDatabase? database,
  }) : _userActivityService = userActivityService,
       _storageService = storageService,
       _database = database;

  final DashboardApiClient _client;
  final UserActivityService? _userActivityService;
  final LocalStorageService? _storageService;
  final AppDatabase? _database;

  AppDatabase? get _effectiveDatabase {
    if (_database != null) return _database;
    try {
      if (locator.isRegistered<AppDatabase>()) {
        return locator<AppDatabase>();
      }
    } on Object catch (_) {}
    return null;
  }

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
        final courses = list
            .map((e) => CuratedCourseModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (courses.isNotEmpty) return courses;
      }
    } on Object catch (_) {}
    return _getCoursesFromCalibrationProfile();
  }

  List<CuratedCourseModel> _getCoursesFromCalibrationProfile() {
    try {
      final raw = _storage?.getPreference(key: '__calibration_profile');
      if (raw != null && raw.isNotEmpty) {
        final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
        final subjects =
            (jsonMap['highSchoolSubjects'] as List<dynamic>?)
                ?.map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            [];
        final examName = (jsonMap['highSchoolExam'] as String?) ?? 'WAEC';

        if (subjects.isNotEmpty) {
          final catalog = _generateDefaultCatalogCourses();
          final matched = <CuratedCourseModel>[];

          for (final subject in subjects) {
            final lower = subject.toLowerCase().trim();
            CuratedCourseModel? bestMatch;
            for (final c in catalog) {
              final cTitleLower = c.title.toLowerCase();
              final isNameMatch =
                  cTitleLower == lower ||
                  cTitleLower.contains(lower) ||
                  lower.contains(cTitleLower) ||
                  c.courseCode.toLowerCase() == lower;

              if (isNameMatch) {
                if (c.department.toLowerCase().contains(
                  examName.toLowerCase(),
                )) {
                  bestMatch = c;
                  break;
                }
                bestMatch ??= c;
              }
            }

            if (bestMatch != null) {
              if (!matched.any((m) => m.id == bestMatch!.id)) {
                matched.add(bestMatch);
              }
            } else {
              matched.add(
                CuratedCourseModel(
                  id: 'course_${examName.toLowerCase()}_${subject.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '_')}',
                  courseCode: subject.length > 4
                      ? subject.substring(0, 4).toUpperCase()
                      : subject.toUpperCase(),
                  title: subject,
                  department: '$examName - General Studies',
                  totalMaterials: 25,
                  hasActivePastPapers: true,
                  iconName: 'school',
                  colorHex: '#6366F1',
                ),
              );
            }
          }

          if (matched.isNotEmpty) {
            try {
              final jsonStr = jsonEncode(
                matched.map((c) => c.toJson()).toList(),
              );
              unawaited(
                _storage?.savePreference(
                  key: PrefKeys.userCuratedCourses,
                  data: jsonStr,
                ),
              );
            } on Object catch (_) {}
            return matched;
          }
        }
      }
    } on Object catch (_) {}
    return const [];
  }

  List<StudyDeckModel> _getLocallySavedDecks() {
    try {
      final raw = _storage?.getPreference(key: PrefKeys.persistedUserDecks);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) {
              final m = e as Map<String, dynamic>;
              final deckId = (m['id'] as String?) ?? 'deck';
              final rawTitle = (m['title'] as String?) ?? 'Study Deck';
              final rawSubject = (m['subject'] as String?) ?? 'General Studies';
              final rawCategory = (m['category'] as String?) ?? 'General';
              final due = ((m['dueCards'] ?? m['due_cards']) as int?) ?? 0;
              final total =
                  ((m['totalCards'] ?? m['total_cards']) as int?) ?? 10;
              final mastery =
                  ((m['masteryRate'] ?? m['mastery_rate']) as num?)
                      ?.toDouble() ??
                  0.0;
              final lastStudied =
                  ((m['lastStudied'] ?? m['last_studied']) as String?) ??
                  DateTime.now().toIso8601String();

              final resolvedTitle = DeckTitleResolver.resolveTitle(
                deckId: deckId,
                currentTitle: rawTitle,
                subject: rawSubject,
                category: rawCategory,
              );
              final resolvedSubject = DeckTitleResolver.resolveSubject(
                deckId: deckId,
                currentSubject: rawSubject,
              );
              final resolvedCategory = DeckTitleResolver.resolveCategory(
                deckId: deckId,
                currentCategory: rawCategory,
              );

              return StudyDeckModel(
                id: deckId,
                title: resolvedTitle,
                subject: resolvedSubject,
                totalCards: total,
                dueCards: due,
                retentionRate: mastery,
                lastReviewedIso: lastStudied,
                category: resolvedCategory,
                colorHex: m['colorHex'] as String?,
              );
            })
            .where((d) => d.dueCards > 0)
            .toList();
      }
    } on Object catch (_) {}
    return const [];
  }

  Future<List<StudyDeckModel>> _resolveActiveDueDecks() async {
    final results = <StudyDeckModel>[];
    final seenIds = <String>{};

    // 1. Query DecksRemoteDataSource which has the unified canonical + created decks
    try {
      if (locator.isRegistered<DecksRemoteDataSource>()) {
        final deckModels = await locator<DecksRemoteDataSource>()
            .getUserDecks();
        for (final d in deckModels) {
          if (d.dueCards > 0 && seenIds.add(d.id)) {
            results.add(
              StudyDeckModel(
                id: d.id,
                title: d.title,
                subject: d.subject,
                totalCards: d.totalCards,
                dueCards: d.dueCards,
                retentionRate: d.masteryRate,
                lastReviewedIso: (d.lastStudied ?? DateTime.now())
                    .toIso8601String(),
                category: d.category,
              ),
            );
          }
        }
      }
    } on Object catch (_) {}

    // 2. Supplement with SQLite database if needed
    final db = _effectiveDatabase;
    if (db != null) {
      try {
        final entries = await db.getAllDecks();
        for (final d in entries) {
          if (d.dueCards > 0 && seenIds.add(d.id)) {
            results.add(
              StudyDeckModel(
                id: d.id,
                title: d.title,
                subject: d.subject,
                totalCards: d.totalCards,
                dueCards: d.dueCards,
                retentionRate: d.masteryRate,
                lastReviewedIso: (d.lastStudied ?? DateTime.now())
                    .toIso8601String(),
                category: d.category,
              ),
            );
          }
        }
      } on Object catch (_) {}
    }

    // 3. Supplement with locally saved preference decks if needed
    final saved = _getLocallySavedDecks();
    for (final d in saved) {
      if (d.dueCards > 0 && seenIds.add(d.id)) {
        results.add(d);
      }
    }

    return results;
  }

  @override
  Future<DashboardFeedModel> getDashboardFeed() async {
    final liveAnalytics = _userActivityService?.getAnalyticsSummary();
    final localCourses = _getLocallySavedCourses();
    final activeDueDecks = await _resolveActiveDueDecks();

    try {
      var feed = await _client.getDashboardFeed(const {});
      if (feed.curatedCourses.isNotEmpty) {
        try {
          final jsonStr = jsonEncode(
            feed.curatedCourses.map((c) => c.toJson()).toList(),
          );
          unawaited(
            _storage?.savePreference(
              key: PrefKeys.userCuratedCourses,
              data: jsonStr,
            ),
          );
          unawaited(
            _storage?.savePreference(
              key: PrefKeys.hasCompletedOnboarding,
              data: 'true',
            ),
          );
        } on Object catch (_) {}
      } else if (localCourses.isNotEmpty) {
        feed = feed.copyWith(curatedCourses: localCourses);
      }

      // Merge remote due decks with all active due decks (canonical + local)
      final combinedDueDecks = <StudyDeckModel>[];
      final seenDeckIds = <String>{};

      for (final d in feed.dueStudyDecks) {
        if (d.dueCards > 0 && seenDeckIds.add(d.id)) {
          combinedDueDecks.add(d);
        }
      }

      for (final d in activeDueDecks) {
        if (seenDeckIds.add(d.id)) {
          combinedDueDecks.add(d);
        }
      }

      feed = feed.copyWith(dueStudyDecks: combinedDueDecks);

      if (liveAnalytics != null &&
          (liveAnalytics.currentStreakDays > 0 ||
              liveAnalytics.xpPoints > 0 ||
              liveAnalytics.weeklyMinutesStudied > 0)) {
        feed = feed.copyWith(analyticsSummary: liveAnalytics);
      }
      return feed;
    } on Object catch (_) {
      return _generateFallbackFeedModel(
        liveAnalytics,
        fallbackDecks: activeDueDecks,
      );
    }
  }

  @override
  Future<List<StudyDeckModel>> getReviewQueue() async {
    try {
      final decks = await _client.getReviewQueue();
      if (decks.isNotEmpty) return decks;
    } on Object catch (_) {}

    final local = _getLocallySavedDecks();
    if (local.isNotEmpty) return local;

    final db = _effectiveDatabase;
    if (db != null) {
      try {
        final entries = await db.getAllDecks();
        if (entries.isNotEmpty) {
          return entries
              .where((d) => d.dueCards > 0)
              .map(
                (d) => StudyDeckModel(
                  id: d.id,
                  title: d.title,
                  subject: d.subject,
                  totalCards: d.totalCards,
                  dueCards: d.dueCards,
                  retentionRate: d.masteryRate,
                  lastReviewedIso: (d.lastStudied ?? DateTime.now())
                      .toIso8601String(),
                  category: d.category,
                ),
              )
              .toList();
        }
      } on Object catch (_) {}
    }

    return local;
  }

  @override
  Future<List<CuratedCourseModel>> getCatalogCourses() async {
    try {
      final courses = await _client.getCuratedCoursesCatalog();
      if (courses.isNotEmpty) {
        final db = _effectiveDatabase;
        if (db != null) {
          try {
            final now = DateTime.now();
            final companions = courses.map((c) {
              return CourseModulesCompanion(
                id: Value(c.id),
                courseCode: Value(c.courseCode),
                title: Value(c.title),
                department: Value(c.department),
                totalMaterials: Value(c.totalMaterials),
                hasActivePastPapers: Value(c.hasActivePastPapers),
                iconName: Value(c.iconName),
                colorHex: Value(c.colorHex),
                pdfDownloadUrl: Value(c.pdfDownloadUrl),
                syllabusCoverage: Value(c.syllabusCoverage),
                updatedAt: Value(now),
              );
            }).toList();
            await db.batchUpsertCourseModules(companions);
          } on Object catch (_) {}
        }
        return courses;
      }
      return _generateDefaultCatalogCourses();
    } on Object catch (_) {
      return _generateDefaultCatalogCourses();
    }
  }

  @override
  Future<List<CuratedCourseModel>> getUserCuratedCourses() async {
    try {
      final remoteCourses = await _client.getUserCuratedCourses();
      if (remoteCourses.isNotEmpty) {
        final jsonStr = jsonEncode(
          remoteCourses.map((c) => c.toJson()).toList(),
        );
        await _storage?.savePreference(
          key: PrefKeys.userCuratedCourses,
          data: jsonStr,
        );
        await _storage?.savePreference(
          key: PrefKeys.hasCompletedOnboarding,
          data: 'true',
        );
        return remoteCourses;
      }
    } on Object catch (_) {}

    return _getLocallySavedCourses();
  }

  @override
  Future<void> syncUserCourses(List<Map<String, dynamic>> courses) async {
    // 1. Instantly persist to Hive local storage for resilient offline/restart capability
    try {
      final catalog = _generateDefaultCatalogCourses();
      final catalogMap = {for (final c in catalog) c.id: c};

      final models = courses.map((m) {
        final id =
            (m['id'] as String?) ??
            'course_${DateTime.now().microsecondsSinceEpoch}';
        final catalogMatch = catalogMap[id];

        return CuratedCourseModel(
          id: id,
          courseCode:
              (m['courseCode'] as String?) ?? catalogMatch?.courseCode ?? 'CRS',
          title: (m['title'] as String?) ?? catalogMatch?.title ?? '',
          department:
              (m['department'] as String?) ??
              catalogMatch?.department ??
              'General Studies',
          totalMaterials:
              (m['totalMaterials'] as int?) ??
              catalogMatch?.totalMaterials ??
              15,
          hasActivePastPapers:
              (m['hasActivePastPapers'] as bool?) ??
              catalogMatch?.hasActivePastPapers ??
              true,
          iconName:
              (m['iconName'] as String?) ?? catalogMatch?.iconName ?? 'school',
          colorHex:
              (m['colorHex'] as String?) ?? catalogMatch?.colorHex ?? '#6366F1',
          syllabusCoverage:
              (m['syllabusCoverage'] as num?)?.toDouble() ??
              catalogMatch?.syllabusCoverage ??
              0.70,
        );
      }).toList();

      final jsonStr = jsonEncode(models.map((c) => c.toJson()).toList());
      await _storage?.savePreference(
        key: PrefKeys.userCuratedCourses,
        data: jsonStr,
      );
      if (models.isNotEmpty) {
        await _storage?.savePreference(
          key: PrefKeys.hasCompletedOnboarding,
          data: 'true',
        );
      }
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
    // 1. Immediately cache locally in Hive so dashboard renders instantly
    try {
      final catalog = _generateDefaultCatalogCourses();
      final matched = <CuratedCourseModel>[];
      for (final subject in subjects) {
        final lower = subject.toLowerCase().trim();
        CuratedCourseModel? bestMatch;
        for (final c in catalog) {
          final cTitleLower = c.title.toLowerCase();
          final isNameMatch =
              cTitleLower == lower ||
              cTitleLower.contains(lower) ||
              lower.contains(cTitleLower) ||
              c.courseCode.toLowerCase() == lower;

          if (isNameMatch) {
            if (c.department.toLowerCase().contains(examName.toLowerCase())) {
              bestMatch = c;
              break;
            }
            bestMatch ??= c;
          }
        }

        if (bestMatch != null) {
          if (!matched.any((m) => m.id == bestMatch!.id)) {
            matched.add(bestMatch);
          }
        } else {
          matched.add(
            CuratedCourseModel(
              id: 'course_${examName.toLowerCase()}_${subject.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '_')}',
              courseCode: subject.length > 4
                  ? subject.substring(0, 4).toUpperCase()
                  : subject.toUpperCase(),
              title: subject,
              department: '$examName - General Studies',
              totalMaterials: 25,
              hasActivePastPapers: true,
              iconName: 'school',
              colorHex: '#6366F1',
            ),
          );
        }
      }
      if (matched.isNotEmpty) {
        final current = _getLocallySavedCourses();
        final currentIds = {for (final c in current) c.id};
        final merged = [
          ...current,
          ...matched.where((m) => !currentIds.contains(m.id)),
        ];
        final jsonStr = jsonEncode(merged.map((c) => c.toJson()).toList());
        await _storage?.savePreference(
          key: PrefKeys.userCuratedCourses,
          data: jsonStr,
        );

        // Notify DashboardBloc immediately so UI reflects newly curated courses without waiting
        try {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        } on Object catch (_) {}
      }
    } on Object catch (_) {}

    // 2. Sync to Supabase RPC (gracefully non-blocking)
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
      final db = _effectiveDatabase;
      if (db != null) {
        try {
          await db.deleteCourseModuleById(courseId);
        } on Object catch (e) {
          developer.log('Error deleting course module from SQLite: $e');
        }
      }
      await _client.syncUserCourses({
        'p_courses': updated.map((c) => c.toJson()).toList(),
      });
    } on Object catch (e) {
      developer.log('Error in deleteCuratedCourse: $e');
    }
  }

  @override
  Future<void> deleteAllCuratedCourses() async {
    try {
      await _storage?.deletePreference(key: PrefKeys.userCuratedCourses);
      await _storage?.deletePreference(key: PrefKeys.syncedSecondarySubjects);
      await _storage?.deletePreference(key: '__calibration_profile');
      final db = _effectiveDatabase;
      if (db != null) {
        try {
          await db.deleteAllCourseModules();
        } on Object catch (_) {}
      }
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
    final res = await _client.startMockExam({
      'examId': examId,
      'subject': subject,
    });
    final dynamic data = res.data;
    if (data is Map<String, dynamic> && data['sessionId'] != null) {
      return data['sessionId'].toString();
    }
    throw const ServerException(
      message: 'Invalid session response from server',
    );
  }

  DashboardFeedModel _generateFallbackFeedModel(
    AnalyticsSummaryModel? liveAnalytics, {
    List<StudyDeckModel>? fallbackDecks,
  }) {
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
      dueStudyDecks: fallbackDecks ?? _getLocallySavedDecks(),
      curatedCourses: _getLocallySavedCourses(),
      syllabotDailyInsight: insight,
    );
  }

  List<HeatMapDayModel> _generateEmptyHeatMap() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final startMonday = currentMonday.subtract(const Duration(days: 21));

    return List.generate(28, (i) {
      final day = startMonday.add(Duration(days: i));
      return HeatMapDayModel(
        dateIso: day.toIso8601String(),
        intensityLevel: 0,
        cardsReviewed: 0,
        minutesStudied: 0,
      );
    });
  }

  List<CuratedCourseModel> _generateDefaultCatalogCourses() {
    return const [];
  }
}
