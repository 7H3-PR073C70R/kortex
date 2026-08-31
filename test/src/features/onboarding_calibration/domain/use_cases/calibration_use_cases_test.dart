import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/get_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/save_calibration_profile_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockCalibrationRepository extends Mock
    implements CalibrationRepository {}

void main() {
  late MockCalibrationRepository mockRepository;
  late SaveCalibrationProfileUseCase saveUseCase;
  late GetCalibrationProfileUseCase getUseCase;

  const testProfile = CalibrationProfile(
    higherEdLevel: HigherEdLevel.bsc,
    higherEdField: 'Mathematics & Data Science',
    higherEdGoals: ['Thesis / Dissertation Support'],
    isCalibrated: true,
  );

  setUp(() {
    mockRepository = MockCalibrationRepository();
    saveUseCase = SaveCalibrationProfileUseCase(mockRepository);
    getUseCase = GetCalibrationProfileUseCase(mockRepository);
  });

  group('Calibration UseCases Test Suite', () {
    test('SaveCalibrationProfileUseCase saves profile successfully', () async {
      when(() => mockRepository.saveCalibrationProfile(testProfile))
          .thenAnswer((_) async => const Right(null));

      final result = await saveUseCase(testProfile);

      expect(result.isRight, isTrue);
      verify(() => mockRepository.saveCalibrationProfile(testProfile))
          .called(1);
    });

    test('SaveCalibrationProfileUseCase returns Failure on error', () async {
      when(() => mockRepository.saveCalibrationProfile(testProfile))
          .thenAnswer((_) async =>
              const Left(ServerFailure(message: 'Disk Error')));

      final result = await saveUseCase(testProfile);

      expect(result.isLeft, isTrue);
      result.fold(
        (failure) => expect(failure.message, equals('Disk Error')),
        (_) => fail('Should be left'),
      );
    });

    test('GetCalibrationProfileUseCase returns profile successfully', () async {
      when(() => mockRepository.getCalibrationProfile())
          .thenAnswer((_) async => const Right(testProfile));

      final result = await getUseCase(const NoParams());

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Should be right'),
        (profile) {
          expect(profile, isNotNull);
          expect(profile!.focus, equals(AcademicFocus.higherEducation));
          expect(profile.higherEdLevel, equals(HigherEdLevel.bsc));
        },
      );
      verify(() => mockRepository.getCalibrationProfile()).called(1);
    });
  });
}
