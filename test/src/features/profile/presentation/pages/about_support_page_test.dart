import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/profile/presentation/pages/about_support_page.dart';
import 'package:kortex/src/l10n/l10n.dart';

import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  PackageInfo.setMockInitialValues(
    appName: 'Kortexify',
    packageName: 'com.kortex.app',
    version: '1.0.2',
    buildNumber: '3',
    buildSignature: '',
  );

  Widget createTestWidget() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AboutSupportPage(),
    );
  }

  group('AboutSupportPage Widget Tests', () {
    testWidgets('renders app title and support links correctly', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('About & Support'), findsOneWidget);
      expect(find.text('Kortexify'), findsOneWidget);
      expect(find.text('v1.0.2+3 • Production Neural Engine'), findsOneWidget);
      expect(find.text('Community Discord & Study Rooms'), findsOneWidget);
      expect(find.text('Documentation & Knowledgebase'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });
}
