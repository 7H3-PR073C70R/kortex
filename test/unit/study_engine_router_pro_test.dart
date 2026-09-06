import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/offline_ai/offline_ai.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}
class MockOfflineModelInstaller extends Mock implements OfflineModelInstaller {}
class MockLocalInferenceIsolateManager extends Mock
    implements LocalInferenceIsolateManager {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  late MockConnectivity mockConnectivity;
  late MockOfflineModelInstaller mockInstaller;
  late MockLocalInferenceIsolateManager mockIsolateManager;
  late MockLocalStorageService mockLocal;
  late MockUserStorageService mockUser;
  late SubscriptionGuard subscriptionGuard;

  setUp(() {
    mockConnectivity = MockConnectivity();
    mockInstaller = MockOfflineModelInstaller();
    mockIsolateManager = MockLocalInferenceIsolateManager();
    mockLocal = MockLocalStorageService();
    mockUser = MockUserStorageService();

    subscriptionGuard = SubscriptionGuard(
      userStorageService: mockUser,
      localStorageService: mockLocal,
    );
  });

  group('StudyEngineRouter Pro Gating & Free Local AI Fallback Suite', () {
    test('Online Pro user: Routes to cloudRemote', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );
      when(() => mockUser.isProSubscriber()).thenReturn(true);

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
        modelInstaller: mockInstaller,
        isolateManager: mockIsolateManager,
        subscriptionGuard: subscriptionGuard,
      );

      final mode = await router.getExecutionMode();
      expect(mode, equals(StudyEngineExecutionMode.cloudRemote));
    });

    test('Online Free user with local model: Falls back to offlineOnDevice (free AI access)', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );
      when(() => mockUser.isProSubscriber()).thenReturn(false);
      when(() => mockInstaller.isModelInstalled()).thenAnswer((_) async => true);

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
        modelInstaller: mockInstaller,
        isolateManager: mockIsolateManager,
        subscriptionGuard: subscriptionGuard,
      );

      final mode = await router.getExecutionMode();
      expect(mode, equals(StudyEngineExecutionMode.offlineOnDevice));
    });

    test('Online Free user without local model: Returns unavailable with Pro upgrade guidance', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );
      when(() => mockUser.isProSubscriber()).thenReturn(false);
      when(() => mockInstaller.isModelInstalled()).thenAnswer((_) async => false);

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
        modelInstaller: mockInstaller,
        isolateManager: mockIsolateManager,
        subscriptionGuard: subscriptionGuard,
      );

      final mode = await router.getExecutionMode();
      expect(mode, equals(StudyEngineExecutionMode.unavailable));

      final result = await router.generateStudyPack(topic: 'Physics 101');
      expect(result.executionMode, equals(StudyEngineExecutionMode.unavailable));
      expect(result.isOfflineModelMissing, isTrue);
      expect(result.userMessage, equals(StudyEngineRouter.cloudAiRequiresProPrompt));
    });
  });
}
