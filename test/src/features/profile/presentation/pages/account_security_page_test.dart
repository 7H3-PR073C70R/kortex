import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/features/profile/presentation/pages/account_security_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/security_settings_page.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockListMfaFactorsUseCase extends Mock implements ListMfaFactorsUseCase {}
class MockBiometricAuthService extends Mock implements BiometricAuthService {}
class MockGetUserDecksUseCase extends Mock implements GetUserDecksUseCase {}
class MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockLocalStorageService mockStorage;
  late MockListMfaFactorsUseCase mockListMfaFactorsUseCase;
  late MockBiometricAuthService mockBiometricService;
  late MockGetUserDecksUseCase mockGetUserDecksUseCase;
  late MockAuthBloc mockAuthBloc;

  setUp(() async {
    mockStorage = MockLocalStorageService();
    mockListMfaFactorsUseCase = MockListMfaFactorsUseCase();
    mockBiometricService = MockBiometricAuthService();
    mockGetUserDecksUseCase = MockGetUserDecksUseCase();
    mockAuthBloc = MockAuthBloc();

    when(() => mockStorage.getPreference(key: any(named: 'key'))).thenReturn('false');
    when(() => mockListMfaFactorsUseCase(any())).thenAnswer((_) async => const Right([]));
    when(() => mockBiometricService.canAuthenticate()).thenAnswer((_) async => false);
    when(() => mockGetUserDecksUseCase()).thenAnswer((_) async => const Right([]));

    const tState = AuthState(
      user: UserEntity(id: 'u1', email: 'scholar@kortex.ai'),
      userProfile: UserProfileEntity(
        id: 'u1',
        email: 'scholar@kortex.ai',
        displayName: 'Hypatia of Alexandria',
      ),
    );
    when(() => mockAuthBloc.state).thenReturn(tState);
    when(() => mockAuthBloc.stream).thenAnswer((_) => Stream.value(tState));

    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    if (locator.isRegistered<ListMfaFactorsUseCase>()) {
      await locator.unregister<ListMfaFactorsUseCase>();
    }
    if (locator.isRegistered<BiometricAuthService>()) {
      await locator.unregister<BiometricAuthService>();
    }
    if (locator.isRegistered<GetUserDecksUseCase>()) {
      await locator.unregister<GetUserDecksUseCase>();
    }

    locator
      ..registerLazySingleton<LocalStorageService>(() => mockStorage)
      ..registerLazySingleton<ListMfaFactorsUseCase>(() => mockListMfaFactorsUseCase)
      ..registerLazySingleton<BiometricAuthService>(() => mockBiometricService)
      ..registerLazySingleton<GetUserDecksUseCase>(() => mockGetUserDecksUseCase);
  });

  tearDown(() async {
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    if (locator.isRegistered<ListMfaFactorsUseCase>()) {
      await locator.unregister<ListMfaFactorsUseCase>();
    }
    if (locator.isRegistered<BiometricAuthService>()) {
      await locator.unregister<BiometricAuthService>();
    }
    if (locator.isRegistered<GetUserDecksUseCase>()) {
      await locator.unregister<GetUserDecksUseCase>();
    }
  });

  Widget buildTestWidget({Widget? home}) {
    return BlocProvider<AuthBloc>.value(
      value: mockAuthBloc,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: home ?? const SecuritySettingsPage(),
      ),
    );
  }

  group('Consolidated Account & Security Page Test Suite', () {
    testWidgets('renders Account & Security title and segmented pill tab bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Security & Access'), findsOneWidget);
      expect(find.text('Account & Data'), findsOneWidget);
    });

    testWidgets('defaults to Security & Access tab with password, biometrics, sessions, and danger zone', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Password & Authentication'), findsOneWidget);
      expect(find.text('App Lock & Two-Factor Authentication'), findsOneWidget);
      expect(find.text('Active Sessions & Device Management'), findsOneWidget);
      expect(find.text('Danger Zone'), findsOneWidget);
      expect(find.text('Sign Out All Other Devices'), findsOneWidget);
    });

    testWidgets('switching to Account & Data tab displays credentials, deck export, and cache', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the Account & Data tab
      await tester.tap(find.text('Account & Data'));
      await tester.pumpAndSettle();

      expect(find.text('Account Credentials'), findsOneWidget);
      expect(find.text('Hypatia of Alexandria'), findsOneWidget);
      expect(find.text('scholar@kortex.ai'), findsOneWidget);
      expect(find.text('Data Portability & Export'), findsOneWidget);
      expect(find.text('Storage & AI Cache Management'), findsOneWidget);
      expect(find.text('Clear Cache'), findsOneWidget);
    });

    testWidgets('AccountSecurityPage wrapper defaults to Account & Data tab', (tester) async {
      await tester.pumpWidget(buildTestWidget(home: const AccountSecurityPage()));
      await tester.pumpAndSettle();

      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Account Credentials'), findsOneWidget);
      expect(find.text('Data Portability & Export'), findsOneWidget);
      expect(find.text('Storage & AI Cache Management'), findsOneWidget);
    });
  });
}
