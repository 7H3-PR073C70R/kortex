import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_local_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_remote_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/calibration_profile_model.dart';
import 'package:kortex/src/features/onboarding_calibration/data/repositories/calibration_repository_impl.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockCalibrationLocalDataSource extends Mock
    implements CalibrationLocalDataSource {}

class MockCalibrationRemoteDataSource extends Mock
    implements CalibrationRemoteDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CalibrationProfileModel(
        isCalibrated: true,
      ),
    );
  });

  group('Reinstall Data Sync & Persistence Integrity', () {
    test('UserActivityService restores streak, freezes, and XP from remote',
        () async {
      final inMemory = <String, String>{};
      final storage = MockLocalStorageService();

      when(() => storage.getPreference(key: any(named: 'key')))
          .thenAnswer((inv) => inMemory[inv.namedArguments[#key] as String]);
      when(
        () => storage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        inMemory[inv.namedArguments[#key] as String] =
            inv.namedArguments[#data] as String;
      });

      final service = UserActivityServiceImpl(storage);

      // Verify starting state on clean install is 0
      expect(service.getCurrentStreak(), 0);
      expect(service.getXpPoints(), 0);

      // Hydrate from remote profile (simulating login/reinstall)
      await service.hydrateFromRemote(
        streakDays: 14,
        longestStreakDays: 20,
        xpPoints: 1500,
        streakFreezes: 3,
        heatMapData: const [
          HeatMapDayModel(
            dateIso: '2026-10-01T00:00:00.000Z',
            intensityLevel: 3,
            cardsReviewed: 25,
            minutesStudied: 20,
          ),
        ],
      );

      expect(service.getCurrentStreak(), 14);
      expect(service.getLongestStreak(), 20);
      expect(service.getStreakFreezes(), 3);
      expect(service.getXpPoints(), greaterThanOrEqualTo(1500));
    });

    test('CalibrationRepository fetches from remote when local is empty',
        () async {
      final localDS = MockCalibrationLocalDataSource();
      final remoteDS = MockCalibrationRemoteDataSource();

      const remoteModel = CalibrationProfileModel(
        higherEdLevel: 'bsc',
        higherEdField: 'Computer Science',
        isCalibrated: true,
      );

      when(localDS.getCalibrationProfile)
          .thenAnswer((_) async => null);
      when(remoteDS.fetchCalibrationProfile)
          .thenAnswer((_) async => remoteModel);
      when(() => localDS.saveCalibrationProfile(any()))
          .thenAnswer((_) async {});

      final repo = CalibrationRepositoryImpl(
        localDataSource: localDS,
        remoteDataSource: remoteDS,
      );

      final result = await repo.getCalibrationProfile();

      expect(result.isRight, isTrue);
      final profile = result.fold((_) => null, (p) => p);
      expect(profile, isNotNull);
      expect(profile!.isCalibrated, isTrue);
      expect(profile.higherEdField, 'Computer Science');

      // Verify it was cached locally for offline continuity
      verify(() => localDS.saveCalibrationProfile(remoteModel)).called(1);
    });

    test('CalibrationRepository pushes to remote and local on save', () async {
      final localDS = MockCalibrationLocalDataSource();
      final remoteDS = MockCalibrationRemoteDataSource();

      when(() => localDS.saveCalibrationProfile(any()))
          .thenAnswer((_) async {});
      when(() => remoteDS.syncCalibrationProfile(any()))
          .thenAnswer((_) async {});

      final repo = CalibrationRepositoryImpl(
        localDataSource: localDS,
        remoteDataSource: remoteDS,
      );

      const entity = CalibrationProfile(
        higherEdField: 'Medicine',
        isCalibrated: true,
      );

      final result = await repo.saveCalibrationProfile(entity);

      expect(result.isRight, isTrue);
      verify(() => localDS.saveCalibrationProfile(any())).called(1);
      verify(() => remoteDS.syncCalibrationProfile(any())).called(1);
    });
  });
}
