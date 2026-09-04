import 'dart:convert';
import 'dart:math' as math;
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';

/// Service responsible for recording user learning activities (flashcard
/// reviews, study sessions, quizzes) and calculating live, accurate study
/// streaks, memory retention rates, weekly velocity, and heat map data.
abstract class UserActivityService {
  Future<void> recordStudySession({
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    int masteredCards = 0,
  });

  int getCurrentStreak();
  int getLongestStreak();
  int getTotalCardsMastered();
  int getWeeklyMinutesStudied();
  double getOverallRetentionRate();
  int getXpPoints();
  String getAcademicRank();
  List<HeatMapDayModel> getHeatMapData();
  AnalyticsSummaryModel getAnalyticsSummary();
}

class UserActivityServiceImpl implements UserActivityService {
  UserActivityServiceImpl(this._localStorageService);

  final LocalStorageService _localStorageService;

  static const String _sessionsKey = '__kortex_study_sessions';
  static const String _streakCurrentKey = '__kortex_streak_current';
  static const String _streakLongestKey = '__kortex_streak_longest';
  static const String _lastStudyDateKey = '__kortex_last_study_date';

  @override
  Future<void> recordStudySession({
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    int masteredCards = 0,
  }) async {
    final now = DateTime.now();

    // 1. Append session record to storage
    final sessions = _getSessions();
    final newSession = {
      'timestamp': now.toIso8601String(),
      'cardsReviewed': cardsReviewed,
      'durationSeconds': durationSeconds,
      'retentionScore': retentionScore,
      'masteredCards': masteredCards > 0 ? masteredCards : cardsReviewed,
    };
    sessions.add(newSession);

    // Keep up to 500 recent sessions
    if (sessions.length > 500) {
      sessions.removeRange(0, sessions.length - 500);
    }
    await _localStorageService.savePreference(
      key: _sessionsKey,
      data: jsonEncode(sessions),
    );

    // 2. Update daily study streak
    await _updateStreak(now);
  }

  Future<void> _updateStreak(DateTime now) async {
    final todayKey = _toDateKey(now);
    final lastDateStr = _localStorageService.getPreference(
      key: _lastStudyDateKey,
    );
    var currentStreak = getCurrentStreak();
    var longestStreak = getLongestStreak();

    if (lastDateStr == null || lastDateStr.isEmpty) {
      currentStreak = 1;
    } else if (lastDateStr == todayKey) {
      if (currentStreak <= 0) currentStreak = 1;
    } else {
      final lastDate = _parseDate(lastDateStr);
      final todayDate = _parseDate(todayKey);
      final diffDays = todayDate.difference(lastDate).inDays;

      if (diffDays == 1) {
        currentStreak += 1;
      } else if (diffDays > 1) {
        currentStreak = 1;
      }
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    await _localStorageService.savePreference(
      key: _lastStudyDateKey,
      data: todayKey,
    );
    await _localStorageService.savePreference(
      key: _streakCurrentKey,
      data: currentStreak.toString(),
    );
    await _localStorageService.savePreference(
      key: _streakLongestKey,
      data: longestStreak.toString(),
    );
  }

  @override
  int getCurrentStreak() {
    final raw = _localStorageService.getPreference(key: _streakCurrentKey);
    if (raw == null || raw.isEmpty) return 0;
    final streak = int.tryParse(raw) ?? 0;

    // Verify if streak was broken (e.g. user hasn't studied yesterday or today)
    final lastDateStr = _localStorageService.getPreference(
      key: _lastStudyDateKey,
    );
    if (lastDateStr != null && lastDateStr.isNotEmpty && streak > 0) {
      final todayKey = _toDateKey(DateTime.now());
      final lastDate = _parseDate(lastDateStr);
      final todayDate = _parseDate(todayKey);
      final diffDays = todayDate.difference(lastDate).inDays;
      if (diffDays > 1) {
        // Streak expired
        return 0;
      }
    }

    return streak;
  }

  @override
  int getLongestStreak() {
    final raw = _localStorageService.getPreference(key: _streakLongestKey);
    return int.tryParse(raw ?? '') ?? getCurrentStreak();
  }

  @override
  int getTotalCardsMastered() {
    final sessions = _getSessions();
    var total = 0;
    for (final s in sessions) {
      total +=
          (s['masteredCards'] as num?)?.toInt() ??
          (s['cardsReviewed'] as num?)?.toInt() ??
          0;
    }
    return total;
  }

  @override
  int getWeeklyMinutesStudied() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final sessions = _getSessions();
    var totalSeconds = 0;

    for (final s in sessions) {
      final dt = DateTime.tryParse(s['timestamp'] as String? ?? '');
      if (dt != null && dt.isAfter(sevenDaysAgo)) {
        totalSeconds += (s['durationSeconds'] as num?)?.toInt() ?? 0;
      }
    }

    if (totalSeconds <= 0) return 0;
    return math.max(1, (totalSeconds / 60).round());
  }

