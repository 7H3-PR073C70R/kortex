import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/planner/data/models/exam_event_model.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';

class PlannerRepositoryImpl implements PlannerRepository {
  PlannerRepositoryImpl({
    CramWorkloadCalculator? calculator,
    AppDatabase? database,
    LocalStorageService? storageService,
    UserStorageService? userStorageService,
    Dio? dio,
  }) : _calculator = calculator ?? const CramWorkloadCalculator(),
       _database = database,
       _storageService = storageService,
       _userStorageService = userStorageService,
       _dio = dio;

  final CramWorkloadCalculator _calculator;
  final AppDatabase? _database;
  final LocalStorageService? _storageService;
  final UserStorageService? _userStorageService;
  final Dio? _dio;

  Dio? get _effectiveDio {
    if (_dio != null) return _dio;
    try {
      if (locator.isRegistered<Dio>()) {
        return locator<Dio>();
      }
    } on Object catch (_) {}
    return null;
  }

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

  UserStorageService? get _userStorage {
    if (_userStorageService != null) return _userStorageService;
    try {
      if (locator.isRegistered<UserStorageService>()) {
        return locator<UserStorageService>();
      }
    } on Object catch (_) {}
    return null;
  }

  // In-memory local cache / fallback list
  final List<ExamEventModel> _cachedExams = [];
  bool _migrationAttempted = false;

