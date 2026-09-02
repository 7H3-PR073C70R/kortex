// ignore_for_file: one_member_abstracts, Data source contract

import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';

abstract class ContentRecommendationDataSource {
  List<RecommendedContentItem> generateRecommendations({
    required CalibrationProfile profile,
    required String Function(String key, Map<String, dynamic> params)
        localizeHandler,
  });
}

class ContentRecommendationDataSourceImpl
    implements ContentRecommendationDataSource {
  const ContentRecommendationDataSourceImpl();

  @override
  List<RecommendedContentItem> generateRecommendations({
    required CalibrationProfile profile,
    required String Function(String key, Map<String, dynamic> params)
        localizeHandler,
  }) {
    final isHigherEd = profile.focus == AcademicFocus.higherEducation;

    // 1. Past Papers Item
    final examType = !isHigherEd && profile.highSchoolExam != null
        ? profile.highSchoolExam!
        : 'Final Exams';
    final subjectsList = !isHigherEd && profile.highSchoolSubjects.isNotEmpty
        ? profile.highSchoolSubjects.take(3).join(', ')
        : (profile.higherEdField ?? 'Core Academic Modules');

    final pastPapersDesc = localizeHandler('pastPapersDesc', {
      'examType': examType,
      'subjects': subjectsList,
    });
    final pastPapersBadge = localizeHandler('badgeCurated', {});
    final pastPapersTagline = localizeHandler('pastPapersTagline', {});

    final item1 = RecommendedContentItem(
      id: 'rec_past_papers',
      type: RecommendationType.pastPapers,
      badge: pastPapersBadge,
      tagline: pastPapersTagline,
      description: pastPapersDesc,
      formulaChips: [
        'Q-Bank: $examType',
        'Verified Past Papers',
        '98.4% Syllabus Match',
        'Step-by-Step Solutions',
      ],
    );

    // 2. Flashcards Item
    final fieldOfStudy = isHigherEd && profile.higherEdField != null
        ? profile.higherEdField!
        : (profile.highSchoolSubjects.isNotEmpty
            ? profile.highSchoolSubjects.first
            : 'Core Subject Concepts');

    final flashcardsDesc = localizeHandler('flashcardsDesc', {
      'field': fieldOfStudy,
    });
    final flashcardsTagline = localizeHandler('flashcardsTagline', {
      'field': fieldOfStudy,
    });
    final flashcardsBadge = localizeHandler('badgeActiveRecall', {});

    final item2 = RecommendedContentItem(
      id: 'rec_flashcards',
      type: RecommendationType.flashcards,
      badge: flashcardsBadge,
      tagline: flashcardsTagline,
      description: flashcardsDesc,
      formulaChips: const [
        'SM-2 Active Recall',
        'Spaced Repetition',
        'High-Yield Decks',
        'Mastery Retention Curve',
      ],
    );

    // 3. Socratic AI Tutoring Item
    final levelName = isHigherEd && profile.higherEdLevel != null
        ? profile.higherEdLevel!.name.toUpperCase()
        : 'Exam Prep';
    final socraticDesc = localizeHandler('socraticDesc', {
      'level': levelName,
      'field': fieldOfStudy,
    });
    final socraticTagline = localizeHandler('socraticTagline', {});
    final socraticBadge = localizeHandler('badgeSocratic', {});

    final item3 = RecommendedContentItem(
      id: 'rec_socratic',
      type: RecommendationType.socraticAi,
      badge: socraticBadge,
      tagline: socraticTagline,
      description: socraticDesc,
      formulaChips: const [
        'Syllabot AI Tutor',
        'Deep Step Proofs',
        'Adaptive Calibration',
        '24/7 Study Companion',
      ],
    );

    return [item1, item2, item3];
  }
}
