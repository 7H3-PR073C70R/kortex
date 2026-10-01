import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/presentation/pages/ocr_preview_page.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ocr_latex_live_editor.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('OcrPreviewPage Layout & Functionality Tests', () {
    testWidgets('renders banner, editor cards, and bottom button properly', (
      tester,
    ) async {
      final sampleSnippets = [
        const OcrExtractionEntity(
          id: 's1',
          documentId: 'doc1',
          rawText: 'Photosynthesis converts light into chemical energy',
          topic: 'Photosynthesis',
        ),
        const OcrExtractionEntity(
          id: 's2',
          documentId: 'doc1',
          rawText: 'Energy mass equivalence formula',
          latexContent: 'E = mc^2',
          topic: 'Special Relativity',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          OcrPreviewPage(
            documentId: 'doc1',
            filename: 'Biology_101.pdf',
            snippets: sampleSnippets,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title in AppBar
      expect(find.text('Study Cards Live Editor'), findsOneWidget);

      // Banner with snippet count
      expect(
        find.text('2 study concepts & cards extracted'),
        findsOneWidget,
      );

      // Both cards are rendered in the body (not crushed)
      expect(find.byType(OcrLatexLiveEditor), findsNWidgets(2));
      expect(find.text('CARD #1'), findsOneWidget);
      expect(find.text('CARD #2'), findsOneWidget);
      expect(find.text('Photosynthesis'), findsOneWidget);
      expect(find.text('Special Relativity'), findsOneWidget);

      // Bottom bar action button is visible and at the bottom
      expect(find.text('Save & Generate Deck'), findsOneWidget);

      final buttonFinder = find.text('Save & Generate Deck');
      final buttonCenter = tester.getCenter(buttonFinder);
      // Ensure the button is positioned at the bottom of the screen (height: 600, button at ~556),
      // not vertically in the middle (which would be ~300)
      expect(buttonCenter.dy, greaterThan(500));
    });

    testWidgets('allows adding and deleting cards dynamically', (
      tester,
    ) async {
      final sampleSnippets = [
        const OcrExtractionEntity(
          id: 's1',
          documentId: 'doc1',
          rawText: 'Cellular respiration overview',
          topic: 'Respiration',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          OcrPreviewPage(
            documentId: 'doc1',
            filename: 'Biology_101.pdf',
            snippets: sampleSnippets,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OcrLatexLiveEditor), findsOneWidget);

      // Tap "Add Card"
      await tester.tap(find.text('Add Card'));
      await tester.pumpAndSettle();

      expect(find.byType(OcrLatexLiveEditor), findsNWidgets(2));
      expect(
        find.text('2 study concepts & cards extracted'),
        findsOneWidget,
      );

      // Delete the first card
      final deleteButtons = find.byTooltip('Delete Card');
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.byType(OcrLatexLiveEditor), findsOneWidget);
      expect(
        find.text('1 study concepts & cards extracted'),
        findsOneWidget,
      );
    });

    testWidgets('displays empty state when initial snippets list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const OcrPreviewPage(
            documentId: 'doc1',
            filename: 'Empty.pdf',
            snippets: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No study cards yet'), findsOneWidget);
      expect(find.text('Save & Generate Deck'), findsOneWidget);
    });
  });
}
