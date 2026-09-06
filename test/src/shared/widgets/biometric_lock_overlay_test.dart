import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/biometric_lock_overlay.dart';
import 'package:kortex/src/shared/widgets/tailored_biometric_lock_view.dart';
import 'package:mocktail/mocktail.dart';

class MockBiometricAuthService extends Mock implements BiometricAuthService {}
class MockUserStorageService extends Mock implements UserStorageService {}
class MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockBiometricAuthService mockBiometric;
  late MockUserStorageService mockUserStorage;
  late MockAuthBloc mockAuthBloc;
  late ValueNotifier<bool> isEnabledNotifier;
  late DateTime currentTime;

  setUp(() {
    mockBiometric = MockBiometricAuthService();
    mockUserStorage = MockUserStorageService();
    mockAuthBloc = MockAuthBloc();
    isEnabledNotifier = ValueNotifier<bool>(true);
    currentTime = DateTime(2026, 9, 6, 12);

    const tState = AuthState(
      user: UserEntity(id: 'u1', email: 'scholar@kortex.ai', displayName: 'Ada Lovelace'),
    );
    when(() => mockAuthBloc.state).thenReturn(tState);
    when(() => mockAuthBloc.stream).thenAnswer((_) => Stream.value(tState));

    when(() => mockBiometric.isEnabledListenable).thenReturn(isEnabledNotifier);
    when(() => mockBiometric.isBiometricLockEnabled()).thenReturn(true);
    when(() => mockBiometric.backgroundLockTimeout)
        .thenReturn(const Duration(seconds: 30));
    when(() => mockUserStorage.getToken()).thenReturn('valid_jwt_token_123');

    // Simulate background recording & shouldReArm logic
    DateTime? recordedTime;
    when(() => mockBiometric.recordBackgroundedAt(any())).thenAnswer((inv) {
      recordedTime = inv.positionalArguments.first as DateTime?;
    });
    when(() => mockBiometric.clearBackgroundedAt()).thenAnswer((_) {
      recordedTime = null;
    });
    when(
      () => mockBiometric.shouldReArmLock(
        threshold: any(named: 'threshold'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((inv) {
      if (recordedTime == null) return false;
      final now = (inv.namedArguments[const Symbol('now')] as DateTime?) ?? currentTime;
      final threshold = (inv.namedArguments[const Symbol('threshold')] as Duration?) ??
          const Duration(seconds: 30);
      return now.difference(recordedTime!) >= threshold;
    });
    when(() => mockBiometric.authenticate(localizedReason: any(named: 'localizedReason')))
        .thenAnswer((_) async => true);
  });

  Widget buildWidget({Duration? backgroundTimeout}) {
    return BlocProvider<AuthBloc>.value(
      value: mockAuthBloc,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BiometricLockOverlay(
          biometricService: mockBiometric,
          userStorageService: mockUserStorage,
          clock: () => currentTime,
          backgroundTimeout: backgroundTimeout,
          child: const Scaffold(
            body: Center(
              child: Text('Protected Study Dashboard'),
            ),
          ),
        ),
      ),
    );
  }

  group('BiometricLockOverlay Background Re-Arming Test Suite', () {
    testWidgets('renders child on initial display', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Protected Study Dashboard'), findsOneWidget);
      expect(find.byType(TailoredBiometricLockView), findsNothing);
    });

    testWidgets('resuming before 30s timeout threshold does not lock overlay', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Transition to paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Advance clock by only 15 seconds (under 30s threshold)
      currentTime = currentTime.add(const Duration(seconds: 15));

      // Transition to resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Protected Study Dashboard'), findsOneWidget);
      expect(find.byType(TailoredBiometricLockView), findsNothing);
    });

    testWidgets('resuming after 30s timeout threshold locks overlay and presents TailoredBiometricLockView', (
      tester,
    ) async {
      // Return false initially so it stays locked
      when(() => mockBiometric.authenticate(localizedReason: any(named: 'localizedReason')))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Pause app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Advance clock by 35 seconds (exceeds 30s threshold)
      currentTime = currentTime.add(const Duration(seconds: 35));

      // Resume app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      // Expect TailoredBiometricLockView to be shown
      expect(find.byType(TailoredBiometricLockView), findsOneWidget);
    });

    testWidgets('successful biometric authentication unlocks overlay', (
      tester,
    ) async {
      when(() => mockBiometric.authenticate(localizedReason: any(named: 'localizedReason')))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Background and resume after 40 seconds
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      currentTime = currentTime.add(const Duration(seconds: 40));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify lock view was unlocked upon success
      expect(find.text('Protected Study Dashboard'), findsOneWidget);
      expect(find.byType(TailoredBiometricLockView), findsNothing);
    });

    testWidgets('does not lock on resume if biometric lock is disabled in settings', (
      tester,
    ) async {
      when(() => mockBiometric.isBiometricLockEnabled()).thenReturn(false);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      currentTime = currentTime.add(const Duration(seconds: 50));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Protected Study Dashboard'), findsOneWidget);
      expect(find.byType(TailoredBiometricLockView), findsNothing);
    });
  });
}
