import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';

void main() {
  group('LatexRichViewer.sanitizeRawText', () {
    test('protects inline code from formula formatting mutation', () {
      const raw = '`if(x==1)`';
      final sanitized = LatexRichViewer.sanitizeRawText(raw);
      expect(sanitized, equals('`if(x==1)`'));
    });

    test('protects fenced code blocks from formula formatting mutation', () {
      const raw = '```dart\nif (x == 1) {\n  print("hello");\n}\n```';
      final sanitized = LatexRichViewer.sanitizeRawText(raw);
      expect(sanitized, equals(raw));
    });

    test('preserves blockquotes and strikethrough tags', () {
      const raw = '> quoted text\n~~strikethrough~~';
      final sanitized = LatexRichViewer.sanitizeRawText(raw);
      expect(sanitized, contains('> quoted text'));
      expect(sanitized, contains('~~strikethrough~~'));
    });

    test('sanitizes dangerous HTML scripts and events', () {
      const raw = '<script>alert(1)</script>Hello <b onclick="doBad()">World</b>';
      final sanitized = LatexRichViewer.sanitizeRawText(raw);
      expect(sanitized, contains('Hello **World**'));
      expect(sanitized, isNot(contains('<script>')));
      expect(sanitized, isNot(contains('onclick')));
    });

    test('retains LaTeX formulas while cleaning HTML entities', () {
      const raw = r'Solve &lt;i&gt;x&lt;/i&gt;: \(x^2 + 4 = 20\)';
      final sanitized = LatexRichViewer.sanitizeRawText(raw);
      expect(sanitized, contains('<i>x</i>'));
      expect(sanitized, contains(r'\(x^2 + 4 = 20\)'));
    });
  });
}
