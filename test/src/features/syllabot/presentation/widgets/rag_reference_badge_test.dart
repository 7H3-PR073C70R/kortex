import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/rag_reference_badge.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/rag_source_inspection_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const tChunk = DocumentChunkEntity(
    id: 'chunk_123',
    documentId: 'doc_456',
    documentTitle: 'Calculus III Syllabus',
    content: 'Stokes Theorem relates a surface integral over a vector field to a line integral around the boundary curve.',
    similarityScore: 0.94,
    pageNumber: 5,
    paragraphNumber: 2,
  );

  Widget buildTestWidget({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    );
  }

  group('RagReferenceBadge & RagSourceInspectionSheet Test Suite', () {
    testWidgets('renders badge with title, citation, and similarity percentage', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const RagReferenceBadge(chunk: tChunk),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Calculus III Syllabus (p. 5, para. 2)'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });

    testWidgets('tapping badge opens RagSourceInspectionSheet with full excerpt', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => RagReferenceBadge(
              chunk: tChunk,
              onTap: () => RagSourceInspectionSheet.show(context, tChunk),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(RagReferenceBadge));
      await tester.pumpAndSettle();

      expect(find.byType(RagSourceInspectionSheet), findsOneWidget);
      expect(find.text('Page 5 • Paragraph 2'), findsOneWidget);
      expect(find.text('94% Match'), findsOneWidget);
      expect(
        find.text('Stokes Theorem relates a surface integral over a vector field to a line integral around the boundary curve.'),
        findsOneWidget,
      );
      expect(find.text('Copy Citation'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(RagSourceInspectionSheet), findsNothing);
    });
  });
}
