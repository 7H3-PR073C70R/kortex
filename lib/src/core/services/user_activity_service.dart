import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';


/// Categories of student activity that award XP across Kortex.
enum XpActivityCategory {
  cardReview(10, 'Card Review'),
  deckCompletion(50, 'Deck Completed'),
  deckCreation(30, 'Deck Created'),
  quizQuestionCorrect(15, 'Quiz Correct Answer'),
  quizCompletion(100, 'Quiz Completed'),
  quizDuelWin(150, 'Quiz Duel Victory'),
  quizDuelParticipation(50, 'Quiz Duel Participant'),
  plannerTaskCompletion(40, 'Task Completed'),
  dailyPlannerGoal(150, 'Daily Goal Achieved'),
  syllabotQuery(10, 'Syllabot AI Interaction'),
  syllabotExercise(30, 'AI Exercise Completed'),
  aiDeckGeneration(25, 'AI Deck Generated'),
  focusSession(75, 'Focus Session Completed'),
  coWorkingGroupBonus(25, 'Group Study Bonus'),
  communityPost(15, 'Community Post'),
  communityAnswer(30, 'Community Answer'),
  verifiedSolution(100, 'Verified Solution'),
  documentIngestion(30, 'Document Ingestion'),
  onboardingCalibration(100, 'Profile Calibration'),
  dailyCheckIn(20, 'Daily Check-in');

  const XpActivityCategory(this.defaultBaseXp, this.displayName);
  final int defaultBaseXp;
  final String displayName;
}

/// Telemetry payload emitted whenever XP is awarded to a student.
class XpEarnedEvent {
  const XpEarnedEvent({
    required this.category,
    required this.baseAmount,
    required this.multiplier,
    required this.xpEarned,
    required this.totalXp,
    this.sourceId,
    this.metadata,
  });

  final XpActivityCategory category;
  final int baseAmount;
  final double multiplier;
  final int xpEarned;
  final int totalXp;
  final String? sourceId;
  final Map<String, dynamic>? metadata;
}

/// Service responsible for recording user learning activities (flashcard
/// reviews, study sessions, quizzes, AI sessions, tasks) and calculating live,
/// accurate study streaks, memory retention rates, weekly velocity, heat map
/// data, and universal XP rewards.
abstract class UserActivityService {
  Future<void> recordStudySession({
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    int masteredCards = 0,
    String? activityCategory,
    String? subject,
    String? topicId,
  });

  Stream<AnalyticsSummaryModel> get analyticsSummaryStream;
  Stream<XpEarnedEvent> get xpEarnedStream;
  Map<String, ({int totalItems, double avgRetention, int minutes})>
      getSubjectBreakdown();

  int getCurrentStreak();
  int getLongestStreak();
  int getStreakFreezes();
  Future<void> setStreakFreezes(int count);
  Future<bool> consumeStreakFreeze();
  int getSpentXp();
  Future<bool> purchaseStreakFreeze({int costXp = 200});
  int getTotalCardsMastered();
  int getWeeklyMinutesStudied();
  double getOverallRetentionRate();
  int getXpPoints();
  double getStreakMultiplier();
  Future<XpEarnedEvent> awardXp(
    XpActivityCategory category, {
    int? customBaseAmount,
    String? sourceId,
    Map<String, dynamic>? metadata,
  });
  List<Map<String, dynamic>> getXpTransactions();
  int getLevelForXp(int xp);
  int getXpForLevel(int level);
  String getAvatarFrameForLevel(int level);
  int getBonusKarma();
  Future<void> addBonusKarma(int amount);
  String getAcademicRank();
  List<HeatMapDayModel> getHeatMapData();
  bool hasStudiedToday();
  AnalyticsSummaryModel getAnalyticsSummary();
}

class UserActivityServiceImpl implements UserActivityService {
  UserActivityServiceImpl(this._localStorageService);

  final LocalStorageService _localStorageService;
  final StreamController<AnalyticsSummaryModel> _analyticsStreamController =
      StreamController<AnalyticsSummaryModel>.broadcast();
  final StreamController<XpEarnedEvent> _xpEarnedStreamController =
      StreamController<XpEarnedEvent>.broadcast();

  static const String _sessionsKey = '__kortex_study_sessions';
  static const String _streakCurrentKey = '__kortex_streak_current';
  static const String _streakLongestKey = '__kortex_streak_longest';
  static const String _lastStudyDateKey = '__kortex_last_study_date';
  static const String _streakFreezesKey = '__kortex_streak_freezes';
  static const String _spentXpKey = '__kortex_spent_xp';
  static const String _bonusKarmaKey = '__kortex_bonus_karma';
  static const String _xpTransactionsKey = '__kortex_xp_transactions_list';
  static const String _directXpAccumulatedKey = '__kortex_direct_xp_total';

