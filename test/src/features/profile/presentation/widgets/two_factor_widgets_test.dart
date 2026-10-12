import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/profile/presentation/pages/two_factor_setup_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('TwoFactor Subwidgets Test Suite', () {
    testWidgets('TwoFactorQrCodeCard renders step 1 badge and compatibility text', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const TwoFactorQrCodeCard(
            totpUri: 'otpauth://totp/Kortexify:scholar@kortex.ai?secret=JBSWY3DPEHPK3PXP&issuer=Kortexify',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Scan QR Code with Authenticator App'), findsOneWidget);
      expect(find.textContaining('Google Authenticator'), findsOneWidget);
    });

    testWidgets('TwoFactorSecretKeyCard renders step 2 badge, key, and copy button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const TwoFactorSecretKeyCard(
            secretKey: 'JBSWY3DPEHPK3PXP',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Or Copy Secret Key Manually'), findsOneWidget);
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('TwoFactorVerifyCard renders step 3 badge, input field, and triggers verification', (tester) async {
      var verifyTriggered = false;
      final controller = TextEditingController(text: '654321');

      await tester.pumpWidget(
        createTestApp(
          TwoFactorVerifyCard(
            codeController: controller,
            isVerifying: false,
            onVerify: () {
              verifyTriggered = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Enter 6-Digit Code from Authenticator'), findsOneWidget);
      expect(find.text('Verify & Enable 2FA'), findsOneWidget);

      await tester.tap(find.text('Verify & Enable 2FA'));
      await tester.pumpAndSettle();
      expect(verifyTriggered, isTrue);
    });

    testWidgets('TwoFactorErrorView renders error message and triggers retry', (tester) async {
      var retryTriggered = false;

      await tester.pumpWidget(
        createTestApp(
          TwoFactorErrorView(
            errorMessage: 'Network timeout connecting to server',
            onRetry: () {
              retryTriggered = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could Not Initialize 2FA'), findsOneWidget);
      expect(find.text('Network timeout connecting to server'), findsOneWidget);
      expect(find.text('Retry Enrollment'), findsOneWidget);

      await tester.tap(find.text('Retry Enrollment'));
      await tester.pumpAndSettle();
      expect(retryTriggered, isTrue);
    });

    testWidgets('TwoFactorShimmerSkeleton renders loading placeholders', (tester) async {
      await tester.pumpWidget(
        createTestApp(const TwoFactorShimmerSkeleton()),
      );
      await tester.pump();

      expect(find.byType(TwoFactorShimmerSkeleton), findsOneWidget);
    });
  });
}
