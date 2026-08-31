import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/offline_ai/domain/logic/experimental_offline_guard.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  group('ExperimentalOfflineGuard Hardware & Sandbox Test Suite', () {
    late MockConnectivity mockConnectivity;

    setUp(() {
      mockConnectivity = MockConnectivity();
    });

    test('Throws OfflineAiDisabledException when toggle is disabled', () async {
      final guard = ExperimentalOfflineGuard(
        connectivity: mockConnectivity,
        overrideDeviceRamMb: 8192,
      );

      const settings = OfflineAiUserSettings();

      expect(
        () => guard.preflightCheck(userSettings: settings),
        throwsA(isA<OfflineAiDisabledException>()),
      );
    });

    test('Throws LowMemoryDeviceException when physical RAM is < 6.0 GB',
        () async {
      final guard = ExperimentalOfflineGuard(
        connectivity: mockConnectivity,
        overrideDeviceRamMb: 4096, // 4 GB RAM < 6 GB requirement
      );

      const settings = OfflineAiUserSettings(
        enableExperimentalOfflineAI: true,
      );

      expect(
        () => guard.preflightCheck(userSettings: settings),
        throwsA(isA<LowMemoryDeviceException>()),
      );
    });

    test('Throws MeteredNetworkException when downloading on cellular',
        () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.mobile],
      );

      final guard = ExperimentalOfflineGuard(
        connectivity: mockConnectivity,
        overrideDeviceRamMb: 8192,
      );

      const settings = OfflineAiUserSettings(
        enableExperimentalOfflineAI: true,
      );

      expect(
        () => guard.preflightCheck(
          userSettings: settings,
          isDownloadAction: true,
        ),
        throwsA(isA<MeteredNetworkException>()),
      );
    });

    test('Passes all pre-flight checks when RAM >= 6GB, toggle on, and Wi-Fi',
        () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );

      final guard = ExperimentalOfflineGuard(
        connectivity: mockConnectivity,
        overrideDeviceRamMb: 8192,
      );

      const settings = OfflineAiUserSettings(
        enableExperimentalOfflineAI: true,
      );

      await expectLater(
        guard.preflightCheck(
          userSettings: settings,
          isDownloadAction: true,
        ),
        completes,
      );
    });

    test('Executes sandboxed inference and returns fallback on low memory',
        () async {
      final guard = ExperimentalOfflineGuard(
        connectivity: mockConnectivity,
        overrideDeviceRamMb: 3000,
      );

      const settings = OfflineAiUserSettings(
        enableExperimentalOfflineAI: true,
      );

      final result = await guard.executeSandboxedInference(
        prompt: 'Derive Lagrange equation',
        modelPath: '/models/qwen.gguf',
        userSettings: settings,
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.fallbackMessage,
        equals(ExperimentalOfflineGuard.resourceFallbackMessage),
      );
    });
  });
}