  @override
  double getOverallRetentionRate() {
    final sessions = _getSessions();
    if (sessions.isEmpty) return 0;
    var sumScore = 0.0;
    var count = 0;

    for (final s in sessions) {
      final score = (s['retentionScore'] as num?)?.toDouble();
      if (score != null) {
        sumScore += score;
        count++;
      }
    }

    return count == 0 ? 0.0 : (sumScore / count).clamp(0.0, 1.0);
  }

  @override
  int getXpPoints() {
    final sessions = _getSessions();
    var xp = 0;
    for (final s in sessions) {
      final cards = (s['cardsReviewed'] as num?)?.toInt() ?? 0;
      final minutes = (((s['durationSeconds'] as num?)?.toInt() ?? 0) / 60)
          .round();
      xp += (cards * 10) + (minutes * 5) + 50;
    }
    final streak = getCurrentStreak();
    return xp + (streak * 30);
  }

  @override
  String getAcademicRank() {
    final xp = getXpPoints();
    if (xp >= 2500) return 'Master of Recall';
    if (xp >= 1500) return 'Cortex Pioneer II';
    if (xp >= 800) return 'Cortex Pioneer I';
    if (xp >= 300) return 'Neural Scholar II';
    return 'Neural Scholar I';
  }

  @override
  List<HeatMapDayModel> getHeatMapData() {
    final now = DateTime.now();
    final sessions = _getSessions();
    final map = <String, ({int cards, int seconds})>{};

    for (final s in sessions) {
      final dt = DateTime.tryParse(s['timestamp'] as String? ?? '');
      if (dt != null) {
        final key = _toDateKey(dt);
        final prev = map[key] ?? (cards: 0, seconds: 0);
        map[key] = (
          cards: prev.cards + ((s['cardsReviewed'] as num?)?.toInt() ?? 0),
          seconds:
              prev.seconds + ((s['durationSeconds'] as num?)?.toInt() ?? 0),
        );
      }
    }

    return List.generate(28, (i) {
      final day = now.subtract(Duration(days: 27 - i));
      final key = _toDateKey(day);
      final entry = map[key];
      final cards = entry?.cards ?? 0;
      final seconds = entry?.seconds ?? 0;
      final minutes = seconds > 0 ? math.max(1, (seconds / 60).round()) : 0;

      var intensityLevel = 0;
      if (cards >= 30 || minutes >= 25) {
        intensityLevel = 4;
      } else if (cards >= 20 || minutes >= 15) {
        intensityLevel = 3;
      } else if (cards >= 10 || minutes >= 8) {
        intensityLevel = 2;
      } else if (cards > 0 || minutes > 0 || seconds > 0) {
        intensityLevel = 1;
      }

      return HeatMapDayModel(
        dateIso: day.toIso8601String(),
        intensityLevel: intensityLevel,
        cardsReviewed: cards,
        minutesStudied: minutes,
      );
    });
  }

  @override
  AnalyticsSummaryModel getAnalyticsSummary() {
    return AnalyticsSummaryModel(
      currentStreakDays: getCurrentStreak(),
      longestStreakDays: math.max(getLongestStreak(), getCurrentStreak()),
      weeklyMinutesStudied: getWeeklyMinutesStudied(),
      overallRetentionRate: getOverallRetentionRate(),
      totalCardsMastered: getTotalCardsMastered(),
      heatMapData: getHeatMapData(),
      xpPoints: getXpPoints(),
      academicRank: getAcademicRank(),
    );
  }

  List<Map<String, dynamic>> _getSessions() {
    try {
      final raw = _localStorageService.getPreference(key: _sessionsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Object {
      return [];
    }
  }

  static String _toDateKey(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length >= 3) {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    return DateTime.now();
  }
}
