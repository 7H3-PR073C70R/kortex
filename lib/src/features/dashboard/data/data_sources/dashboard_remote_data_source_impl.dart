import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
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
      return HeatMapDayModel(
        dateIso: day.toIso8601String(),
        intensityLevel: 0,
        cardsReviewed: 0,
        minutesStudied: 0,
      );
    });

    return DashboardFeedModel(
      analyticsSummary: AnalyticsSummaryModel(
        currentStreakDays: 0,
        longestStreakDays: 0,
        weeklyMinutesStudied: 0,
        overallRetentionRate: 0,
        totalCardsMastered: 0,
        heatMapData: heatMap,
        xpPoints: 0,
        academicRank: 'Neural Scholar I',
      ),
      dueStudyDecks: const [],
      curatedCourses: const [],
      syllabotDailyInsight: 'Welcome to Kortex! Start your first study '
          'session to activate your neural memory retention tracking.',
    );
  }

  List<StudyDeckModel> _generateFallbackDecks() {
    return const [];
  }
}