  void _loadFromStorage() {
    final db = _effectiveDatabase;
    if (db != null) {
      try {
        // Load synchronously from memory while kicking off async Drift sync
        unawaited(_syncFromDrift());
        return;
      } on Object catch (_) {}
    }

    try {
      final storage = _storage;
      final raw = storage?.getPreference(key: PrefKeys.persistedExamCountdowns);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _cachedExams
          ..clear()
          ..addAll(
            list.map((e) => ExamEventModel.fromJson(e as Map<String, dynamic>)),
          )
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
      }
    } on Object catch (_) {}
  }

  Future<void> _syncFromDrift() async {
    final db = _effectiveDatabase;
    if (db == null) return;

    try {
      final entries = await db.getAllExamEvents();
      if (entries.isNotEmpty) {
        _cachedExams
          ..clear()
          ..addAll(
            entries.map(
              (e) => ExamEventModel(
                id: e.id,
                userId: e.userId,
                examName: e.examName,
                targetDate: e.targetDate,
                subjectTrack: e.subjectTrack,
                totalCardsCount: e.totalCardsCount,
                masteredCardsCount: e.masteredCardsCount,
                totalLapses: e.totalLapses,
                dailyTarget: e.dailyTarget,
                targetScorePercent: e.targetScorePercent,
                createdAt: e.createdAt,
              ),
            ),
          )
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
        return;
      }

      // Check migration from SharedPreferences
      if (!_migrationAttempted && _storage != null) {
        _migrationAttempted = true;
        final raw = _storage?.getPreference(
          key: PrefKeys.persistedExamCountdowns,
        );
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          final parsed = list
              .map((e) => ExamEventModel.fromJson(e as Map<String, dynamic>))
              .toList();

          final companions = parsed
              .map(
                (e) => ExamEventsCompanion(
                  id: Value(e.id),
                  userId: Value(e.userId),
                  examName: Value(e.examName),
                  targetDate: Value(e.targetDate),
                  subjectTrack: Value(e.subjectTrack),
                  totalCardsCount: Value(e.totalCardsCount),
                  masteredCardsCount: Value(e.masteredCardsCount),
                  totalLapses: Value(e.totalLapses),
                  dailyTarget: Value(e.dailyTarget),
                  targetScorePercent: Value(e.targetScorePercent),
                  createdAt: Value(e.createdAt ?? DateTime.now()),
                ),
              )
              .toList();

          await db.batchUpsertExamEvents(companions);
          await _storage?.deletePreference(
            key: PrefKeys.persistedExamCountdowns,
          );

          _cachedExams
            ..clear()
            ..addAll(parsed)
            ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
        }
      }
    } on Object catch (e) {
      developer.log('Error syncing ExamEvents from Drift: $e');
    }
  }

  void _saveToStorage() {
    final db = _effectiveDatabase;
    if (db != null) {
      try {
        final companions = _cachedExams
            .map(
              (e) => ExamEventsCompanion(
                id: Value(e.id),
                userId: Value(e.userId),
                examName: Value(e.examName),
                targetDate: Value(e.targetDate),
                subjectTrack: Value(e.subjectTrack),
                totalCardsCount: Value(e.totalCardsCount),
                masteredCardsCount: Value(e.masteredCardsCount),
                totalLapses: Value(e.totalLapses),
                dailyTarget: Value(e.dailyTarget),
                targetScorePercent: Value(e.targetScorePercent),
                createdAt: Value(e.createdAt ?? DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            )
            .toList();

        unawaited(db.batchUpsertExamEvents(companions));
      } on Object catch (e) {
        developer.log('Error saving ExamEvents to Drift: $e');
      }
    }

    try {
      final storage = _storage;
      final jsonStr = jsonEncode(_cachedExams.map((e) => e.toJson()).toList());
      unawaited(
        storage?.savePreference(
          key: PrefKeys.persistedExamCountdowns,
          data: jsonStr,
        ),
      );
    } on Object catch (_) {}
  }

  @override
  Future<Either<Failure, List<ExamEventEntity>>> getActiveExams() {
    return Future<List<ExamEventEntity>>.sync(() async {
      if (_cachedExams.isEmpty) {
        _loadFromStorage();
      }

      // Attempt background/active sync with Supabase backend
      final client = _effectiveDio;
      final userId = _userStorage?.getUserId() ?? '';
      if (client != null && AppApiEndpoint.baseUri.isNotEmpty) {
        try {
          final uri = userId.isNotEmpty
              ? '${AppApiEndpoint.baseUri}${AppApiEndpoint.examEvents}?user_id=eq.$userId&order=target_date.asc'
              : '${AppApiEndpoint.baseUri}${AppApiEndpoint.examEvents}?order=target_date.asc';
          final response = await client.get<dynamic>(uri);
          if (response.statusCode == 200 && response.data is List) {
            final remoteList =
                (response.data as List<dynamic>)
                    .map(
                      (e) => ExamEventModel.fromJson(e as Map<String, dynamic>),
                    )
                    .toList()
                  ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

            _cachedExams
              ..clear()
              ..addAll(remoteList);
            _saveToStorage();
          }
        } on Object catch (e) {
          developer.log('Failed to fetch exams from Supabase: $e');
        }
      }

      _cachedExams.sort((a, b) => a.targetDate.compareTo(b.targetDate));
      return List<ExamEventEntity>.from(_cachedExams);
    }).makeRequest();
  }

  @override
  Future<Either<Failure, ExamEventEntity>> createExam({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    AssessmentType assessmentType = AssessmentType.finalExam,
    List<String> scopedDeckIds = const [],
    List<String> scopedTopics = const [],
    double? weightPercent,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  }) {
    return Future<ExamEventEntity>.sync(() async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final daysRemaining = target.difference(today).inDays;
      final dailyTarget = _calculator.calculateDailyTarget(
        remainingCards: totalCardsCount,
        lapses: 0,
        daysRemaining: daysRemaining < 1 ? 1 : daysRemaining,
      );

      var examId = 'exam-${DateTime.now().millisecondsSinceEpoch}';
      final client = _effectiveDio;
      final userId = _userStorage?.getUserId() ?? '';

      if (client != null && AppApiEndpoint.baseUri.isNotEmpty) {
        try {
          final payload = <String, dynamic>{
            'exam_name': examName,
            'target_date': targetDate.toIso8601String().split('T').first,
            'subject_track': subjectTrack,
            'assessment_type': assessmentType.name,
            'scoped_deck_ids': scopedDeckIds,
            'scoped_topics': scopedTopics,
            'weight_percent': ?weightPercent,
            'total_cards_count': totalCardsCount,
            'mastered_cards_count': 0,
            'total_lapses': 0,
            'daily_target': dailyTarget,
            'target_score_percent': targetScorePercent,
            if (userId.isNotEmpty) 'user_id': userId,
          };
          final response = await client.post<dynamic>(
            '${AppApiEndpoint.baseUri}${AppApiEndpoint.examEvents}',
            data: payload,
            options: Options(headers: {'Prefer': 'return=representation'}),
          );
          if (response.statusCode == 201 || response.statusCode == 200) {
            if (response.data is List && (response.data as List).isNotEmpty) {
              final first =
                  (response.data as List).first as Map<String, dynamic>;
              if (first['id'] != null) {
                examId = first['id'].toString();
              }
            } else if (response.data is Map &&
                (response.data as Map)['id'] != null) {
              examId = (response.data as Map)['id'].toString();
            }
          }
        } on Object catch (e) {
          developer.log('Failed to post new exam to Supabase: $e');
        }
      }

      final newExam = ExamEventModel(
        id: examId,
        userId: userId.isNotEmpty ? userId : 'current-user',
        examName: examName,
        targetDate: targetDate,
        subjectTrack: subjectTrack,
        assessmentType: assessmentType,
        scopedDeckIds: scopedDeckIds,
        scopedTopics: scopedTopics,
        weightPercent: weightPercent,
        totalCardsCount: totalCardsCount,
        dailyTarget: dailyTarget,
        targetScorePercent: targetScorePercent,
        createdAt: DateTime.now(),
      );

      _cachedExams
        ..add(newExam)
        ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
      _saveToStorage();
      return newExam;
    }).makeRequest();
  }

  @override
  Future<Either<Failure, ExamEventEntity>> updateExam({
    required String examId,
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    AssessmentType? assessmentType,
    List<String>? scopedDeckIds,
    List<String>? scopedTopics,
    double? weightPercent,
    int? totalCardsCount,
    double? targetScorePercent,
    bool? isCompleted,
    double? achievedScorePercent,
  }) {
    return Future<ExamEventEntity>.sync(() async {
      final idx = _cachedExams.indexWhere((e) => e.id == examId);
      final existing = idx >= 0 ? _cachedExams[idx] : null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final daysRemaining = target.difference(today).inDays;
      final cards = totalCardsCount ?? existing?.totalCardsCount ?? 0;
      final dailyTarget = _calculator.calculateDailyTarget(
        remainingCards: cards,
        lapses: existing?.totalLapses ?? 0,
        daysRemaining: daysRemaining < 1 ? 1 : daysRemaining,
      );

      final effType = assessmentType ?? existing?.assessmentType ?? AssessmentType.finalExam;
      final effDecks = scopedDeckIds ?? existing?.scopedDeckIds ?? const <String>[];
      final effTopics = scopedTopics ?? existing?.scopedTopics ?? const <String>[];
      final effWeight = weightPercent ?? existing?.weightPercent;
      final effCompleted = isCompleted ?? existing?.isCompleted ?? false;
      final effAchieved = achievedScorePercent ?? existing?.achievedScorePercent;

      final client = _effectiveDio;
      final userId = _userStorage?.getUserId() ?? '';
      if (client != null && AppApiEndpoint.baseUri.isNotEmpty) {
        try {
          final payload = <String, dynamic>{
            'exam_name': examName,
            'target_date': targetDate.toIso8601String().split('T').first,
            'subject_track': subjectTrack,
            'assessment_type': effType.name,
            'scoped_deck_ids': effDecks,
            'scoped_topics': effTopics,
            'weight_percent': ?effWeight,
            'total_cards_count': ?totalCardsCount,
            'target_score_percent': ?targetScorePercent,
            'daily_target': dailyTarget,
            'is_completed': effCompleted,
            'achieved_score_percent': ?effAchieved,
            'updated_at': DateTime.now().toIso8601String(),
            if (userId.isNotEmpty) 'user_id': userId,
          };
          final uri = userId.isNotEmpty
              ? '${AppApiEndpoint.baseUri}${AppApiEndpoint.examEvents}?id=eq.$examId&user_id=eq.$userId'
              : '${AppApiEndpoint.baseUri}${AppApiEndpoint.examEvents}?id=eq.$examId';
          await client.patch<dynamic>(
            uri,
            data: payload,
          );
        } on Object catch (e) {
          developer.log('Failed to patch exam in Supabase: $e');
        }
      }

      final updated = ExamEventModel(
        id: examId,
        userId:
            existing?.userId ?? (userId.isNotEmpty ? userId : 'current-user'),
        examName: examName,
        targetDate: targetDate,
        subjectTrack: subjectTrack,
        assessmentType: effType,
        scopedDeckIds: effDecks,
        scopedTopics: effTopics,
        weightPercent: effWeight,
        totalCardsCount: cards,
        masteredCardsCount: existing?.masteredCardsCount ?? 0,
        totalLapses: existing?.totalLapses ?? 0,
        dailyTarget: dailyTarget,
        targetScorePercent:
            targetScorePercent ?? existing?.targetScorePercent ?? 0.85,
        isCompleted: effCompleted,
        achievedScorePercent: effAchieved,
        completedAt: existing?.completedAt,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      if (idx >= 0) {
        _cachedExams[idx] = updated;
      } else {
        _cachedExams.add(updated);
      }
      _cachedExams.sort((a, b) => a.targetDate.compareTo(b.targetDate));
      _saveToStorage();
      return updated;
    }).makeRequest();
  }

  @override
  Future<Either<Failure, ExamEventEntity>> completeExam({
    required String examId,
    required double scorePercent,
    bool rolloverWeakCards = true,
  }) {
    return Future<ExamEventEntity>.sync(() async {
      final idx = _cachedExams.indexWhere((e) => e.id == examId);
      if (idx < 0) {
        throw Exception('Exam not found with id $examId');
      }
      final existing = _cachedExams[idx];
      final model = ExamEventModel(
        id: existing.id,
        userId: existing.userId,
        examName: existing.examName,
        targetDate: existing.targetDate,
        subjectTrack: existing.subjectTrack,
        assessmentType: existing.assessmentType,
        scopedDeckIds: existing.scopedDeckIds,
        scopedTopics: existing.scopedTopics,
        weightPercent: existing.weightPercent,
        totalCardsCount: existing.totalCardsCount,
        masteredCardsCount: existing.masteredCardsCount,
        totalLapses: existing.totalLapses,
        dailyTarget: 0,
        targetScorePercent: existing.targetScorePercent,
        isCompleted: true,
        achievedScorePercent: scorePercent,
        completedAt: DateTime.now(),
        createdAt: existing.createdAt,
      );

      _cachedExams[idx] = model;
      _saveToStorage();
      return model;
    }).makeRequest();
  }

  @override
  Future<Either<Failure, ExamEventEntity>> reopenExam(String examId) {
    return Future<ExamEventEntity>.sync(() async {
      final idx = _cachedExams.indexWhere((e) => e.id == examId);
      if (idx < 0) {
        throw Exception('Exam not found with id $examId');
      }
      final existing = _cachedExams[idx];
      final model = ExamEventModel(
        id: existing.id,
        userId: existing.userId,
        examName: existing.examName,
        targetDate: existing.targetDate,
        subjectTrack: existing.subjectTrack,
        assessmentType: existing.assessmentType,
        scopedDeckIds: existing.scopedDeckIds,
        scopedTopics: existing.scopedTopics,
        weightPercent: existing.weightPercent,
        totalCardsCount: existing.totalCardsCount,
        masteredCardsCount: existing.masteredCardsCount,
        totalLapses: existing.totalLapses,
        dailyTarget: existing.dailyTarget,
        targetScorePercent: existing.targetScorePercent,
        createdAt: existing.createdAt,
      );

      _cachedExams[idx] = model;
      _saveToStorage();
      return model;
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> deleteExam(String examId) {
    return Future<void>.sync(() async {
      final client = _effectiveDio;
      final userId = _userStorage?.getUserId() ?? '';
      if (client != null && AppApiEndpoint.baseUri.isNotEmpty) {
        try {
          final uri = userId.isNotEmpty
              ? '${AppApiEndpoint.baseUri}${AppApiEndpoint.examEvents}?id=eq.$examId&user_id=eq.$userId'
              : '${AppApiEndpoint.baseUri}${AppApiEndpoint.examEvents}?id=eq.$examId';
          await client.delete<dynamic>(uri);
        } on Object catch (e) {
          developer.log('Failed to delete exam from Supabase: $e');
        }
      }

      final db = _effectiveDatabase;
      if (db != null) {
        try {
          await db.deleteExamEventById(examId);
        } on Object catch (e) {
          developer.log('Error deleting ExamEvent from Drift: $e');
        }
      }

      _cachedExams.removeWhere((e) => e.id == examId);
      _saveToStorage();
    }).makeRequest();
  }
}
