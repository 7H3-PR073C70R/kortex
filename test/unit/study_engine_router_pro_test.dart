import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/offline_ai/offline_ai.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}
class MockLocalInferenceIsolateManager extends Mock
    implements LocalInferenceIsolateManager {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  late MockConnectivity mockConnectivity;
  late MockLocalInferenceIsolateManager mockIsolateManager;
  late MockLocalStorageService mockLocal;
  late MockUserStorageService mockUser;
  late SubscriptionGuard subscriptionGuard;

  setUp(() {
    mockConnectivity = MockConnectivity();
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
        isolateManager: mockIsolateManager,
        subscriptionGuard: subscriptionGuard,
      );

      final mode = await router.getExecutionMode();
      expect(mode, equals(StudyEngineExecutionMode.cloudRemote));
    });

    test('Online Free user: Routes to offlineOnDevice without 1.5GB download locks', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.wifi],
      );
      when(() => mockUser.isProSubscriber()).thenReturn(false);

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
        isolateManager: mockIsolateManager,
        subscriptionGuard: subscriptionGuard,
      );

      final mode = await router.getExecutionMode();
      expect(mode, equals(StudyEngineExecutionMode.offlineOnDevice));
    });

    test('Offline Free or Pro user: Always routes to offlineOnDevice', () async {
      when(() => mockConnectivity.checkConnectivity()).thenAnswer(
        (_) async => [ConnectivityResult.none],
      );
      when(() => mockUser.isProSubscriber()).thenReturn(false);

      final router = StudyEngineRouter(
        connectivity: mockConnectivity,
        isolateManager: mockIsolateManager,
        subscriptionGuard: subscriptionGuard,
      );

      final mode = await router.getExecutionMode();
      expect(mode, equals(StudyEngineExecutionMode.offlineOnDevice));
    });
  });
}
