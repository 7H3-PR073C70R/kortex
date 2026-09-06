import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_enroll_result_entity.dart';
import 'package:kortex/src/features/profile/domain/use_cases/profile_security_use_cases.dart';
import 'package:kortex/src/features/profile/presentation/pages/two_factor_setup_page.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockEnrollMfaTotpUseCase extends Mock implements EnrollMfaTotpUseCase {}

class MockVerifyMfaTotpUseCase extends Mock implements VerifyMfaTotpUseCase {}

class MockUserStorageService extends Mock implements UserStorageService {}

class FakeVerifyMfaTotpParams extends Fake implements VerifyMfaTotpParams {}

void main() {
  final locator = GetIt.instance;
  late MockEnrollMfaTotpUseCase mockEnroll;
  late MockVerifyMfaTotpUseCase mockVerify;
  late MockUserStorageService mockUserStorage;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(FakeVerifyMfaTotpParams());
  });

  setUp(() {
    locator.pushNewScope();
    mockEnroll = MockEnrollMfaTotpUseCase();
    mockVerify = MockVerifyMfaTotpUseCase();
    mockUserStorage = MockUserStorageService();

    locator
      ..registerSingleton<EnrollMfaTotpUseCase>(mockEnroll)
      ..registerSingleton<VerifyMfaTotpUseCase>(mockVerify)
      ..registerSingleton<UserStorageService>(mockUserStorage);

    when(() => mockUserStorage.getUserEmail()).thenReturn('scholar.dynamic@kortex.ai');
  });

  tearDown(() async {
    await locator.popScope();
  });

  Widget createTestApp({
    String? email,
    String? initialSecret,
    String? initialFactorId,
    String? initialTotpUri,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TwoFactorSetupPage(
        email: email,
        initialSecret: initialSecret,
        initialFactorId: initialFactorId,
        initialTotpUri: initialTotpUri,
      ),
    );
  }

  group('TwoFactorSetupPage Dynamic Configuration & Security Suite', () {
    testWidgets('resolves authenticated email dynamically from UserStorageService when unprovided', (
      tester,
    ) async {
      when(() => mockEnroll.call(any())).thenAnswer(
        (_) async => const Right(
          MfaEnrollResultEntity(
            factorId: 'factor_dyn_123',
            secret: 'SECRETKEY987654321',
            uri: 'otpauth://totp/Kortexify:scholar.dynamic@kortex.ai?secret=SECRETKEY987654321&issuer=Kortexify',
          ),
        ),
      );

      await tester.pumpWidget(createTestApp());
      // Pump past initial frame so enroll() finishes
      await tester.pumpAndSettle();

      verify(() => mockUserStorage.getUserEmail()).called(greaterThanOrEqualTo(1));
      expect(find.text('SECRETKEY987654321'), findsOneWidget);
      expect(find.text('MJ6YDJSONHTA3IXIW7JSX2USKBC67XTN'), findsNothing);
    });

    testWidgets('renders provided initialSecret and does not invoke EnrollMfaTotpUseCase', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          email: 'custom@student.edu',
          initialSecret: 'PREPROVIDEDSECRET123',
          initialFactorId: 'factor_pre_456',
        ),
      );
      await tester.pumpAndSettle();

      verifyNever(() => mockEnroll.call(any()));
      expect(find.text('PREPROVIDEDSECRET123'), findsOneWidget);
      expect(find.text('MJ6YDJSONHTA3IXIW7JSX2USKBC67XTN'), findsNothing);
    });

    testWidgets('displays error view and retry button when enrollment fails', (
      tester,
    ) async {
      when(() => mockEnroll.call(any())).thenAnswer(
        (_) async => const Left(
          ServerFailure(message: 'Network unreachable or 2FA service down'),
        ),
      );

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Could Not Initialize 2FA'), findsOneWidget);
      expect(find.text('Network unreachable or 2FA service down'), findsOneWidget);
      expect(find.text('Retry Enrollment'), findsOneWidget);
      expect(find.text('MJ6YDJSONHTA3IXIW7JSX2USKBC67XTN'), findsNothing);

      // Verify retry flow
      when(() => mockEnroll.call(any())).thenAnswer(
        (_) async => const Right(
          MfaEnrollResultEntity(
            factorId: 'factor_retry_789',
            secret: 'RETRYSECRET456',
            uri: 'otpauth://totp/Kortexify:scholar@kortex.ai?secret=RETRYSECRET456&issuer=Kortexify',
          ),
        ),
      );

      await tester.tap(find.text('Retry Enrollment'));
      await tester.pumpAndSettle();

      expect(find.text('Could Not Initialize 2FA'), findsNothing);
      expect(find.text('RETRYSECRET456'), findsOneWidget);
    });

    testWidgets('validates 6-digit code before calling VerifyMfaTotpUseCase', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          initialSecret: 'READYSECRET123',
          initialFactorId: 'factor_ready_999',
        ),
      );
      await tester.pumpAndSettle();

      final verifyBtn = find.text('Verify & Enable 2FA');
      await tester.ensureVisible(verifyBtn);

      // Tap verify with empty code
      await tester.tap(verifyBtn);
      await tester.pumpAndSettle();

      verifyNever(() => mockVerify.call(any()));
      expect(find.text('Please enter the full 6-digit code.'), findsOneWidget);

      // Enter 6-digit code and verify call
      when(() => mockVerify.call(any())).thenAnswer(
        (_) async => const Right(null),
      );

      await tester.enterText(find.byType(TextField), '654321');
      await tester.tap(verifyBtn);
      await tester.pumpAndSettle();

      verify(
        () => mockVerify.call(
          any(
            that: isA<VerifyMfaTotpParams>()
                .having((p) => p.factorId, 'factorId', 'factor_ready_999')
                .having((p) => p.code, 'code', '654321'),
          ),
        ),
      ).called(1);
    });
  });
}
