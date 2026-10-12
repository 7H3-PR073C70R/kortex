import 'package:kortex/src/core/utils/latex_ast_cache.dart';
import 'package:kortex/src/features/quiz/domain/logic/formula_aware_text_formatter.dart';

/// Text sanitization, HTML entity cleanup, and inline list normalization
/// for LaTeX and Markdown viewing.
class LatexTextSanitizer {
  const LatexTextSanitizer._();

  static final RegExp rtlRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  static final RegExp codeBlockRegex = RegExp(
    r'```(?:([a-zA-Z0-9_\-+]*)(?:\r?\n|\s+))?([\s\S]*?)```',
    multiLine: true,
  );

  static final RegExp structuralBlockRegex = RegExp(
    r'(```(?:[a-zA-Z0-9_\-+]*\r?\n)?[\s\S]*?```|\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$)',
    multiLine: true,
  );

  static final RegExp latexRegex = RegExp(
    r'(\\\([\s\S]*?\\\)|\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\]|(?<!\\)\$(?!\$)((?:\\.|[^\$\n])+?)(?<!\\)\$)',
    multiLine: true,
  );

  static final RegExp inlineMarkdownRegex = RegExp(
    r'(\*\*\*(.+?)\*\*\*|___(.+?)___|\*\*(.+?)\*\*|__(.+?)__|(?<!\*)\*([^\*\n]+?)\*(?!\*)|(?<!_)_([^_\n]+?)_(?!_)|`([^`]+)`|~~(.+?)~~)',
    multiLine: true,
  );

  static final RegExp listLineRegex = RegExp(
    r'^\s*(?:(\*|-|•)\s+|(?:\(?\d+[\.\)]|\[\d+\])\s+|(?:\(?[A-Za-z][\.\)]|\([ivxIVX]+\)|[ivxIVX]+[\.\)])\s+)',
  );

  static const List<String> fontFamilyFallbacks = [
    'Geeza Pro',
    'Noto Naskh Arabic',
    'Noto Sans',
    'Roboto',
    'Arial',
  ];

  static bool isRtlString(String s) => rtlRegex.hasMatch(s);

