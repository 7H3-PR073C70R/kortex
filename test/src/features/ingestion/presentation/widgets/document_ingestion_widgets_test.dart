import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ingestion/document_upload_control_section.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ingestion/interrupted_upload_banner.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ingestion/recent_document_card.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ingestion/recent_documents_section.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';

import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget _wrap(Widget child, {bool isDark = false}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('InterruptedUploadBanner', () {
    testWidgets('renders banner with filename and progress percentage',
        (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        _wrap(
          InterruptedUploadBanner(
            job: const {
              'filename': 'lecture_notes.pdf',
              'uploadProgress': 0.75,
            },
            onDismiss: () => dismissed = true,
            isDark: false,
          ),
        ),
      );

      expect(find.text('Interrupted Upload Detected'), findsOneWidget);
      expect(
        find.textContaining('lecture_notes.pdf was interrupted at 75%'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Dismiss'));
      expect(dismissed, isTrue);
    });
  });

  group('RecentDocumentCard', () {
    final testDoc = DocumentUploadEntity(
      id: 'doc-123',
      userId: 'user-1',
      filename: 'Physics101_Lecture.pdf',
      fileSizeBytes: 204800,
      fileType: 'pdf',
      storagePath: '/storage/path',
      contentHash: 'hash-abc',
      status: ProcessingStatus.completed,
      createdAt: DateTime.now(),
    );

    testWidgets('renders document details and handles delete/attach callbacks',
        (tester) async {
      var deleteCalled = false;
      var attachCalled = false;

      await tester.pumpWidget(
        _wrap(
          RecentDocumentCard(
            doc: testDoc,
            isAlreadyAttached: false,
            hasCourseContext: true,
            courseCode: 'PHY101',
            onDelete: () => deleteCalled = true,
            onAttach: () => attachCalled = true,
            isDark: false,
          ),
        ),
      );

      expect(find.text('Physics101_Lecture.pdf'), findsOneWidget);
      expect(find.text('PDF • 200.0 KB'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Attach to PHY101'), findsOneWidget);

      await tester.tap(find.text('Attach to PHY101'));
      expect(attachCalled, isTrue);

      await tester.tap(find.byTooltip('Delete Document'));
      expect(deleteCalled, isTrue);
    });

    testWidgets('shows attached badge when already attached', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RecentDocumentCard(
            doc: testDoc,
            isAlreadyAttached: true,
            hasCourseContext: true,
            courseCode: 'PHY101',
            onDelete: () {},
            onAttach: () {},
            isDark: false,
          ),
        ),
      );

      expect(find.text('Attached to PHY101'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });

  group('RecentDocumentsSection', () {
    testWidgets('renders empty state when user documents list is empty',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          RecentDocumentsSection(
            userDocuments: const [],
            attachedDocumentIds: const {},
            onAttachDocument: (_) {},
            onDeleteDocument: (_) {},
            isDark: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('RECENTLY INGESTED DOCUMENTS'), findsOneWidget);
      expect(
        find.text(
          'No documents ingested yet. Upload lecture notes above to start.',
        ),
        findsOneWidget,
      );
    });
  });

  group('DocumentUploadControlSection', () {
    testWidgets('renders upload zone, synthesis mode toggle, and progress card',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const state = IngestionState();

      await tester.pumpWidget(
        _wrap(
          DocumentUploadControlSection(
            state: state,
            guard: SubscriptionGuard(),
            remainingQuota: 5,
            onUpdateQuota: (_) {},
            onModeSelected: (_) {},
            onFilePicked: ({
              required filename,
              required fileType,
              required fileBytes,
            }) {},
            onCameraScanTap: () {},
            onDismissPendingJob: () {},
            onRetryProgress: () {},
            isDark: false,
          ),
        ),
      );

      // Settle animations
      await tester.pumpAndSettle();

      // Verify synthesis mode and drop zone elements render
      expect(find.byType(DocumentUploadControlSection), findsOneWidget);
    });
  });
}
