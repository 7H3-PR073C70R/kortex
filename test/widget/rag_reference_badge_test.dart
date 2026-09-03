import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/rag_reference_badge.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  group('RagReferenceBadge Widget Test Suite', () {
    const tChunk = DocumentChunkEntity(
      id: 'chk_1',
      documentId: 'doc_chem',
      content: 'Le Chatelier Principle shifts equilibrium.',
      similarityScore: 0.94,
      documentTitle: 'AP Chemistry Guide',
      pageNumber: 88,
    );

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

    testWidgets('renders document title, page number, and similarity score', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          RagReferenceBadge(
            chunk: tChunk,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AP Chemistry Guide (p. 88)'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);

      await tester.tap(find.byType(RagReferenceBadge));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