  @override
  Stream<AnalyticsSummaryModel> get analyticsSummaryStream =>
      _analyticsStreamController.stream;

  @override
  Stream<XpEarnedEvent> get xpEarnedStream => _xpEarnedStreamController.stream;

  void _notifyAnalyticsUpdated() {
    if (!_analyticsStreamController.isClosed) {
      _analyticsStreamController.add(getAnalyticsSummary());
    }
  }

  @override
  double getStreakMultiplier() {
    final streak = getCurrentStreak();
    if (streak >= 30) return 2;
    if (streak >= 14) return 1.75;
    if (streak >= 7) return 1.5;
    if (streak >= 4) return 1.25;
    return 1;
  }

  @override
  Future<XpEarnedEvent> awardXp(
    XpActivityCategory category, {
    int? customBaseAmount,
    String? sourceId,
    Map<String, dynamic>? metadata,
  }) async {
    final baseAmount = customBaseAmount ?? category.defaultBaseXp;
    final multiplier = getStreakMultiplier();
    final xpEarned = (baseAmount * multiplier).round();

    // 1. Accumulate direct XP locally
    final currentDirectXp = _getDirectXpAccumulated();
    final newDirectXp = currentDirectXp + xpEarned;
    await _localStorageService.savePreference(
      key: _directXpAccumulatedKey,
      data: newDirectXp.toString(),
    );

    // 2. Append transaction log
    final txList = getXpTransactions();
    final newTx = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'category': category.name,
      'categoryDisplayName': category.displayName,
      'baseAmount': baseAmount,
      'multiplier': multiplier,
      'xpEarned': xpEarned,
      'timestamp': DateTime.now().toIso8601String(),
      'sourceId': ?sourceId,
      'metadata': ?metadata,
    };
    txList.insert(0, newTx);
    if (txList.length > 200) {
      txList.removeRange(200, txList.length);
    }
    await _localStorageService.savePreference(
      key: _xpTransactionsKey,
      data: jsonEncode(txList),
    );

    final event = XpEarnedEvent(
      category: category,
      baseAmount: baseAmount,
      multiplier: multiplier,
      xpEarned: xpEarned,
      totalXp: getXpPoints(),
      sourceId: sourceId,
      metadata: metadata,
    );

    // 3. Emit event & update telemetry streams
    if (!_xpEarnedStreamController.isClosed) {
      _xpEarnedStreamController.add(event);
    }
    _notifyAnalyticsUpdated();

    // 4. Fire-and-forget sync to backend so leaderboard stays correct for all users.
    //    syncUserProgress updates profiles.xp_points atomically, which triggers
    //    the Supabase leaderboard sync trigger automatically.
    _syncProgressToBackend(xpDelta: xpEarned);

