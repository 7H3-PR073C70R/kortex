import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/data/models/study_deck_model.dart';

abstract class DashboardRemoteDataSource {
  Future<DashboardFeedModel> getDashboardFeed();

  Future<List<StudyDeckModel>> getReviewQueue();

  Future<String> startMockExam({
    required String examId,
    required String subject,
  });

  Future<List<CuratedCourseModel>> getCatalogCourses();

  Future<void> syncUserCourses(List<Map<String, dynamic>> courses);

  Future<void> autoCurateExamCourses({
    required String examName,
    required List<String> subjects,
  });

  Future<void> deleteCuratedCourse(String courseId);

  Future<void> deleteAllCuratedCourses();
}
