import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/sync/app_sync_engine.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/auth_verify_otp_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/observe_auth_state_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/update_course_track_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSyncEngine extends Mock implements AppSyncEngine {}
class MockCardSyncQueue extends Mock implements CardSyncQueue {}
class MockQuizRepository extends Mock implements QuizRepository {}
class MockUserActivityService extends Mock implements UserActivityService {}
class MockCommunityRepository extends Mock implements CommunityRepository {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockUserStorageService extends Mock implements UserStorageService {}
class MockAuthRepository extends Mock implements AuthRepository {}
class MockLoginWithEmailUseCase extends Mock implements LoginWithEmailUseCase {}
class MockRegisterWithEmailUseCase extends Mock implements RegisterWithEmailUseCase {}
class MockLoginWithSocialUseCase extends Mock implements LoginWithSocialUseCase {}
class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}
class MockObserveAuthStateUseCase extends Mock implements ObserveAuthStateUseCase {}
class MockUpdateCourseTrackUseCase extends Mock implements UpdateCourseTrackUseCase {}
class MockAuthVerifyOtpUseCase extends Mock implements AuthVerifyOtpUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P3-02 · Verified Offline Data Flush on Logout', () {
    late MockAppSyncEngine mockAppSyncEngine;
    late MockCardSyncQueue mockCardSyncQueue;
    late MockQuizRepository mockQuizRepository;
    late MockUserActivityService mockUserActivityService;
    late MockCommunityRepository mockCommunityRepository;
    late MockLocalStorageService mockLocalStorageService;
    late MockUserStorageService mockUserStorageService;
    late MockAuthRepository mockAuthRepository;
    late StreamController<AuthSessionStatus> authStreamController;

    setUp(() async {
      mockAppSyncEngine = MockAppSyncEngine();
      mockCardSyncQueue = MockCardSyncQueue();
      mockQuizRepository = MockQuizRepository();
      mockUserActivityService = MockUserActivityService();
      mockCommunityRepository = MockCommunityRepository();
      mockLocalStorageService = MockLocalStorageService();
      mockUserStorageService = MockUserStorageService();
      mockAuthRepository = MockAuthRepository();

      authStreamController = StreamController<AuthSessionStatus>.broadcast();

      // Clean registration in locator
      if (locator.isRegistered<AppSyncEngine>()) await locator.unregister<AppSyncEngine>();
      if (locator.isRegistered<CardSyncQueue>()) await locator.unregister<CardSyncQueue>();
      if (locator.isRegistered<QuizRepository>()) await locator.unregister<QuizRepository>();
      if (locator.isRegistered<UserActivityService>()) await locator.unregister<UserActivityService>();
      if (locator.isRegistered<CommunityRepository>()) await locator.unregister<CommunityRepository>();
      if (locator.isRegistered<LocalStorageService>()) await locator.unregister<LocalStorageService>();
      if (locator.isRegistered<UserStorageService>()) await locator.unregister<UserStorageService>();

      locator.registerSingleton<LocalStorageService>(mockLocalStorageService);
      when(() => mockLocalStorageService.savePreference(
        key: any(named: 'key'),
        data: any(named: 'data'),
      )).thenAnswer((_) async => true);

      when(() => mockAuthRepository.signOut()).thenAnswer((_) async => const Right(null));
      when(() => mockAuthRepository.getUserProfile()).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'No active session')),
      );
    });

    tearDown(() async {
      await authStreamController.close();
      if (locator.isRegistered<AppSyncEngine>()) await locator.unregister<AppSyncEngine>();
      if (locator.isRegistered<CardSyncQueue>()) await locator.unregister<CardSyncQueue>();
      if (locator.isRegistered<QuizRepository>()) await locator.unregister<QuizRepository>();
      if (locator.isRegistered<UserActivityService>()) await locator.unregister<UserActivityService>();
      if (locator.isRegistered<CommunityRepository>()) await locator.unregister<CommunityRepository>();
      if (locator.isRegistered<LocalStorageService>()) await locator.unregister<LocalStorageService>();
      if (locator.isRegistered<UserStorageService>()) await locator.unregister<UserStorageService>();
    });

    AuthBloc createBloc() {
      final mockObserve = MockObserveAuthStateUseCase();
      when(mockObserve.call).thenAnswer((_) => authStreamController.stream);

      return AuthBloc(
        loginWithEmailUseCase: MockLoginWithEmailUseCase(),
        registerWithEmailUseCase: MockRegisterWithEmailUseCase(),
        loginWithSocialUseCase: MockLoginWithSocialUseCase(),
        resetPasswordUseCase: MockResetPasswordUseCase(),
        observeAuthStateUseCase: mockObserve,
        updateCourseTrackUseCase: MockUpdateCourseTrackUseCase(),
        verifyOtpUseCase: MockAuthVerifyOtpUseCase(),
        authRepository: mockAuthRepository,
      );
    }

    test('1. Flushes pending AppSyncEngine outbox BEFORE invoking authRepository.signOut()', () async {
      locator.registerSingleton<AppSyncEngine>(mockAppSyncEngine);

      final callOrder = <String>[];

      when(() => mockAppSyncEngine.flushAllPendingOutboxes()).thenAnswer((_) async {
        callOrder.add('flushAllPendingOutboxes');
      });

      when(() => mockAuthRepository.signOut()).thenAnswer((_) async {
        callOrder.add('signOut');
        return const Right(null);
      });

      final bloc = createBloc()..add(const AuthSignOutRequested());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(callOrder, equals(['flushAllPendingOutboxes', 'signOut']));
      verify(() => mockAppSyncEngine.flushAllPendingOutboxes()).called(1);
      verify(() => mockAuthRepository.signOut()).called(1);
      expect(bloc.state.status, equals(AuthStatus.unauthenticated));
    });

    test('2. Flushes individual queues sequentially if AppSyncEngine is not registered', () async {
      locator
        ..registerSingleton<CardSyncQueue>(mockCardSyncQueue)
        ..registerSingleton<QuizRepository>(mockQuizRepository)
        ..registerSingleton<UserActivityService>(mockUserActivityService)
        ..registerSingleton<CommunityRepository>(mockCommunityRepository);

      when(() => mockCardSyncQueue.flushPendingLogs()).thenAnswer((_) async => 5);
      when(() => mockQuizRepository.flushPendingQuizSubmissions()).thenAnswer((_) async => 0);
      when(() => mockUserActivityService.syncPendingProgressToBackend()).thenAnswer((_) async {});
      when(() => mockCommunityRepository.flushPendingForumActions()).thenAnswer((_) async => 0);

      final bloc = createBloc()..add(const AuthSignOutRequested());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => mockCardSyncQueue.flushPendingLogs()).called(1);
      verify(() => mockQuizRepository.flushPendingQuizSubmissions()).called(1);
      verify(() => mockUserActivityService.syncPendingProgressToBackend()).called(1);
      verify(() => mockCommunityRepository.flushPendingForumActions()).called(1);
      verify(() => mockAuthRepository.signOut()).called(1);
      expect(bloc.state.status, equals(AuthStatus.unauthenticated));
    });

    test('3. Gracefully proceeds with logout if flush times out or throws (fault tolerance)', () async {
      locator.registerSingleton<AppSyncEngine>(mockAppSyncEngine);

      when(() => mockAppSyncEngine.flushAllPendingOutboxes()).thenThrow(
        DioException(requestOptions: RequestOptions(path: '/mock-timeout')),
      );

      final bloc = createBloc()..add(const AuthSignOutRequested());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => mockAuthRepository.signOut()).called(1);
      expect(bloc.state.status, equals(AuthStatus.unauthenticated));
    });

    test('4. AppSyncEngine.flushAllPendingOutboxes calls flush and all domain outboxes', () async {
      locator
        ..registerSingleton<CardSyncQueue>(mockCardSyncQueue)
        ..registerSingleton<QuizRepository>(mockQuizRepository)
        ..registerSingleton<UserActivityService>(mockUserActivityService)
        ..registerSingleton<CommunityRepository>(mockCommunityRepository);

      when(() => mockCardSyncQueue.flushPendingLogs()).thenAnswer((_) async => 2);
      when(() => mockQuizRepository.flushPendingQuizSubmissions()).thenAnswer((_) async => 0);
      when(() => mockUserActivityService.syncPendingProgressToBackend()).thenAnswer((_) async {});
      when(() => mockCommunityRepository.flushPendingForumActions()).thenAnswer((_) async => 0);

      final engine = AppSyncEngine(
        storageService: mockLocalStorageService,
        userStorageService: mockUserStorageService,
      );

      await engine.flushAllPendingOutboxes();

      verify(() => mockCardSyncQueue.flushPendingLogs()).called(1);
      verify(() => mockQuizRepository.flushPendingQuizSubmissions()).called(1);
      verify(() => mockUserActivityService.syncPendingProgressToBackend()).called(1);
      verify(() => mockCommunityRepository.flushPendingForumActions()).called(1);
    });
  });
}
