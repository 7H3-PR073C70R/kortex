import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/get_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/domain/use_cases/get_recommended_content_use_case.dart';
import 'package:kortex/src/features/onboarding_content/presentation/bloc/content_recommendation_cubit.dart';
import 'package:kortex/src/features/onboarding_content/presentation/bloc/content_recommendation_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGetRecommendedContentUseCase extends Mock
    implements GetRecommendedContentUseCase {}

class MockGetCalibrationProfileUseCase extends Mock
    implements GetCalibrationProfileUseCase {}

void main() {
  late MockGetRecommendedContentUseCase mockGetContentUseCase;
  late MockGetCalibrationProfileUseCase mockGetProfileUseCase;

  const testItems = [
    RecommendedContentItem(
      id: 'rec_1',
      type: RecommendationType.pastPapers,
      badge: 'DATABASE PRE-POPULATED',
      tagline: 'Instant Exam Readiness',
      description: 'Selected past papers',
      formulaChips: ['JAMB', 'WAEC'],
    ),
    RecommendedContentItem(
      id: 'rec_2',
      type: RecommendationType.flashcards,
      badge: 'ACTIVE RECALL DECK',
      tagline: 'Deep Mastery',
      description: 'Calculus flashcards',
      formulaChips: ['SM-2'],
    ),
  ];

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      GetRecommendationsParams(
        profile: const CalibrationProfile(),
        localizeHandler: (key, params) => '',
      ),
    );
  });

  setUp(() {
    mockGetContentUseCase = MockGetRecommendedContentUseCase();
    mockGetProfileUseCase = MockGetCalibrationProfileUseCase();
  });

  group('ContentRecommendationCubit Test Suite', () {
    test('initial state has empty items and status initial', () {
      final cubit = ContentRecommendationCubit(
        getRecommendedContentUseCase: mockGetContentUseCase,
        getCalibrationProfileUseCase: mockGetProfileUseCase,
      );
      expect(cubit.state.status, equals(ContentRecommendationStatus.initial));
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.currentIndex, equals(0));
    });

    blocTest<ContentRecommendationCubit, ContentRecommendationState>(
      'loadRecommendations emits [loading, loaded] with items on success',
      build: () {
        when(() => mockGetProfileUseCase(const NoParams()))
            .thenAnswer((_) async => const Right(CalibrationProfile()));
        when(() => mockGetContentUseCase(any()))
            .thenAnswer((_) async => const Right(testItems));
        return ContentRecommendationCubit(
          getRecommendedContentUseCase: mockGetContentUseCase,
          getCalibrationProfileUseCase: mockGetProfileUseCase,
        );
      },
      act: (cubit) => cubit.loadRecommendations(
        localizeHandler: (key, params) => '',
      ),
      expect: () => [
        const ContentRecommendationState(
          status: ContentRecommendationStatus.loading,
        ),
        const ContentRecommendationState(
          status: ContentRecommendationStatus.loaded,
          items: testItems,
        ),
      ],
    );

    blocTest<ContentRecommendationCubit, ContentRecommendationState>(
      'loadRecommendations emits [loading, error] on failure',
      build: () {
        when(() => mockGetProfileUseCase(const NoParams()))
            .thenAnswer((_) async => const Right(CalibrationProfile()));
        when(() => mockGetContentUseCase(any())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Error fetching')),
        );
        return ContentRecommendationCubit(
          getRecommendedContentUseCase: mockGetContentUseCase,
          getCalibrationProfileUseCase: mockGetProfileUseCase,
        );
      },
      act: (cubit) => cubit.loadRecommendations(
        localizeHandler: (key, params) => '',
      ),
      expect: () => [
        const ContentRecommendationState(
          status: ContentRecommendationStatus.loading,
        ),
        const ContentRecommendationState(
          status: ContentRecommendationStatus.error,
          errorMessage: 'Error fetching',
        ),
      ],
    );

    blocTest<ContentRecommendationCubit, ContentRecommendationState>(
      'onPageChanged updates currentIndex',
      build: () => ContentRecommendationCubit(
        getRecommendedContentUseCase: mockGetContentUseCase,
        getCalibrationProfileUseCase: mockGetProfileUseCase,
      ),
      seed: () => const ContentRecommendationState(
        status: ContentRecommendationStatus.loaded,
        items: testItems,
      ),
      act: (cubit) => cubit.onPageChanged(1),
      expect: () => [
        const ContentRecommendationState(
          status: ContentRecommendationStatus.loaded,
          items: testItems,
          currentIndex: 1,
        ),
      ],
    );
  });
}
