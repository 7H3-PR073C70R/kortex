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
      final feed = await _client.getDashboardFeed();
      if (liveAnalytics != null &&
          (liveAnalytics.currentStreakDays > 0 ||
              liveAnalytics.totalCardsMastered > 0)) {
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
    final analytics = liveAnalytics ??
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
        : 'Welcome to Kortex! Start your first study session to activate your neural memory retention tracking.';

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
}
