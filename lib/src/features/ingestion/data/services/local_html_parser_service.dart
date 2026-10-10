import 'dart:convert';
import 'dart:typed_data';
import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

/// Native HTML and XHTML parser service.
///
/// Converts web pages and XHTML chapters into structured, Markdown-compatible
/// text representation preserving:
/// - Semantic heading hierarchy (h1 through h6)
/// - Mathematical notation (MathJax, KaTeX, MathML, Greek entities, sub/sup)
/// - Markdown-formatted tables (table, tr, th, td)
/// - Syntax-fenced code blocks (pre, code with language class)
/// - Figures and images with captions (figure, img, figcaption)
/// - Lists and paragraphs
class LocalHtmlParserService {
  const LocalHtmlParserService();

  static const LocalHtmlParserService instance = LocalHtmlParserService();

  /// Extracts structured text from HTML bytes synchronously.
  static String extractTextFromBytesSync(
    Uint8List bytes, {
    String? filename,
    ExtractionReport? report,
  }) {
    if (bytes.isEmpty) {
      return '';
    }
    final html = utf8.decode(bytes, allowMalformed: true);
    return extractTextFromString(html, filename: filename, report: report);
  }

  /// Extracts structured text from an HTML/XHTML string synchronously.
  static String extractTextFromString(
    String html, {
    String? filename,
    ExtractionReport? report,
  }) {
    if (html.trim().isEmpty) {
      return '';
    }

    try {
      var content = html;

      // 1. Strip style tags
      content = content.replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
        '',
      );

      // 2. Extract and convert MathJax formulas in scripts before stripping scripts
      content = content.replaceAllMapped(
        RegExp(
          r'<script[^>]*type="math/tex;\s*mode=display"[^>]*>([\s\S]*?)</script>',
          caseSensitive: false,
        ),
        (m) => '\n\n\$\$${m.group(1)!.trim()}\$\$\n\n',
      );

      content = content.replaceAllMapped(
        RegExp(
          r'<script[^>]*type="math/tex"[^>]*>([\s\S]*?)</script>',
          caseSensitive: false,
        ),
        (m) => ' \$${m.group(1)!.trim()}\$ ',
      );

      // 3. Strip remaining non-math script tags
      content = content.replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
        '',
      );

      // 4. Extract KaTeX annotations and arithmatex wrappers
      content = content.replaceAllMapped(
        RegExp(
          r'<span[^>]*class="[^"]*katex[^"]*"[^>]*>[\s\S]*?<annotation[^>]*encoding="application/x-tex"[^>]*>([\s\S]*?)</annotation>[\s\S]*?</span>',
          caseSensitive: false,
        ),
        (m) => ' \$${m.group(1)!.trim()}\$ ',
      );

      content = content.replaceAllMapped(
        RegExp(
          r'<div[^>]*class="[^"]*arithmatex[^"]*"[^>]*>\s*\\\[([\s\S]*?)\\\]\s*</div>',
          caseSensitive: false,
        ),
        (m) => '\n\n\$\$${m.group(1)!.trim()}\$\$\n\n',
      );

      content = content.replaceAllMapped(
        RegExp(
          r'<span[^>]*class="[^"]*arithmatex[^"]*"[^>]*>\s*\\\(([\s\S]*?)\\\)\s*</span>',
          caseSensitive: false,
        ),
        (m) => ' \$${m.group(1)!.trim()}\$ ',
      );

      // 5. Convert MathML to LaTeX
      content = content.replaceAllMapped(
        RegExp(r'<math[^>]*>([\s\S]*?)</math>', caseSensitive: false),
        (m) {
          final latex = FormulaExtractionService.convertMathMLToLatex(m.group(0)!);
          return latex.isNotEmpty ? ' \$$latex\$ ' : '';
        },
      );

      // 6. Convert sub and sup into LaTeX-like subscripts/superscripts
      content = content
          .replaceAllMapped(
            RegExp('<sub>(.*?)</sub>', caseSensitive: false),
            (m) => '_{${m.group(1)}}',
          )
          .replaceAllMapped(
            RegExp('<sup>(.*?)</sup>', caseSensitive: false),
            (m) => '^{${m.group(1)}}',
          );

      // 7. Extract code blocks (<pre><code> or <pre>)
      final codePlaceholders = <String, String>{};
      var codeIndex = 0;

      content = content.replaceAllMapped(
        RegExp(r'<pre[^>]*>([\s\S]*?)</pre>', caseSensitive: false),
        (m) {
          final preBody = m.group(1)!;
          var lang = '';
          var rawCode = preBody;

          final codeMatch = RegExp(
            r'<code([^>]*)>([\s\S]*?)</code>',
            caseSensitive: false,
          ).firstMatch(preBody);

          if (codeMatch != null) {
            final attrs = codeMatch.group(1)!;
            rawCode = codeMatch.group(2) ?? '';
            final classMatch = RegExp('class="([^"]*)"', caseSensitive: false).firstMatch(attrs);
            if (classMatch != null) {
              final classVal = classMatch.group(1)!;
              for (final token in classVal.split(RegExp(r'\s+'))) {
                if (token.startsWith('language-')) {
                  lang = token.substring(9);
                  break;
                } else if (token.startsWith('lang-')) {
                  lang = token.substring(5);
                  break;
                } else if (token.isNotEmpty && lang.isEmpty) {
                  lang = token;
                }
              }
            }
          }

          rawCode = _unescapeHtml(rawCode);

          final placeholder = '___HTML_CODE_BLOCK_${codeIndex++}___';
          final fencedCode = '\n\n```$lang\n${rawCode.trimRight()}\n```\n\n';
          codePlaceholders[placeholder] = fencedCode;
          return placeholder;
        },
      );

