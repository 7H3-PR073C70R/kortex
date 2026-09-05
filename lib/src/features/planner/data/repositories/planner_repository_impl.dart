import 'dart:async';
import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/planner/data/models/exam_event_model.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';

class PlannerRepositoryImpl implements PlannerRepository {
  PlannerRepositoryImpl({
    CramWorkloadCalculator? calculator,
    LocalStorageService? storageService,
  })  : _calculator = calculator ?? const CramWorkloadCalculator(),
        _storageService = storageService;

  final CramWorkloadCalculator _calculator;
  final LocalStorageService? _storageService;

  LocalStorageService? get _storage {
    if (_storageService != null) return _storageService;
    try {
      return locator<LocalStorageService>();
    } on Object catch (_) {
      return null;
    }
  }

  // In-memory local cache / fallback list
  final List<ExamEventModel> _cachedExams = [];

  void _loadFromStorage() {
    try {
      final storage = _storage;
      final raw = storage?.getPreference(key: PrefKeys.persistedExamCountdowns);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _cachedExams
          ..clear()
          ..addAll(
            list.map((e) => ExamEventModel.fromJson(e as Map<String, dynamic>)),
          );
      }
    } on Object catch (_) {}
  }

  void _saveToStorage() {
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
    return Future<List<ExamEventEntity>>.sync(() {
      if (_cachedExams.isEmpty) {
        _loadFromStorage();
      }
      return List<ExamEventEntity>.from(_cachedExams);
    }).makeRequest();
  }

  @override
  Future<Either<Failure, ExamEventEntity>> createExam({
    required String examName,
    required DateTime targetDate,
    required String subjectTrack,
    int totalCardsCount = 0,
    double targetScorePercent = 0.85,
  }) {
    return Future<ExamEventEntity>.sync(() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final daysRemaining = target.difference(today).inDays;
      final dailyTarget = _calculator.calculateDailyTarget(
        remainingCards: totalCardsCount,
        lapses: 0,
        daysRemaining: daysRemaining < 1 ? 1 : daysRemaining,
      );

      final newExam = ExamEventModel(
        id: 'exam-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'current-user',
        examName: examName,
        targetDate: targetDate,
        subjectTrack: subjectTrack,
        totalCardsCount: totalCardsCount,
        dailyTarget: dailyTarget,
        targetScorePercent: targetScorePercent,
        createdAt: DateTime.now(),
      );

      _cachedExams.add(newExam);
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
    int? totalCardsCount,
    double? targetScorePercent,
  }) {
    return Future<ExamEventEntity>.sync(() {
      final idx = _cachedExams.indexWhere((e) => e.id == examId);
      final existing = idx >= 0 ? _cachedExams[idx] : null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final daysRemaining = target.difference(today).inDays;
      final cards = totalCardsCount ?? existing?.totalCardsCount ?? 0;
      final dailyTarget = _calculator.calculateDailyTarget(
        remainingCards: cards,
        lapses: existing?.totalLapses ?? 0,
        daysRemaining: daysRemaining < 1 ? 1 : daysRemaining,
      );

      final updated = ExamEventModel(
        id: examId,
        userId: existing?.userId ?? 'current-user',
        examName: examName,
        targetDate: targetDate,
        subjectTrack: subjectTrack,
        totalCardsCount: cards,
        masteredCardsCount: existing?.masteredCardsCount ?? 0,
        totalLapses: existing?.totalLapses ?? 0,
        dailyTarget: dailyTarget,
        targetScorePercent:
            targetScorePercent ?? existing?.targetScorePercent ?? 0.85,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      if (idx >= 0) {
        _cachedExams[idx] = updated;
      } else {
        _cachedExams.add(updated);
      }
      _saveToStorage();
      return updated;
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> deleteExam(String examId) {
    return Future<void>.sync(() {
      _cachedExams.removeWhere((e) => e.id == examId);
      _saveToStorage();
    }).makeRequest();
  }
}
