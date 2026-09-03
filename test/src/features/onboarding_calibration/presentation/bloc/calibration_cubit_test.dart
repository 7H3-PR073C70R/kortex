import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/save_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_state.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveCalibrationProfileUseCase extends Mock
    implements SaveCalibrationProfileUseCase {}

void main() {
  late MockSaveCalibrationProfileUseCase mockSaveUseCase;

  setUpAll(() {
    registerFallbackValue(const CalibrationProfile());
  });

  setUp(() {
    mockSaveUseCase = MockSaveCalibrationProfileUseCase();
  });

  group('CalibrationCubit Test Suite', () {
    test('initial state has default higherEducation focus and step 0', () {
      final cubit = CalibrationCubit(
        saveCalibrationProfileUseCase: mockSaveUseCase,
      );
      expect(cubit.state.currentStepIndex, equals(0));
      expect(cubit.state.profile.focus, equals(AcademicFocus.higherEducation));
      expect(cubit.state.status, equals(CalibrationStatus.initial));
    });

    blocTest<CalibrationCubit, CalibrationState>(
      'setAcademicFocus updates focus and triggers branching',
      build: () => CalibrationCubit(
        saveCalibrationProfileUseCase: mockSaveUseCase,
      ),
      act: (cubit) => cubit.setAcademicFocus(AcademicFocus.highSchool),
      expect: () => [
        const CalibrationState(
          profile: CalibrationProfile(focus: AcademicFocus.highSchool),
        ),
      ],
    );

    blocTest<CalibrationCubit, CalibrationState>(
      'toggleHigherEdGoal adds and removes multiselect goals correctly',
      build: () => CalibrationCubit(
        saveCalibrationProfileUseCase: mockSaveUseCase,
      ),
      act: (cubit) => cubit
        ..toggleHigherEdGoal('Thesis')
        ..toggleHigherEdGoal('Thesis'),
      expect: () => [
        const CalibrationState(
          profile: CalibrationProfile(
            higherEdGoals: ['Thesis'],
          ),
        ),
        const CalibrationState(),
      ],
    );

    blocTest<CalibrationCubit, CalibrationState>(
      'step navigation updates currentStepIndex and trajectory',
      build: () => CalibrationCubit(
        saveCalibrationProfileUseCase: mockSaveUseCase,
      ),
      act: (cubit) => cubit
        ..nextStep()
        ..nextStep()
        ..previousStep(),
      expect: () => [
        const CalibrationState(
          currentStepIndex: 1,
        ),
        const CalibrationState(
          currentStepIndex: 2,
        ),
        const CalibrationState(
          currentStepIndex: 1,
          isForwardTrajectory: false,
        ),
      ],
    );

    blocTest<CalibrationCubit, CalibrationState>(
      'finishCalibration calls useCase and transitions to completed',
      build: () {
        when(
          () => mockSaveUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        return CalibrationCubit(
          saveCalibrationProfileUseCase: mockSaveUseCase,
        );
      },
      act: (cubit) => cubit.finishCalibration(),
      expect: () => [
        const CalibrationState(
          status: CalibrationStatus.submitting,
        ),
        const CalibrationState(
          status: CalibrationStatus.completed,
          profile: CalibrationProfile(isCalibrated: true),
        ),
      ],
    );
  });
}
