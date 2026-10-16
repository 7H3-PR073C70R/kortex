import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/file_drop_zone_widget.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockSubscriptionGuard extends Mock implements SubscriptionGuard {}

Widget _wrap(Widget child, {bool isDark = false}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('FileDropZoneWidget Tests', () {
    testWidgets('renders drop zone header, format notice, and browse button',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          FileDropZoneWidget(
            onFilePicked: ({
              required filename,
              required fileType,
              required fileBytes,
            }) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.text('Browse Files'), findsOneWidget);
      expect(find.byType(FreeDailyUploadsCard), findsOneWidget);
    });

    testWidgets('renders LMS Import and Camera Scan buttons when callbacks provided',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var lmsTapped = false;
        var cameraTapped = false;

        await tester.pumpWidget(
          _wrap(
            FileDropZoneWidget(
              onFilePicked: ({
                required filename,
                required fileType,
                required fileBytes,
              }) {},
              onLmsImportTap: () => lmsTapped = true,
              onCameraScanTap: () => cameraTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Import LMS'), findsOneWidget);
        await tester.tap(find.text('Import LMS'));
        expect(lmsTapped, isTrue);

        expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.camera_alt_outlined));
        expect(cameraTapped, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('supports constructor DI of SubscriptionGuard and hides free limit card for Pro',
        (tester) async {
      final mockGuard = MockSubscriptionGuard();
      when(() => mockGuard.isPro).thenReturn(true);

      await tester.pumpWidget(
        _wrap(
          FileDropZoneWidget(
            subscriptionGuard: mockGuard,
            onFilePicked: ({
              required filename,
              required fileType,
              required fileBytes,
            }) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Free Daily Uploads'), findsNothing);
    });
  });
}
