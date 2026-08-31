import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/domain/repositories/content_recommendation_repository.dart';
import 'package:kortex/src/features/onboarding_content/domain/use_cases/get_recommended_content_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockContentRecommendationRepository extends Mock
    implements ContentRecommendationRepository {}

void main() {
  late MockContentRecommendationRepository mockRepository;
  late GetRecommendedContentUseCase useCase;

  setUpAll(() {
    registerFallbackValue(const CalibrationProfile());
  });

  setUp(() {
    mockRepository = MockContentRecommendationRepository();
    useCase = GetRecommendedContentUseCase(mockRepository);
  });

  group('GetRecommendedContentUseCase Test Suite', () {
    const testItems = [
      RecommendedContentItem(
        id: 'rec_1',
        type: RecommendationType.pastPapers,
        badge: 'DATABASE PRE-POPULATED',
        tagline: 'Instant Exam Readiness',
        description: 'Selected past papers',
        formulaChips: ['JAMB', 'WAEC'],
      ),
    ];

    test('returns list of recommended items on success', () async {
      when(
        () => mockRepository.getRecommendations(
          profile: any(named: 'profile'),
          localizeHandler: any(named: 'localizeHandler'),
        ),
      ).thenAnswer((_) async => const Right(testItems));

      final result = await useCase(
        GetRecommendationsParams(
          profile: const CalibrationProfile(),
          localizeHandler: (key, params) => '',
        ),
      );

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Should be right'),
        (items) {
          expect(items.length, equals(1));
          expect(items.first.tagline, equals('Instant Exam Readiness'));
        },
      );
    });

    test('returns Failure when repository returns error', () async {
      when(
        () => mockRepository.getRecommendations(
          profile: any(named: 'profile'),
          localizeHandler: any(named: 'localizeHandler'),
        ),
      ).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'Error generating')),
      );

      final result = await useCase(
        GetRecommendationsParams(
          profile: const CalibrationProfile(),
          localizeHandler: (key, params) => '',
        ),
      );

      expect(result.isLeft, isTrue);
    });
  });
}
