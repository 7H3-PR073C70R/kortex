import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ocr_latex_live_editor.dart';
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
  group('OcrLatexLiveEditor Tests', () {
    const testSnippet = OcrExtractionEntity(
      id: 'snippet-1',
      documentId: 'doc-1',
      rawText: 'Acceleration is the rate of change of velocity',
      latexContent: r'a = \frac{dv}{dt}',
      topic: 'Kinematics',
    );

    testWidgets('renders card number, topic, answer, and latex formula preview',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          OcrLatexLiveEditor(
            snippet: testSnippet,
            cardNumber: 3,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CARD #3'), findsOneWidget);
      expect(find.text('Kinematics'), findsOneWidget);
      expect(find.text('Acceleration is the rate of change of velocity'),
          findsOneWidget);
      expect(find.byType(LatexMathPreviewBox), findsOneWidget);
    });

    testWidgets('dispatches onDelete callback when delete button is pressed',
        (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        _wrap(
          OcrLatexLiveEditor(
            snippet: testSnippet,
            cardNumber: 1,
            onDelete: () => deleted = true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteIcon, findsOneWidget);
      await tester.tap(deleteIcon);
      expect(deleted, isTrue);
    });

    testWidgets('displays ExtractedDiagramPreviewSection when imageUrl is present',
        (tester) async {
      const diagramSnippet = OcrExtractionEntity(
        id: 'snippet-2',
        documentId: 'doc-1',
        rawText: 'Circuit diagram showing resistors in parallel',
        imageUrl: 'https://example.com/circuit.png',
        topic: 'Electronics',
      );

      await tester.pumpWidget(
        _wrap(
          OcrLatexLiveEditor(
            snippet: diagramSnippet,
            cardNumber: 2,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DIAGRAM'), findsOneWidget);
      expect(find.byType(ExtractedDiagramPreviewSection), findsOneWidget);
    });
  });
}
