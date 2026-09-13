import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LatexRichViewer Markdown Tests', () {
    testWidgets('renders bold and italic correctly including trailing space within asterisks', (tester) async {
      const text = '**We** have been looking for a w3auyt tp male this a realty am,so mngr and yet intere *way * of lie ~~to be very honet~~';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatexRichViewer(text: text),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsOneWidget);

      final richText = tester.widget<RichText>(richTextFinder);
      final inlineSpan = richText.text;

      // Extract all spans
      final spans = <TextSpan>[];
      inlineSpan.visitChildren((span) {
        if (span is TextSpan) {
          spans.add(span);
        }
        return true;
      });

      // Find the italic span
      final italicSpan = spans.firstWhere(
        (s) => s.style?.fontStyle == FontStyle.italic,
        orElse: () => const TextSpan(text: 'NOT_FOUND'),
      );

      expect(italicSpan.text, equals('way'));
      expect(italicSpan.style?.fontStyle, equals(FontStyle.italic));

      // Find bold span
      final boldSpan = spans.firstWhere(
        (s) => s.style?.fontWeight == FontWeight.bold,
        orElse: () => const TextSpan(text: 'NOT_FOUND'),
      );
      expect(boldSpan.text, equals('We'));
      expect(boldSpan.style?.fontWeight, equals(FontStyle.italic == boldSpan.style?.fontStyle ? null : FontWeight.bold));

      // Find strikethrough span
      final strikeSpan = spans.firstWhere(
        (s) => s.style?.decoration == TextDecoration.lineThrough,
        orElse: () => const TextSpan(text: 'NOT_FOUND'),
      );
      expect(strikeSpan.text, equals('to be very honet'));
    });

    testWidgets('renders simple italic *hello*', (tester) async {
      const text = 'This is *italic text* in a sentence.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatexRichViewer(text: text),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final spans = <TextSpan>[];
      richText.text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });

      final italicSpan = spans.firstWhere(
        (s) => s.style?.fontStyle == FontStyle.italic,
        orElse: () => const TextSpan(text: 'NOT_FOUND'),
      );

      expect(italicSpan.text, equals('italic text'));
    });

    testWidgets('renders underscore italic _italic_', (tester) async {
      const text = 'This is _underscore italic_ here.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatexRichViewer(text: text),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final spans = <TextSpan>[];
      richText.text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });

      final italicSpan = spans.firstWhere(
        (s) => s.style?.fontStyle == FontStyle.italic,
        orElse: () => const TextSpan(text: 'NOT_FOUND'),
      );

      expect(italicSpan.text, equals('underscore italic'));
    });

    testWidgets('renders mixed bold, italic, strikethrough, and inline code in paragraph', (tester) async {
      const text = 'Mix of **bold word**, *italic phrase*, `code snippet`, and ~~strikethrough~~ all together.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatexRichViewer(text: text),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final spans = <TextSpan>[];
      richText.text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });

      expect(spans.any((s) => s.text == 'bold word' && s.style?.fontWeight == FontWeight.bold), isTrue);
      expect(spans.any((s) => s.text == 'italic phrase' && s.style?.fontStyle == FontStyle.italic), isTrue);
      expect(spans.any((s) => s.text == 'strikethrough' && s.style?.decoration == TextDecoration.lineThrough), isTrue);
      expect(spans.any((s) => s.text?.contains('code snippet') == true && s.style?.fontFamily == 'monospace'), isTrue);
    });
  });
}