    return event;
  }

  /// Pushes the latest XP delta + streak + track to Supabase asynchronously.
  /// Safe to call fire-and-forget — all errors are silently swallowed.
  void _syncProgressToBackend({int xpDelta = 0}) {
    try {
      final communityRepo = locator.isRegistered<CommunityRepository>()
          ? locator<CommunityRepository>()
          : null;
      if (communityRepo == null) return;

      final authProfile = locator.isRegistered<AuthBloc>()
          ? locator<AuthBloc>().state.userProfile
          : null;

      final currentStreak = getCurrentStreak();
      final track = authProfile?.targetTrack.isNotEmpty == true
          ? authProfile!.targetTrack
          : null;

      unawaited(
        communityRepo
            .syncUserProgress(
              xpDelta: xpDelta,
              streakDays: currentStreak,
              track: track,
            )
            .catchError(
              (_) =>
                  const Right<Failure, Map<String, dynamic>>(<String, dynamic>{}),
            ),
      );
    } on Object catch (_) {
      // Offline-safe — never break the UX for a sync failure.
    }
  }

  @override
  List<Map<String, dynamic>> getXpTransactions() {
    try {
      final raw = _localStorageService.getPreference(key: _xpTransactionsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Object {
      return [];
    }
  }

  int _getDirectXpAccumulated() {
    final raw = _localStorageService.getPreference(key: _directXpAccumulatedKey);
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  @override
  Map<String, ({int totalItems, double avgRetention, int minutes})>
      getSubjectBreakdown() {
    final sessions = _getSessions();
    final map = <
        String,
        ({
          int totalItems,
          double totalRetentionSum,
          int count,
          int seconds,
        })>{};

    for (final s in sessions) {
      final subj = (s['subject'] as String?)?.trim();
      if (subj == null || subj.isEmpty) continue;
      final cards = (s['cardsReviewed'] as num?)?.toInt() ?? 0;
      final retention = (s['retentionScore'] as num?)?.toDouble() ?? 0.85;
      final seconds = (s['durationSeconds'] as num?)?.toInt() ?? 0;

      final prev = map[subj] ??
          (totalItems: 0, totalRetentionSum: 0.0, count: 0, seconds: 0);
      map[subj] = (
        totalItems: prev.totalItems + cards,
        totalRetentionSum: prev.totalRetentionSum + retention,
        count: prev.count + 1,
        seconds: prev.seconds + seconds,
      );
    }

    final result =
        <String, ({int totalItems, double avgRetention, int minutes})>{};
    for (final entry in map.entries) {
      final count = entry.value.count == 0 ? 1 : entry.value.count;
      final avgRet = (entry.value.totalRetentionSum / count).clamp(0.0, 1.0);
      final mins = entry.value.seconds > 0
          ? math.max(1, (entry.value.seconds / 60).round())
          : 0;
      result[entry.key] = (
        totalItems: entry.value.totalItems,
        avgRetention: avgRet,
        minutes: mins,
      );
    }
    return result;
  }

  @override
  int getStreakFreezes() {
    final raw = _localStorageService.getPreference(key: _streakFreezesKey);
    if (raw == null || raw.isEmpty) return 1;
    return int.tryParse(raw) ?? 1;
  }

  @override
  Future<void> setStreakFreezes(int count) async {
    await _localStorageService.savePreference(
      key: _streakFreezesKey,
      data: count.toString(),
    );
    _notifyAnalyticsUpdated();
  }

  @override
  Future<bool> consumeStreakFreeze() async {
    final current = getStreakFreezes();
    if (current <= 0) return false;
    await setStreakFreezes(current - 1);
    return true;
  }

  @override
  int getSpentXp() {
    final raw = _localStorageService.getPreference(key: _spentXpKey);
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  Future<void> _recordSpentXp(int amount) async {
    final current = getSpentXp();
    await _localStorageService.savePreference(
      key: _spentXpKey,
      data: (current + amount).toString(),
    );
  }

  @override
  Future<bool> purchaseStreakFreeze({int costXp = 200}) async {
    final availableXp = getXpPoints();
    if (availableXp < costXp) return false;

    await _recordSpentXp(costXp);
    await setStreakFreezes(getStreakFreezes() + 1);
    _notifyAnalyticsUpdated();
    return true;
  }

  @override
  Future<void> recordStudySession({
    required int cardsReviewed,
    required int durationSeconds,
    required double retentionScore,
    int masteredCards = 0,
    String? activityCategory,
    String? subject,
    String? topicId,
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
      'category': ?activityCategory,
      'subject': ?subject,
      'topicId': ?topicId,
    };
    sessions.add(newSession);

    if (sessions.length > 500) {
      sessions.removeRange(0, sessions.length - 500);
    }
    await _localStorageService.savePreference(
      key: _sessionsKey,
      data: jsonEncode(sessions),
    );

    // 2. Award Card Review XP with streak multiplier
    await awardXp(
      XpActivityCategory.cardReview,
      customBaseAmount: (cardsReviewed * 10) + ((durationSeconds / 60).round() * 5),
      sourceId: topicId,
      metadata: {'subject': subject, 'cardsReviewed': cardsReviewed},
    );

    // 3. Update daily study streak
    await _updateStreak(now);

    // 4. Emit real-time telemetry update event
    _notifyAnalyticsUpdated();
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
      } else if (diffDays == 2 && getStreakFreezes() > 0) {
        await consumeStreakFreeze();
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

    // Sync updated streak to backend so leaderboard updates in real-time
    _syncProgressToBackend();

    _notifyStreakMilestone(currentStreak);
  }

  void _notifyStreakMilestone(int streak) {
    const milestones = {3, 7, 14, 30, 60, 100, 365};
    if (!milestones.contains(streak)) return;
    try {
      if (!locator.isRegistered<NotificationService>()) return;
      final notifs = locator<NotificationService>();
      final (title, body) = switch (streak) {
        3 => (
            '🔥 3-Day Streak!',
            'You studied 3 days in a row. Keep it up — the habit is forming!',
          ),
        7 => (
            '🏅 One Week Streak!',
            'A full week of studying! Your memory retention is compounding fast.',
          ),
        14 => (
            '💪 Two-Week Warrior!',
            '14 consecutive days. Your brain is rewiring for mastery. Incredible!',
          ),
        30 => (
            '🌙 30-Day Scholar!',
            'A whole month of daily study. WAEC/JAMB mastery is within reach!',
          ),
        60 => (
            '⚡ 60-Day Legend!',
            '60 days straight — you are in the top 1% of all Kortex scholars.',
          ),
        100 => (
            '🏆 Century Streak!',
            '100 days of relentless studying. You are unstoppable. Keep pushing!',
          ),
        365 => (
            '🌟 One-Year Champion!',
            'A full year of daily study! The Kortex Scholar Award is yours — infinite respect!',
          ),
        _ => (
            '🔥 Streak Milestone!',
            'You hit a $streak-day streak! Keep going!',
          ),
      };

      unawaited(
        notifs.showLocalNotification(
          id: 9_000_000 + streak,
          title: title,
          body: body,
          channelId: NotificationService.channelStreak,
        ),
      );
    } on Object catch (_) {}
  }

  @override
  int getCurrentStreak() {
    final raw = _localStorageService.getPreference(key: _streakCurrentKey);
    if (raw == null || raw.isEmpty) return 0;
    final streak = int.tryParse(raw) ?? 0;

    final lastDateStr = _localStorageService.getPreference(
      key: _lastStudyDateKey,
    );
    if (lastDateStr != null && lastDateStr.isNotEmpty && streak > 0) {
      final todayKey = _toDateKey(DateTime.now());
      final lastDate = _parseDate(lastDateStr);
      final todayDate = _parseDate(todayKey);
      final diffDays = todayDate.difference(lastDate).inDays;
      if (diffDays > 1) {
        if (diffDays == 2 && getStreakFreezes() > 0) {
          return streak;
        }
        return 0;
      }
    }

    return streak;
  }

  @override
  bool hasStudiedToday() {
    final lastDateStr = _localStorageService.getPreference(
      key: _lastStudyDateKey,
    );
    if (lastDateStr == null || lastDateStr.isEmpty) return false;
    return lastDateStr == _toDateKey(DateTime.now());
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
      total += (s['masteredCards'] as num?)?.toInt() ??
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
  int getBonusKarma() {
    final raw = _localStorageService.getPreference(key: _bonusKarmaKey);
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  @override
  Future<void> addBonusKarma(int amount) async {
    final current = getBonusKarma();
    await _localStorageService.savePreference(
      key: _bonusKarmaKey,
      data: (current + amount).toString(),
    );
  }

  @override
  int getXpPoints() {
    // _directXpAccumulatedKey is the single source of truth — every awardXp()
    // call already writes into it. We do NOT re-sum sessions here to avoid
    // double-counting with direct XP awards.
    final directXp = _getDirectXpAccumulated();
    final streak = getCurrentStreak();
    final bonusKarma = getBonusKarma();
    final totalEarned = directXp + (streak * 30) + bonusKarma;
    return (totalEarned - getSpentXp()).clamp(0, 9999999);
  }

  @override
  int getLevelForXp(int xp) {
    if (xp <= 0) return 1;
    final rawLevel = math.pow(xp / 100.0, 1.0 / 1.4).floor() + 1;
    return math.max(1, rawLevel);
  }

  @override
  int getXpForLevel(int level) {
    if (level <= 1) return 0;
    return (100 * math.pow(level, 1.4)).round();
  }

  @override
  String getAvatarFrameForLevel(int level) {
    if (level >= 15) return 'Diamond Scholar Frame';
    if (level >= 10) return 'Gold Alchemist Frame';
    if (level >= 5) return 'Emerald Novice Frame';
    return 'Bronze Pioneer Frame';
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

    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final startMonday = currentMonday.subtract(const Duration(days: 21));

    return List.generate(28, (i) {
      final day = startMonday.add(Duration(days: i));
      final key = _toDateKey(day);
      final entry = map[key];
      final cards = entry?.cards ?? 0;
      final seconds = entry?.seconds ?? 0;
      final minutes = seconds > 0 ? math.max(1, (seconds / 60).round()) : 0;

      var intensityLevel = 0;
      if (day.isAfter(today)) {
        intensityLevel = 0;
      } else if (cards >= 30 || minutes >= 25) {
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