      // Inline code
      content = content.replaceAllMapped(
        RegExp(r'<code[^>]*>([\s\S]*?)</code>', caseSensitive: false),
        (m) {
          final inlineCode = _unescapeHtml(m.group(1)!);
          return ' `$inlineCode` ';
        },
      );

      // 8. Convert HTML tables into Markdown tables
      content = content.replaceAllMapped(
        RegExp(r'<table[^>]*>([\s\S]*?)</table>', caseSensitive: false),
        (m) => _parseHtmlTable(m.group(1)!),
      );

      // 9. Convert figures with figcaption
      content = content.replaceAllMapped(
        RegExp(r'<figure[^>]*>([\s\S]*?)</figure>', caseSensitive: false),
        (m) {
          final figureBody = m.group(1)!;
          var caption = '';
          var imgSrc = '';
          var imgAlt = '';

          final figcaptionMatch = RegExp(
            r'<figcaption[^>]*>([\s\S]*?)</figcaption>',
            caseSensitive: false,
          ).firstMatch(figureBody);

          if (figcaptionMatch != null) {
            caption = _cleanHtmlInline(figcaptionMatch.group(1)!);
          }

          final imgMatch = RegExp(
            '<img[^>]*src="([^"]+)"[^>]*>',
            caseSensitive: false,
          ).firstMatch(figureBody);

          if (imgMatch != null) {
            imgSrc = imgMatch.group(1) ?? '';
            final altMatch = RegExp(
              'alt="([^"]*)"',
              caseSensitive: false,
            ).firstMatch(imgMatch.group(0)!);
            imgAlt = altMatch != null ? altMatch.group(1) ?? '' : '';
          }

          final buffer = StringBuffer('\n\n');
          if (imgSrc.isNotEmpty) {
            final label = caption.isNotEmpty ? caption : imgAlt;
            buffer.writeln('![$label]($imgSrc)');
          }
          if (caption.isNotEmpty) {
            buffer.writeln(caption);
          }
          buffer.write('\n');
          return buffer.toString();
        },
      );

      // Standalone img tags
      content = content.replaceAllMapped(
        RegExp('<img[^>]*>', caseSensitive: false),
        (m) {
          final tag = m.group(0)!;
          final srcMatch = RegExp(
            'src="([^"]+)"',
            caseSensitive: false,
          ).firstMatch(tag);
          final altMatch = RegExp(
            'alt="([^"]*)"',
            caseSensitive: false,
          ).firstMatch(tag);

          final src = srcMatch != null ? srcMatch.group(1) ?? '' : '';
          final alt = altMatch != null ? altMatch.group(1) ?? '' : '';
          return src.isNotEmpty ? '\n\n![$alt]($src)\n\n' : '';
        },
      );

      // 10. Headings (h1 - h6)
      for (var level = 1; level <= 6; level++) {
        final hashes = '#' * level;
        content = content.replaceAllMapped(
          RegExp('<h$level[^>]*>([\\s\\S]*?)</h$level>', caseSensitive: false),
          (m) {
            final headingText = _cleanHtmlInline(m.group(1)!);
            return '\n\n$hashes $headingText\n\n';
          },
        );
      }

