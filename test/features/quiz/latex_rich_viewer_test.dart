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

    testWidgets('formats inline points (1)-(8) onto new lines with bold markers and start alignment', (tester) async {
      const runOnText =
          'Verify: (1) price is above or below the 50/200 EMA in the intended direction; '
          '(2) clear supporting structure exists; '
          '(3) the setup is continuation-based; '
          '(4) the M15 high or low is ideally inside an imbalance or is a session extreme; '
          '(5) price swept the level and closed with weakness; '
          '(6) the rectangle is drawn from the trigger candle’s close to its high or low; '
          '(7) the stop loss is beyond the relevant extreme; and '
          '(8) take profit targets at least 3:1 reward-to-risk or the next strong M15 key level.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LatexRichViewer(
              text: runOnText,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTexts = tester.widgetList<RichText>(find.byType(RichText)).toList();
      // Should have separate widgets for intro and each point
      expect(richTexts.length, greaterThanOrEqualTo(8));

      // Verify that list items are aligned to start (left) even when textAlign: center was passed
      final listRichText = richTexts.firstWhere(
        (rt) => rt.text.toPlainText().contains('(1)'),
      );
      expect(listRichText.textAlign, equals(TextAlign.start));

      // Verify (1) marker is bolded
      final spans = <TextSpan>[];
      listRichText.text.visitChildren((s) {
        if (s is TextSpan) spans.add(s);
        return true;
      });
      final boldMarkerSpan = spans.firstWhere(
        (s) => s.text == '(1)',
        orElse: () => const TextSpan(text: 'NOT_FOUND'),
      );
      expect(boldMarkerSpan.style?.fontWeight, equals(FontWeight.bold));

      // Verify (8) is present without "; and" connector
      final item8Text = richTexts.firstWhere(
        (rt) => rt.text.toPlainText().contains('(8)'),
      );
      expect(item8Text.text.toPlainText().contains('; and'), isFalse);
    });

    test('formatInlineLists does not alter regular non-sequential text with single numbers', () {
      const normalText = 'In (2024), 5 students scored over 90% on exam 1.';
      final formatted = LatexRichViewer.formatInlineLists(normalText);
      expect(formatted, equals(normalText));
    });

    test('formatInlineLists converts letter sequences (a)-(c) to lines', () {
      const text = 'Phases: (a) initiation; (b) planning; and (c) execution.';
      final formatted = LatexRichViewer.formatInlineLists(text);
      expect(formatted.contains('Phases:'), isTrue);
      expect(formatted.contains('(a) initiation'), isTrue);
      expect(formatted.contains('(b) planning'), isTrue);
      expect(formatted.contains('(c) execution'), isTrue);
    });
  });
}
