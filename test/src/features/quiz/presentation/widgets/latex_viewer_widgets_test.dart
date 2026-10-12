import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_inline_markdown_parser.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_paragraph_builder.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('LatexViewer Subcomponents Tests', () {
    test('LatexTextSanitizer detects RTL scripts correctly', () {
      expect(LatexTextSanitizer.isRtlString('مرحبا بالعالم'), isTrue);
      expect(LatexTextSanitizer.isRtlString('Hello world'), isFalse);
    });

    test('LatexTextSanitizer strips script tags and on* attributes', () {
      const malicious = '<script>bad();</script><p onclick="hack()">Test</p>';
      final clean = LatexTextSanitizer.sanitizeRawText(malicious);
      expect(clean, isNot(contains('<script>')));
      expect(clean, isNot(contains('onclick')));
      expect(clean, contains('Test'));
    });

    test('LatexTextSanitizer sanitizes lone markdown artifacts', () {
      expect(LatexTextSanitizer.sanitizeLoneMarkdownSymbols('### Heading'), equals('Heading'));
      expect(LatexTextSanitizer.sanitizeLoneMarkdownSymbols('***Unclosed'), equals('Unclosed'));
    });

    testWidgets('LatexFormulaBlock renders valid LaTeX equation', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LatexFormulaBlock(
            formula: 'E = mc^2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LatexFormulaBlock), findsOneWidget);
    });

    testWidgets('LatexParagraphBuilder builds heading and blockquote properly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return LatexParagraphBuilder.buildParagraphLayout(
                context,
                '# Big Title\n> Important quote note\n• List item 1',
                const TextStyle(fontSize: 14),
                textAlign: TextAlign.start,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Big Title'), findsOneWidget);
      expect(find.textContaining('Important quote note'), findsOneWidget);
      expect(find.textContaining('List item 1'), findsOneWidget);
    });

    testWidgets('LatexInlineMarkdownParser creates monospace span for inline code', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              final spans = LatexInlineMarkdownParser.parseInlineMarkdownOnly(
                context,
                'Use `const` keyword',
                const TextStyle(fontSize: 14),
              );
              return Text.rich(TextSpan(children: spans));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('const'), findsOneWidget);
    });
  });
}
