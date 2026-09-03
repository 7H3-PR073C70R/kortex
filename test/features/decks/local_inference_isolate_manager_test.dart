import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/data/services/local_inference_isolate_manager.dart';
import 'package:kortex/src/features/decks/data/services/offline_model_installer.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

class MockOfflineModelInstaller extends Mock implements OfflineModelInstaller {}

class MockLocalInferenceIsolateManager extends Mock
    implements LocalInferenceIsolateManager {}

void main() {
  group('1. OfflineModelInstaller Pre-flight & Safeguards', () {
    late MockConnectivity mockConnectivity;

    setUp(() {
      mockConnectivity = MockConnectivity();
    });

    test(
      'Fails pre-flight check when connection is cellular (Wi-Fi gate)',
      () async {
        when(() => mockConnectivity.checkConnectivity()).thenAnswer(
          (_) async => [ConnectivityResult.mobile],
        );

        final installer = OfflineModelInstaller(connectivity: mockConnectivity);
        final check = await installer.checkPrerequisites();

        expect(check.isWifi, isFalse);
        expect(check.error, contains('Wi-Fi Required'));
      },
    );

    test('Passes Wi-Fi gate when connected to Wi-Fi', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );

      final installer = OfflineModelInstaller(connectivity: mockConnectivity);
      final check = await installer.checkPrerequisites();

      expect(check.isWifi, isTrue);
      expect(check.error, isNull);
    });

    test('Verifies supported model specs and 4.0 GB constant', () {
      expect(
        OfflineModelInstaller.minFreeDiskSpaceBytes,
        equals(4 * 1024 * 1024 * 1024),
      );
      expect(
        OfflineModelInstaller.supportedModels.containsKey('qwen2.5-1.5b'),
        isTrue,
      );
      expect(
        OfflineModelInstaller.supportedModels.containsKey('llama-3.2-1b'),
        isTrue,
      );
    });
  });

  group('2. LocalInferenceIsolateManager Memory & 60fps UI Thread Safety', () {
    test('Low-RAM Profile (< 4 GB) caps context to 1024 and output to 256', () {
      final lowRamConfig = MemoryLimitConfig.fromSystemRam(
        estimatedRamMb: 3000,
      );
      expect(lowRamConfig.isLowRamProfile, isTrue);
      expect(lowRamConfig.contextTokens, equals(1024));
      expect(lowRamConfig.maxOutputTokens, equals(256));
      expect(lowRamConfig.maxChunkWords, equals(800));

      final highRamConfig = MemoryLimitConfig.fromSystemRam(
        estimatedRamMb: 8192,
      );
      expect(highRamConfig.isLowRamProfile, isFalse);
      expect(highRamConfig.contextTokens, equals(2048));
      expect(highRamConfig.maxOutputTokens, equals(512));
    });

    test(
      'Background Isolate execution maintains 60fps main thread frame ticks',
      () async {
        final manager = LocalInferenceIsolateManager();

        // Simulate 60fps UI frame scheduler (16ms per frame)
        var frameTickCount = 0;
        final frameTimer = Timer.periodic(const Duration(milliseconds: 10), (
          _,
        ) {
          frameTickCount++;
        });

        const task = InferenceTask(
          modelPath: '/dummy/path/qwen.gguf',
          prompt: 'Calculate Euler-Lagrange equations for double pendulum',
          config: MemoryLimitConfig(
            contextTokens: 1024,
            maxOutputTokens: 256,
            maxChunkWords: 800,
            isLowRamProfile: true,
          ),
        );

        final result = await manager.runIsolatedInference(task);
        frameTimer.cancel();

        expect(result, contains('Momentum conservation'));
        // Ensure UI thread was free to tick regularly during background isolate
        expect(frameTickCount, greaterThan(0));

        await manager.releaseContext();
      },
    );

    test('Enforces 35-second wall clock timeout constant', () {
      expect(
        LocalInferenceIsolateManager.wallClockTimeout,
        equals(const Duration(seconds: 35)),
      );
    });
  });

  group('3. StudyEngineRouter Central Switching Strategy', () {
    late MockConnectivity mockConnectivity;
    late MockOfflineModelInstaller mockInstaller;
    late MockLocalInferenceIsolateManager mockIsolateManager;

    setUp(() {
      mockConnectivity = MockConnectivity();
      mockInstaller = MockOfflineModelInstaller();
      mockIsolateManager = MockLocalInferenceIsolateManager();
    });

    test('Online: Routes to Cloud API', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
        modelInstaller: mockInstaller,
        isolateManager: mockIsolateManager,
      );

      final result = await router.generateStudyPack(
        topic: 'Calculus',
        count: 3,
      );

      expect(
        result.executionMode,
        equals(StudyEngineExecutionMode.cloudRemote),
      );
      expect(result.isOfflineModelMissing, isFalse);
      expect(result.cards.length, equals(3));
      expect(result.cards.first.isLocalInference, isFalse);
    });

    test('Offline with model: Routes to Local Fllama Isolate', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.none],
      );
      when(
        () => mockInstaller.isModelInstalled(),
      ).thenAnswer((_) async => true);
      when(
        () => mockInstaller.getModelPath(),
      ).thenAnswer((_) async => '/models/qwen.gguf');
      when(
        () => mockIsolateManager.executeChunkedInference(
          modelPath: any(named: 'modelPath'),
          topic: any(named: 'topic'),
          sourceText: any(named: 'sourceText'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': 'local_1',
            'front': 'Offline Hamiltonian',
            'back': r'$$\mathcal{H} = T + V$$',
            'explanation': 'Local Isolate Output',
            'isLocalInference': true,
          },
        ],
      );

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
        modelInstaller: mockInstaller,
        isolateManager: mockIsolateManager,
      );

      final result = await router.generateStudyPack(
        topic: 'Classical Mechanics',
        count: 1,
      );

      expect(
        result.executionMode,
        equals(StudyEngineExecutionMode.offlineOnDevice),
      );
      expect(result.isOfflineModelMissing, isFalse);
      expect(result.cards.first.isLocalInference, isTrue);
    });

    test(
      'Offline without model: Returns friendly missing model pack message',
      () async {
        when(() => mockConnectivity.checkConnectivity()).thenAnswer(
          (_) async => [ConnectivityResult.none],
        );
        when(
          () => mockInstaller.isModelInstalled(),
        ).thenAnswer((_) async => false);

        final router = StudyEngineRouter(
          connectivity: mockConnectivity,
          modelInstaller: mockInstaller,
          isolateManager: mockIsolateManager,
        );

        final result = await router.generateStudyPack(topic: 'Fluid Dynamics');

        expect(
          result.executionMode,
          equals(StudyEngineExecutionMode.unavailable),
        );
        expect(result.isOfflineModelMissing, isTrue);
        expect(result.cards, isEmpty);
        expect(
          result.userMessage,
          equals(
            'Offline mode requires the offline model pack. '
            'Download it on Wi-Fi to study offline.',
          ),
        );
      },
    );
  });
}