      // 11. Lists
      content = content.replaceAllMapped(
        RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false),
        (m) {
          final itemText = _cleanHtmlInline(m.group(1)!);
          return '\n- $itemText';
        },
      );

      // 12. Structural block dividers
      content = content
          .replaceAll(
            RegExp(
              '</?(?:p|div|section|article|header|footer|aside|main|blockquote|ul|ol)[^>]*>',
              caseSensitive: false,
            ),
            '\n\n',
          )
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n---\n');

      // 13. Strip any remaining HTML tags
      content = content.replaceAll(RegExp('<[^>]+>'), '');

      // 14. Unescape remaining HTML and Greek entities
      content = _unescapeHtml(content);

      // 15. Restore protected code blocks
      for (final entry in codePlaceholders.entries) {
        content = content.replaceAll(entry.key, entry.value);
      }

      // 16. Normalize whitespace
      return _normalizeOutput(content);
    } catch (e) {
      report?.isCorrupt = true;
      report?.recordDrop(rule: 'html_parser_exception', sampleText: '$e');
      throw CorruptDocumentException(
        filename ?? 'document.html',
        'Malformed HTML file: $e',
      );
    }
  }

  /// Extracts structured text asynchronously.
  Future<String> extractText(
    Uint8List bytes, {
    String? filename,
    ExtractionReport? report,
  }) async {
    return extractTextFromBytesSync(
      bytes,
      filename: filename,
      report: report,
    );
  }

  /// Parses an HTML table element into Markdown table syntax.
  static String _parseHtmlTable(String tableHtml) {
    final rows = <List<String>>[];

    final trMatches = RegExp(
      r'<tr[^>]*>([\s\S]*?)</tr>',
      caseSensitive: false,
    ).allMatches(tableHtml);

    for (final tr in trMatches) {
      final rowHtml = tr.group(1)!;
      final cells = <String>[];

      final cellMatches = RegExp(
        r'<(th|td)[^>]*>([\s\S]*?)</\1>',
        caseSensitive: false,
      ).allMatches(rowHtml);

      for (final cell in cellMatches) {
        final rawCellText = _cleanHtmlInline(cell.group(2)!);
        final cleanCell = rawCellText
            .replaceAll('\n', ' ')
            .replaceAll('|', r'\|')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        cells.add(cleanCell);
      }

      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }

    if (rows.isEmpty) {
      return '';
    }

    var maxCols = 0;
    for (final row in rows) {
      if (row.length > maxCols) {
        maxCols = row.length;
      }
    }

    if (maxCols == 0) {
      return '';
    }

    for (final row in rows) {
      while (row.length < maxCols) {
        row.add('');
      }
    }

    final buffer = StringBuffer('\n\n');

    final header = rows.first;
    buffer.writeln('| ${header.join(' | ')} |');

    final divider = List.filled(maxCols, '---');
    buffer.writeln('| ${divider.join(' | ')} |');

    for (var i = 1; i < rows.length; i++) {
      buffer.writeln('| ${rows[i].join(' | ')} |');
    }

    buffer.write('\n');
    return buffer.toString();
  }

  /// Cleans inline HTML tags and resolves entities.
  static String _cleanHtmlInline(String input) {
    final text = input
        .replaceAllMapped(
          RegExp('<sub>(.*?)</sub>', caseSensitive: false),
          (m) => '_{${m.group(1)}}',
        )
        .replaceAllMapped(
          RegExp('<sup>(.*?)</sup>', caseSensitive: false),
          (m) => '^{${m.group(1)}}',
        )
        .replaceAll(RegExp('<[^>]+>'), '')
        .trim();

    return _unescapeHtml(text);
  }

  /// Resolves standard HTML, math, and Greek entity codes to text or LaTeX symbols.
  static String _unescapeHtml(String input) {
    return input
        // Greek & Math entities
        .replaceAll('&nabla;', r'\nabla ')
        .replaceAll('&hbar;', r'\hbar ')
        .replaceAll('&pi;', r'\pi ')
        .replaceAll('&theta;', r'\theta ')
        .replaceAll('&phi;', r'\phi ')
        .replaceAll('&epsilon;', r'\epsilon ')
        .replaceAll('&alpha;', r'\alpha ')
        .replaceAll('&beta;', r'\beta ')
        .replaceAll('&gamma;', r'\gamma ')
        .replaceAll('&delta;', r'\delta ')
        .replaceAll('&sigma;', r'\sigma ')
        .replaceAll('&omega;', r'\omega ')
        .replaceAll('&mu;', r'\mu ')
        .replaceAll('&nu;', r'\nu ')
        .replaceAll('&rho;', r'\rho ')
        .replaceAll('&psi;', r'\psi ')
        .replaceAll('&lambda;', r'\lambda ')
        .replaceAll('&Delta;', r'\Delta ')
        .replaceAll('&Lambda;', r'\Lambda ')
        .replaceAll('&Sigma;', r'\Sigma ')
        .replaceAll('&Omega;', r'\Omega ')
        .replaceAll('&partial;', r'\partial ')
        .replaceAll('&part;', r'\partial ')
        .replaceAll('&infin;', r'\infty ')
        .replaceAll('&plusmn;', r'\pm ')
        .replaceAll('&times;', r'\times ')
        .replaceAll('&middot;', r'\cdot ')
        .replaceAll('&le;', r'\le ')
        .replaceAll('&ge;', r'\ge ')
        .replaceAll('&ne;', r'\neq ')
        .replaceAll('&approx;', r'\approx ')
        .replaceAll('&sum;', r'\sum ')
        .replaceAll('&prod;', r'\prod ')
        .replaceAll('&int;', r'\int ')
        .replaceAll('&rang;', r'\rangle ')
        .replaceAll('&lang;', r'\langle ')
        .replaceAll('&radic;', r'\sqrt ')
        .replaceAll('&rarr;', r'\rightarrow ')
        .replaceAll('&larr;', r'\leftarrow ')
        // Common HTML entities
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#27;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&deg;', '°')
        .replaceAll('&bull;', '•');
  }

  /// Normalizes whitespace and removes excessive linebreaks.
  static String _normalizeOutput(String input) {
    final lines = input.split('\n');
    final cleaned = <String>[];
    var emptyLineCount = 0;

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        emptyLineCount++;
        if (emptyLineCount <= 2) {
          cleaned.add('');
        }
      } else {
        emptyLineCount = 0;
        cleaned.add(trimmed);
      }
    }

    return cleaned.join('\n').trim();
  }
}
