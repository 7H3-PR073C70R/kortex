import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';

/// Abstract Domain Repository Contract for Kortex Dashboard operations.
abstract class DashboardRepository {
  /// Fetches the personalized dashboard feed based on active user calibration.
  Future<Either<Failure, DashboardFeedEntity>> getDashboardFeed();

  /// Fetches the active recall spaced repetition (SM-2) queue for today.
  Future<Either<Failure, List<StudyDeckEntity>>> getSm2ReviewQueue();

  /// Initiates an interactive mock exam or test simulator session.
  Future<Either<Failure, String>> quickStartMockExam({
    required String examId,
    required String subject,
  });

  /// Fetches the catalog of curated courses across all faculties & tracks.
  Future<Either<Failure, List<CuratedCourseEntity>>> getCatalogCourses();

  /// Synchronizes or enrolls the student into selected/custom courses.
  Future<Either<Failure, void>> syncUserCourses(
    List<Map<String, dynamic>> courses,
  );

  /// Automatically curates standardized lower exam subjects (WAEC, JAMB, SAT).
  Future<Either<Failure, void>> autoCurateExamCourses({
    required String examName,
    required List<String> subjects,
  });
}
