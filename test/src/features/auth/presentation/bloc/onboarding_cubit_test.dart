import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/onboarding_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockCompleteOnboardingUseCase extends Mock
    implements CompleteOnboardingUseCase {}

void main() {
  late MockCompleteOnboardingUseCase mockUseCase;
  late OnboardingCubit cubit;

  const tProfile = UserProfileEntity(
    id: 'user_123',
    email: 'student@university.edu',
    targetTrack: 'JAMB',
    dailyCardTarget: 25,
    isOnboarded: true,
  );

  setUp(() {
    mockUseCase = MockCompleteOnboardingUseCase();
    cubit = OnboardingCubit(completeOnboardingUseCase: mockUseCase);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('OnboardingCubit Test Suite', () {
    test('initial state has step 0 and WAEC track', () {
      expect(cubit.state.currentStep, 0);
      expect(cubit.state.selectedTrack, 'WAEC');
      expect(cubit.state.dailyTarget, 20);
    });

    test('selectTrack updates selectedTrack and default dailyTarget', () {
      cubit.selectTrack('JAMB');
      expect(cubit.state.selectedTrack, 'JAMB');
      expect(cubit.state.dailyTarget, 25);
    });

    test('nextStep and previousStep adjust currentStep', () {
      cubit.nextStep();
      expect(cubit.state.currentStep, 1);
      cubit.nextStep();
      expect(cubit.state.currentStep, 2);
      cubit.previousStep();
      expect(cubit.state.currentStep, 1);
    });

    blocTest<OnboardingCubit, OnboardingState>(
      'completeOnboarding emits loading -> completed on success',
      build: () {
        when(
          () => mockUseCase(
            track: 'WAEC',
            dailyTarget: 20,
          ),
        ).thenAnswer((_) async => const Right(tProfile));
        return cubit;
      },
      act: (cubit) => cubit.completeOnboarding(),
      expect: () => [
        const OnboardingState(status: OnboardingStatus.loading),
        const OnboardingState(
          status: OnboardingStatus.completed,
          completedProfile: tProfile,
        ),
      ],
    );
  });
}