  /// Sanitizes raw HTML entities, prompt artifacts, and reasoning tags.
  static String sanitizeRawText(String input) {
    if (input.trim().isEmpty) return '';
    return LatexAstCache.instance.getOrComputeSanitized(input, (raw) {
      var s = raw;

      // Strip reasoning tags & model prompt tokens & metadata comments
      s = s.replaceAll(
        RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false),
        '',
      );
      s = s.replaceAll(RegExp(r'<\/?think>', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'<\|[a-zA-Z0-9_\-]+\|>'), '');
      s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

      // Strip executable script tags, iframes, objects, and event handlers
      s = s.replaceAll(
        RegExp(
          r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
          caseSensitive: false,
        ),
        '',
      );
      s = s.replaceAll(
        RegExp(
          r'<\s*\/?\s*(?:script|iframe|object|embed|applet|style|form|input|meta|link)[^>]*>',
          caseSensitive: false,
        ),
        '',
      );
      s = s.replaceAll(
        RegExp(
          r'\s+on[a-zA-Z]+\s*=\s*(?:"[^"]*"|' r"'[^']*'|[^\s>]+)",
          caseSensitive: false,
        ),
        '',
      );
      s = s.replaceAll(RegExp(r'javascript:\s*', caseSensitive: false), '');

      // Replace common HTML tags and entities
      s = s.replaceAll(RegExp(r'<\s*br\s*\/?\s*>', caseSensitive: false), '\n');
      s = s.replaceAll(
        RegExp(r'<\s*\/?\s*(?:b|strong)\s*>', caseSensitive: false),
        '**',
      );
      s = s.replaceAll(
        RegExp(r'<\s*\/?\s*(?:i|em)\s*>', caseSensitive: false),
        '*',
      );
      s = s.replaceAll('&quot;', '"');
      s = s.replaceAll('&#039;', "'");
      s = s.replaceAll('&#39;', "'");
      s = s.replaceAll('&amp;', '&');
      s = s.replaceAll('&lt;', '<');
      s = s.replaceAll('&gt;', '>');
      s = s.replaceAll('&nbsp;', ' ');

      // Protect code blocks and inline code before formula formatting passes
      final codeBlocks = <String>[];
      s = s.replaceAllMapped(codeBlockRegex, (m) {
        final idx = codeBlocks.length;
        codeBlocks.add(m[0]!);
        return '%%KORTEX_CODE_BLOCK_$idx%%';
      });

      final inlineCodes = <String>[];
      s = s.replaceAllMapped(RegExp(r'`([^`\n]+)`'), (m) {
        final idx = inlineCodes.length;
        inlineCodes.add(m[0]!);
        return '%%KORTEX_INLINE_CODE_$idx%%';
      });

      s = formatInlineLists(s);
      s = FormulaAwareTextFormatter.formatFormulaAware(s);

      // Restore protected inline code and code blocks
      for (var i = 0; i < inlineCodes.length; i++) {
        s = s.replaceAll('%%KORTEX_INLINE_CODE_$i%%', inlineCodes[i]);
      }
      for (var i = 0; i < codeBlocks.length; i++) {
        s = s.replaceAll('%%KORTEX_CODE_BLOCK_$i%%', codeBlocks[i]);
      }

      return s.trim();
    });
  }

  /// Formats inline sequential lists (e.g. "Verify: (1) ...; (2) ...; and (8) ...")
  /// into clean, line-by-line list items.
  static String formatInlineLists(String text) {
    if (text.trim().isEmpty) return text;

    // Fast check: must contain enumeration indicators
    if (!text.contains(
      RegExp(r'\(\d+\)|\b\d+[\.\)]|\[\d+\]|\([a-zA-Z]\)|\([ivxIVX]+\)'),
    )) {
      return text;
    }

    final paragraphs = text.split('\n');
    final processed = <String>[];

    for (final p in paragraphs) {
      processed.add(_formatParagraphInlineList(p));
    }

    return processed.join('\n');
  }

  static String _formatParagraphInlineList(String paragraph) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) return paragraph;

    // Pattern to capture delimiter/connector before the enumeration marker and the marker itself
    final markerRegex = RegExp(
      r'(?:([;:\.]\s*(?:and\s+|or\s+)?|,\s*(?:and\s+|or\s+)|\s+(?:and\s+|or\s+)|\A\s*))(\((\d+|[a-zA-Z]|[ivxIVX]+)\)|\[(\d+)\]|(\d+)[\.\)]|\b([a-zA-Z])\)|\(([a-zA-Z])\)|\(([ivxIVX]+)\))\s+',
    );

    final matches = markerRegex.allMatches(trimmed).toList();
    if (matches.length < 2) {
      return paragraph;
    }

    // 1. Check numeric sequence: 1, 2, 3...
    final numericValues = <int>[];
    var isNumeric = true;
    for (final m in matches) {
      final markerStr = m.group(2) ?? '';
      final numStr = RegExp(r'\d+').firstMatch(markerStr)?.group(0);
      if (numStr != null) {
        numericValues.add(int.parse(numStr));
      } else {
        isNumeric = false;
        break;
      }
    }

    var isValidSequence = false;
    if (isNumeric && numericValues.length >= 2) {
      if (numericValues.first == 1 || numericValues.first == 0) {
        isValidSequence = true;
        for (var i = 0; i < numericValues.length - 1; i++) {
          if (numericValues[i + 1] != numericValues[i] + 1) {
            isValidSequence = false;
            break;
          }
        }
      }
    }

    // 2. Check letter sequence: a, b, c...
    if (!isValidSequence && !isNumeric) {
      final letters = <String>[];
      for (final m in matches) {
        final markerStr = m.group(2) ?? '';
        final l = RegExp(
          '[a-zA-Z]',
        ).firstMatch(markerStr)?.group(0)?.toLowerCase();
        if (l != null && l.length == 1) {
          letters.add(l);
        }
      }
      if (letters.length >= 2 && letters.first == 'a') {
        isValidSequence = true;
        for (var i = 0; i < letters.length - 1; i++) {
          if (letters[i + 1].codeUnitAt(0) != letters[i].codeUnitAt(0) + 1) {
            isValidSequence = false;
            break;
          }
        }
      }
    }

    // 3. Check roman numeral sequence: i, ii, iii...
    if (!isValidSequence && !isNumeric) {
      const romans = [
        'i',
        'ii',
        'iii',
        'iv',
        'v',
        'vi',
        'vii',
        'viii',
        'ix',
        'x',
      ];
      final extractedRomans = <String>[];
      for (final m in matches) {
        final markerStr = m.group(2) ?? '';
        final r = RegExp(
          '[ivxIVX]+',
        ).firstMatch(markerStr)?.group(0)?.toLowerCase();
        if (r != null) {
          extractedRomans.add(r);
        }
      }
      if (extractedRomans.length >= 2 && extractedRomans.first == 'i') {
        isValidSequence = true;
        for (var i = 0; i < extractedRomans.length; i++) {
          if (i < romans.length && extractedRomans[i] != romans[i]) {
            isValidSequence = false;
            break;
          }
        }
      }
    }

    if (!isValidSequence) {
      return paragraph;
    }

    final buffer = StringBuffer();
    final firstMatch = matches.first;

    var rawIntro = trimmed.substring(0, firstMatch.start).trim();
    final connector = firstMatch.group(1) ?? '';
    if (connector.startsWith(':') || connector.startsWith('.')) {
      rawIntro = (rawIntro + connector[0]).trim();
    }

    if (rawIntro.isNotEmpty) {
      buffer
        ..writeln(rawIntro)
        ..writeln(); // Separate intro header with blank line
    }

    for (var i = 0; i < matches.length; i++) {
      final currentMatch = matches[i];
      final marker = currentMatch.group(2)!;
      final contentStart = currentMatch.end;
      final contentEnd = (i < matches.length - 1)
          ? matches[i + 1].start
          : trimmed.length;

      var itemContent = trimmed.substring(contentStart, contentEnd).trim();
      // Remove trailing delimiters like "; and", "; or", ";" or "," if at the end of the item
      itemContent = itemContent
          .replaceAll(RegExp(r'[;,]\s*(?:and|or)$', caseSensitive: false), '')
          .trim();

      buffer.writeln('$marker $itemContent');
    }

    return buffer.toString().trim();
  }

  /// Removes stray unclosed asterisks or raw '#' symbols so users never see markdown artifacts.
  static String sanitizeLoneMarkdownSymbols(String s) {
    var out = s;
    // Strip leading '#' or '>' that may have slipped through
    out = out.replaceAll(RegExp(r'^#{1,6}\s*'), '');
    out = out.replaceAll(RegExp(r'^>\s*'), '');
    // Clean redundant double asterisks that have no closing tag
    out = out.replaceAll('***', '');
    out = out.replaceAll('**', '');
    return out;
  }
}
