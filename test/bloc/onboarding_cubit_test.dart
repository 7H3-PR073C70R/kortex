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
  group('OnboardingCubit Bi-Directional Mode Switching & Sync Test Suite', () {
    late MockCompleteOnboardingUseCase mockCompleteOnboardingUseCase;

    const tProfile = UserProfileEntity(
      id: 'user_123',
      email: 'student@kortex.app',
      targetTrack: 'JAMB',
      dailyCardTarget: 25,
      isOnboarded: true,
    );

    setUp(() {
      mockCompleteOnboardingUseCase = MockCompleteOnboardingUseCase();
    });

    OnboardingCubit buildCubit() => OnboardingCubit(
          completeOnboardingUseCase: mockCompleteOnboardingUseCase,
        );

    test('initial state defaults to Chat mode, step 0, and WAEC track',
        () async {
      final cubit = buildCubit();
      expect(cubit.state.activeMode, equals(OnboardingMode.chat));
      expect(cubit.state.currentStep, equals(0));
      expect(cubit.state.selectedTrack, equals('WAEC'));
      expect(cubit.state.dailyTarget, equals(20));
      await cubit.close();
    });

    blocTest<OnboardingCubit, OnboardingState>(
      'toggleMode seamlessly switches from Chat to Form mode and back',
      build: buildCubit,
      act: (cubit) {
        cubit
          ..toggleMode() // To Form
          ..toggleMode(); // Back to Chat
      },
      expect: () => [
        const OnboardingState(activeMode: OnboardingMode.form),
        const OnboardingState(),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'selectTrack updates selectedTrack and syncs default dailyTarget',
      build: buildCubit,
      act: (cubit) => cubit.selectTrack('JAMB'),
      expect: () => [
        const OnboardingState(
          selectedTrack: 'JAMB',
          dailyTarget: 25,
        ),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'syncStep clamps step index between 0 and 2',
      build: buildCubit,
      act: (cubit) {
        cubit
          ..syncStep(1)
          ..syncStep(5);
      },
      expect: () => [
        const OnboardingState(currentStep: 1),
        const OnboardingState(currentStep: 2),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'completeOnboarding persists profile and emits completed status',
      build: () {
        when(
          () => mockCompleteOnboardingUseCase(
            track: 'JAMB',
            dailyTarget: 30,
            retentionBenchmark: 0.90,
          ),
        ).thenAnswer((_) async => const Right(tProfile));
        return buildCubit();
      },
      seed: () => const OnboardingState(
        selectedTrack: 'JAMB',
        dailyTarget: 30,
        retentionBenchmark: 0.90,
      ),
      act: (cubit) => cubit.completeOnboarding(),
      expect: () => [
        const OnboardingState(
          selectedTrack: 'JAMB',
          dailyTarget: 30,
          retentionBenchmark: 0.90,
          status: OnboardingStatus.loading,
        ),
        const OnboardingState(
          selectedTrack: 'JAMB',
          dailyTarget: 30,
          retentionBenchmark: 0.90,
          status: OnboardingStatus.completed,
          completedProfile: tProfile,
        ),
      ],
    );
  });
}
