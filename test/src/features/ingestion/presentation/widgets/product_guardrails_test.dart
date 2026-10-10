import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/entities/pedagogical_card_schema.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/extraction_report_banner.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/generated_card_preview_tile.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('Step 15: Product Guardrails & UX Transparency Model Tests', () {
    test('effectiveCitation formats combined page and section correctly', () {
      const itemWithBoth = GeneratedCardPreviewItem(
        front: 'What is ATP?',
        back: 'Adenosine triphosphate.',
        source: CardSource(
          docId: 'doc_1',
          page: 14,
          sectionPath: ['§8.3 Cellular Respiration'],
        ),
      );
      expect(itemWithBoth.effectiveCitation, 'p. 14 · §8.3 Cellular Respiration');

      const itemPageOnly = GeneratedCardPreviewItem(
        front: 'Q',
        back: 'A',
        source: CardSource(
          docId: 'doc_1',
          page: 25,
          sectionPath: [],
        ),
      );
      expect(itemPageOnly.effectiveCitation, 'p. 25');

      const itemSectionOnly = GeneratedCardPreviewItem(
        front: 'Q',
        back: 'A',
        source: CardSource(
          docId: 'doc_1',
          page: 1,
          sectionPath: ['§3.1 Introduction'],
        ),
      );
      expect(itemSectionOnly.effectiveCitation, 'p. 1 · §3.1 Introduction');

      const itemFallback = GeneratedCardPreviewItem(
        front: 'Q',
        back: 'A',
        sourceCitation: 'Chapter 2, Note 5',
      );
      expect(itemFallback.effectiveCitation, 'Chapter 2, Note 5');
    });

    test('needsReview flags low-confidence cards (< 0.85)', () {
      const highConfidenceCard = GeneratedCardPreviewItem(
        front: 'Q',
        back: 'A',
      );
      expect(highConfidenceCard.needsReview, isFalse);

      const thresholdCard = GeneratedCardPreviewItem(
        front: 'Q',
        back: 'A',
        confidenceScore: 0.85,
      );
      expect(thresholdCard.needsReview, isFalse);

      const lowConfidenceCard = GeneratedCardPreviewItem(
        front: 'Q',
        back: 'A',
        confidenceScore: 0.75,
      );
      expect(lowConfidenceCard.needsReview, isTrue);
    });
  });

  group('Step 15: ExtractionReportBanner Widget Tests', () {
    testWidgets('renders lines retained, dropped elements, and OCR status', (
      tester,
    ) async {
      final report = ExtractionReport(
        filename: 'scanned_biology.pdf',
        isScanned: true,
      )
        ..totalLinesRetained = 250
        ..recordDrop(rule: 'front_matter_table_of_contents', sampleText: 'Contents')
        ..recordWarning('Low contrast scan detected on page 1');

      await tester.pumpWidget(
        createTestApp(
          ExtractionReportBanner(report: report),
        ),
      );
      await tester.pumpAndSettle();

      // Scanned Document header
      expect(find.text('Scanned Document (OCR Engine Applied)'), findsOneWidget);

      // Pill: retained lines
      expect(find.text('250 lines retained'), findsOneWidget);

      // Pill: dropped boilerplate
      expect(find.text('1 boilerplate / front-matter items filtered'), findsOneWidget);

      // Pill: OCR fallback active
      expect(find.text('Optical Character Recognition fallback active'), findsOneWidget);

      // Pill: Notices
      expect(find.text('1 notices'), findsOneWidget);

      // Inspect audit action
      expect(find.text('Inspect Audit'), findsOneWidget);
    });
  });

  group('Step 15: GeneratedCardPreviewTile Guardrails Widget Tests', () {
    testWidgets('renders citation badge and review badge, opens provenance dialog on tap', (
      tester,
    ) async {
      const testCard = GeneratedCardPreviewItem(
        front: 'State Newton second law',
        back: 'F = ma, Force equals mass times acceleration.',
        confidenceScore: 0.78,
        source: CardSource(
          docId: 'physics_vol1',
          page: 42,
          sectionPath: ['§2.4 Dynamics'],
          bbox: BoundingBox(left: 50, top: 100, right: 450, bottom: 200),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          GeneratedCardPreviewTile(
            index: 0,
            card: testCard,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card index badge
      expect(find.text('CARD #1'), findsOneWidget);

      // Citation badge: 'p. 42 · §2.4 Dynamics'
      expect(find.text('p. 42 · §2.4 Dynamics'), findsOneWidget);

      // Review recommended badge: 'REVIEW (78%)'
      expect(find.text('REVIEW (78%)'), findsOneWidget);

      // Tap citation badge to open provenance inspector dialog
      await tester.tap(find.text('p. 42 · §2.4 Dynamics'));
      await tester.pumpAndSettle();

      // Dialog title and details
      expect(find.text('Source Provenance'), findsOneWidget);
      expect(find.text('Citation: p. 42 · §2.4 Dynamics'), findsOneWidget);
      expect(find.text('Document ID: physics_vol1'), findsOneWidget);
      expect(find.text('Page: 42'), findsOneWidget);
      expect(find.text('Section: §2.4 Dynamics'), findsOneWidget);
      expect(find.text('Bounding Box: [50, 100, 450, 200]'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Source Provenance'), findsNothing);
    });
  });
}
