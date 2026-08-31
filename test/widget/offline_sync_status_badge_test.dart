import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/offline_sync_status_badge.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  group('OfflineSyncStatusBadge Widget Test Suite', () {
    Widget createTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    testWidgets('renders pending sync count and triggers sync on tap',
        (tester) async {
      var syncTriggered = false;

      await tester.pumpWidget(
        createTestApp(
          OfflineSyncStatusBadge(
            pendingCount: 3,
            onSyncNow: () {
              syncTriggered = true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('3 items pending sync'), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

      await tester.tap(find.byType(OfflineSyncStatusBadge));
      await tester.pump();

      expect(syncTriggered, isTrue);
    });

    testWidgets('renders progress indicator when syncing is active',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const OfflineSyncStatusBadge(
            pendingCount: 3,
            isSyncing: true,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Syncing offline notes...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
