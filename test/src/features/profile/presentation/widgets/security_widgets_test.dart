import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_account_credentials_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_biometrics_and_mfa_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_danger_zone_card.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_data_portability_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_deck_picker_dialog.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_password_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_section_container.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_storage_cache_section.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget wrapWithTheme(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('Security Widgets Unit & Component Tests', () {
    testWidgets('SecuritySectionContainer renders title, subtitle, and child', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SecuritySectionContainer(
            title: 'Test Section',
            subtitle: 'Test Subtitle',
            child: Text('Child Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEST SECTION'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets('SecurityPasswordSection renders password fields and triggers actions', (
      tester,
    ) async {
      final currentCtrl = TextEditingController();
      final newCtrl = TextEditingController();
      final confirmCtrl = TextEditingController();
      var updatePressed = false;
      var resetEmailPressed = false;

      await tester.pumpWidget(
        wrapWithTheme(
          SecurityPasswordSection(
            currentPasswordController: currentCtrl,
            newPasswordController: newCtrl,
            confirmPasswordController: confirmCtrl,
            hasMinLength: true,
            hasNumber: false,
            hasSpecial: false,
            isUpdatingPassword: false,
            onUpdatePassword: () => updatePressed = true,
            onSendResetEmail: () => resetEmailPressed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PASSWORD & AUTHENTICATION'), findsOneWidget);
      expect(find.text('Send Reset Email'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);

      await tester.tap(find.text('Update Password'));
      expect(updatePressed, isTrue);

      await tester.tap(find.text('Send Reset Email'));
      expect(resetEmailPressed, isTrue);
    });

    testWidgets('SecurityBiometricsAndMfaSection toggles switches and calls callbacks', (
      tester,
    ) async {
      bool? bioChanged;
      bool? mfaChanged;

      await tester.pumpWidget(
        wrapWithTheme(
          SecurityBiometricsAndMfaSection(
            biometricLockEnabled: false,
            backgroundLockTimeoutSeconds: 30,
            twoFactorEnabled: false,
            onBiometricLockChanged: (val) => bioChanged = val,
            onTimeoutChanged: (_) {},
            onTwoFactorChanged: (val) => mfaChanged = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('APP LOCK & TWO-FACTOR AUTHENTICATION'),
        findsOneWidget,
      );
      expect(find.text('Biometric App Lock'), findsOneWidget);
      expect(find.text('Two-Factor Auth (TOTP)'), findsOneWidget);

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      await tester.tap(switches.first);
      expect(bioChanged, isTrue);

      await tester.tap(switches.last);
      expect(mfaChanged, isTrue);
    });

    testWidgets('SecurityDangerZoneCard shows dialog on click', (
      tester,
    ) async {
      var deleteCalled = false;

      await tester.pumpWidget(
        wrapWithTheme(
          SecurityDangerZoneCard(
            onDeleteAccount: () => deleteCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Danger Zone'), findsOneWidget);
      expect(find.text('Delete Account & Purge Data'), findsOneWidget);

      await tester.tap(find.text('Delete Account & Purge Data'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Account Permanently?'), findsOneWidget);

      await tester.tap(find.text('Delete Forever'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });

    testWidgets('SecurityAccountCredentialsSection renders info and opens edit dialog', (
      tester,
    ) async {
      String? savedName;

      await tester.pumpWidget(
        wrapWithTheme(
          SecurityAccountCredentialsSection(
            displayName: 'Original Name',
            email: 'test@kortex.ai',
            onSaveDisplayName: (name) async => savedName = name,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Original Name'), findsOneWidget);
      expect(find.text('test@kortex.ai'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Display Name'), findsOneWidget);

      final input = find.byType(TextField);
      await tester.enterText(input, 'New Scholar Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedName, 'New Scholar Name');
    });

    testWidgets('SecurityDataPortabilitySection calls callbacks on button taps', (
      tester,
    ) async {
      var exportDecksCalled = false;
      var exportGdprCalled = false;

      await tester.pumpWidget(
        wrapWithTheme(
          SecurityDataPortabilitySection(
            onExportDecks: () => exportDecksCalled = true,
            onExportGdprBundle: () => exportGdprCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DATA PORTABILITY & EXPORT'), findsOneWidget);
      expect(find.text('Export Study Decks (Anki, CSV, PDF)'), findsOneWidget);
      expect(find.text('Export Account Data (GDPR JSON Bundle)'), findsOneWidget);

      await tester.tap(find.text('Export Study Decks (Anki, CSV, PDF)'));
      expect(exportDecksCalled, isTrue);

      await tester.tap(find.text('Export Account Data (GDPR JSON Bundle)'));
      expect(exportGdprCalled, isTrue);
    });

    testWidgets('SecurityStorageCacheSection renders properly', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const SecurityStorageCacheSection(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STORAGE & AI CACHE MANAGEMENT'), findsOneWidget);
      expect(find.text('Syllabot & Image Cache'), findsOneWidget);
      expect(find.text('Clear Cache'), findsOneWidget);
    });

    testWidgets('SecurityDeckPickerDialog renders decks and handles selection', (
      tester,
    ) async {
      DeckEntity? selected;

      const deck1 = DeckEntity(
        id: 'deck_1',
        title: 'Biology Deck',
        description: 'Bio notes',
        subject: 'Biology',
        totalCards: 20,
        dueCards: 5,
        masteryRate: 0.85,
        category: 'Science',
        colorHex: '#4CAF50',
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, _) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => SecurityDeckPickerDialog.show(
                    context: ctx,
                    decks: const [deck1],
                    onSelectDeck: (d) => selected = d,
                  ),
                  child: const Text('Open Picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Deck to Export'), findsOneWidget);
      expect(find.text('Biology Deck'), findsOneWidget);

      await tester.tap(find.text('Biology Deck'));
      await tester.pumpAndSettle();

      expect(selected?.id, 'deck_1');
    });
  });
}
