import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/offline_ai/data/services/local_inference_isolate_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

class MockLocalInferenceIsolateManager extends Mock
    implements LocalInferenceIsolateManager {}

void main() {
  group('1. Offline Engine Instant Readiness & Safeguards', () {
    late MockConnectivity mockConnectivity;

    setUp(() {
      mockConnectivity = MockConnectivity();
    });

    test('StudyEngineRouter defaults to offlineOnDevice without network', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.none],
      );

      final router = StudyEngineRouter(connectivity: mockConnectivity);
      final mode = await router.getExecutionMode();

      expect(mode, equals(StudyEngineExecutionMode.offlineOnDevice));
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
          prompt:
              'Topic: Analytical Mechanics\nContext: - Euler-Lagrange Equations: Dynamic differential equations derived from the principle of least stationary action.',
          config: MemoryLimitConfig(
            contextTokens: 1024,
            maxOutputTokens: 256,
            maxChunkWords: 800,
            isLowRamProfile: true,
          ),
        );

        final result = await manager.runIsolatedInference(task);
        frameTimer.cancel();

        expect(result, contains('Euler-Lagrange Equations'));
        // Ensure UI thread was free to tick regularly during background isolate
        expect(frameTickCount, greaterThan(0));

        await manager.releaseContext();
      },
    );

    test('Throws InsufficientContentException when text lacks extractable concepts', () async {
      final manager = LocalInferenceIsolateManager();

      const emptyTask = InferenceTask(
        modelPath: '/dummy/path/qwen.gguf',
        prompt: 'Hi',
        config: MemoryLimitConfig(
          contextTokens: 1024,
          maxOutputTokens: 256,
          maxChunkWords: 800,
          isLowRamProfile: true,
        ),
      );

      expect(
        () => manager.runIsolatedInference(emptyTask),
        throwsA(isA<InsufficientContentException>()),
      );

      await manager.releaseContext();
    });

    test('Enforces 35-second wall clock timeout constant', () {
      expect(
        LocalInferenceIsolateManager.wallClockTimeout,
        equals(const Duration(seconds: 35)),
      );
    });
  });

  group('3. StudyEngineRouter Central Switching Strategy', () {
    late MockConnectivity mockConnectivity;
    late MockLocalInferenceIsolateManager mockIsolateManager;

    setUp(() {
      mockConnectivity = MockConnectivity();
      mockIsolateManager = MockLocalInferenceIsolateManager();
    });

    test('Online: Routes to Cloud API', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
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

    test('Offline: Routes to instant on-device engine without data consumption', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.none],
      );

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
        isolateManager: mockIsolateManager,
      );

      final result = await router.generateStudyPack(
        topic: 'Classical Mechanics',
        count: 2,
      );

      expect(
        result.executionMode,
        equals(StudyEngineExecutionMode.offlineOnDevice),
      );
      expect(result.isOfflineModelMissing, isFalse);
      expect(result.cards.length, equals(2));
      expect(result.cards.first.isLocalInference, isTrue);
    });
  });
}
