import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

/// Deterministic parser transforming Markdown text into strongly-typed [DocumentIR]
/// with exact AST blocks, hierarchical section paths, and provenance tracking.
class MarkdownIrParser {
  const MarkdownIrParser();

  static final _headingRegex = RegExp(r'^(#{1,6})\s+(\S.*)$');
  static final _codeFenceRegex = RegExp(r'^(?:```|~~~)([a-zA-Z0-9_\-\+]*)\s*$');
  static final _displayMathStartRegex = RegExp(
    r'^(?:\$\$|\\\[|\\begin\{(?:equation|align|gather)\*?\})',
  );
  static final _displayMathEndRegex = RegExp(
    r'(?:\$\$|\\\]|\\end\{(?:equation|align|gather)\*?\})\s*$',
  );
  static final _unorderedListRegex = RegExp(r'^([-*+])\s+(\S.*)$');
  static final _orderedListRegex = RegExp(r'^(\d{1,3}[.)])\s+(\S.*)$');
  static final _tableRowRegex = RegExp(r'^\|(.+)\|\s*$');
  static final _tableDividerRegex = RegExp(r'^\|(?:\s*:?-+:?\s*\|)+\s*$');
  static final _imageRegex = RegExp(r'^!\[(.*?)\]\((.*?)\)\s*$');
  static final _pageNumberRegex = RegExp(
    r'^(?:page\s+\d+(\s+of\s+\d+)?|\d+\s*/\s*\d+|[-–—\s]*\d+[-–—\s]*)$',
    caseSensitive: false,
  );

  /// Parses [markdown] into a strongly-typed [DocumentIR].
  DocumentIR parse({
    required String markdown,
    String filename = 'document.md',
    String? documentId,
  }) {
    final docId =
        documentId ?? sha256.convert(utf8.encode(markdown)).toString();
    final lines = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    final blocks = <DocumentBlock>[];
    final sectionStack = <_HeadingLevelEntry>[];
    var currentPage = 1;
    var readingOrder = 0;

    List<String> currentSectionPath() =>
        sectionStack.map((e) => e.title).toList();

    var i = 0;
    while (i < lines.length) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      // Skip blank lines
      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // Check page break or page number metadata
      if (_pageNumberRegex.hasMatch(trimmed)) {
        final match = RegExp(r'\bpage\s+(\d+)\b', caseSensitive: false).firstMatch(trimmed);
        if (match != null) {
          final p = int.tryParse(match.group(1)!);
          if (p != null) currentPage = p;
        }
        i++;
        continue;
      }

      // 1. Code Blocks
      final codeFenceMatch = _codeFenceRegex.firstMatch(trimmed);
      if (codeFenceMatch != null) {
        final fence = trimmed.substring(0, 3);
        final language = codeFenceMatch.group(1)?.trim();
        final codeLines = <String>[];
        i++; // skip start fence

        while (i < lines.length) {
          final cur = lines[i];
          if (cur.trim().startsWith(fence)) {
            i++; // skip end fence
            break;
          }
          codeLines.add(cur);
          i++;
        }

        final codeText = codeLines.join('\n');
        blocks.add(
          CodeBlock(
            code: codeText,
            language: language?.isNotEmpty == true ? language : null,
            lineCount: codeLines.length,
            provenance: BlockProvenance(
              docId: docId,
              page: currentPage,
              readingOrder: readingOrder++,
              sectionPath: currentSectionPath(),
            ),
          ),
        );
        continue;
      }

      // 2. Display Math Blocks ($$, \[, \begin{equation})
      if (_displayMathStartRegex.hasMatch(trimmed)) {
        final mathLines = <String>[rawLine];
        final isSingleLine = _displayMathEndRegex.hasMatch(trimmed) && trimmed.length > 2;

        if (!isSingleLine) {
          i++;
          while (i < lines.length) {
            final cur = lines[i];
            mathLines.add(cur);
            if (_displayMathEndRegex.hasMatch(cur.trim())) {
              i++;
              break;
            }
            i++;
          }
        } else {
          i++;
        }

        final fullMath = mathLines.join('\n');
        final cleanLatex = fullMath
            .replaceAll(RegExp(r'^\$\$|^\s*\\\[|^\s*\\begin\{[a-zA-Z*]+\}'), '')
            .replaceAll(RegExp(r'\$\$$|\s*\\\]$|\s*\\end\{[a-zA-Z*]+\}$'), '')
            .trim();

        blocks.add(
          MathBlock(
            latex: cleanLatex.isNotEmpty ? cleanLatex : fullMath,
            isDisplay: true,
            rawMathText: fullMath,
            provenance: BlockProvenance(
              docId: docId,
              page: currentPage,
              readingOrder: readingOrder++,
              sectionPath: currentSectionPath(),
            ),
          ),
        );
        continue;
      }

      // 3. Figures / Images (![caption](url))
      final imageMatch = _imageRegex.firstMatch(trimmed);
      if (imageMatch != null) {
        final caption = imageMatch.group(1)?.trim();
        final url = imageMatch.group(2)?.trim();
        blocks.add(
          FigureBlock(
            imageRef: url,
            caption: caption?.isNotEmpty == true ? caption : null,
            label: _extractFigureLabel(caption),
            page: currentPage,
            provenance: BlockProvenance(
              docId: docId,
              page: currentPage,
              readingOrder: readingOrder++,
              sectionPath: currentSectionPath(),
            ),
          ),
        );
        i++;
        continue;
      }

      // 4. ATX Headings (# Heading)
      final headingMatch = _headingRegex.firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final title = headingMatch.group(2)!.trim();

        _updateSectionStack(sectionStack, level, title);

        blocks.add(
          HeadingBlock(
            text: title,
            level: level,
            provenance: BlockProvenance(
              docId: docId,
              page: currentPage,
              readingOrder: readingOrder++,
              sectionPath: currentSectionPath(),
            ),
          ),
        );
        i++;
        continue;
      }

      // 5. Setext Headings (Heading \n === or ---)
      if (i + 1 < lines.length) {
        final nextTrimmed = lines[i + 1].trim();
        if (RegExp(r'^={3,}$').hasMatch(nextTrimmed)) {
          _updateSectionStack(sectionStack, 1, trimmed);
          blocks.add(
            HeadingBlock(
              text: trimmed,
              level: 1,
              provenance: BlockProvenance(
                docId: docId,
                page: currentPage,
                readingOrder: readingOrder++,
                sectionPath: currentSectionPath(),
              ),
            ),
          );
          i += 2;
          continue;
        } else if (RegExp(r'^-{3,}$').hasMatch(nextTrimmed) && trimmed.length >= 2) {
          _updateSectionStack(sectionStack, 2, trimmed);
          blocks.add(
            HeadingBlock(
              text: trimmed,
              level: 2,
              provenance: BlockProvenance(
                docId: docId,
                page: currentPage,
                readingOrder: readingOrder++,
                sectionPath: currentSectionPath(),
              ),
            ),
          );
          i += 2;
          continue;
        }
      }

      // 6. Tables (| col1 | col2 |)
      if (_tableRowRegex.hasMatch(trimmed) && i + 1 < lines.length && _tableDividerRegex.hasMatch(lines[i + 1].trim())) {
        final headerRow = _parseTableRow(trimmed);
        i += 2; // skip header and divider

        final rows = <List<String>>[];
        while (i < lines.length && _tableRowRegex.hasMatch(lines[i].trim())) {
          rows.add(_parseTableRow(lines[i].trim()));
          i++;
        }

        blocks.add(
          TableBlock(
            headers: headerRow,
            rows: rows,
            provenance: BlockProvenance(
              docId: docId,
              page: currentPage,
              readingOrder: readingOrder++,
              sectionPath: currentSectionPath(),
            ),
          ),
        );
        continue;
      }

      // 7. Lists (Unordered or Ordered)
      final unorderedMatch = _unorderedListRegex.firstMatch(trimmed);
      final orderedMatch = _orderedListRegex.firstMatch(trimmed);
      if (unorderedMatch != null || orderedMatch != null) {
        final isOrdered = orderedMatch != null;
        final listItems = <ListItemBlock>[];
        var itemIndex = 0;

        while (i < lines.length) {
          final curTrimmed = lines[i].trim();
          if (curTrimmed.isEmpty) break;

          final uMatch = _unorderedListRegex.firstMatch(curTrimmed);
          final oMatch = _orderedListRegex.firstMatch(curTrimmed);

          if (isOrdered && oMatch != null) {
            final prefix = oMatch.group(1)!;
            final text = oMatch.group(2)!.trim();
            listItems.add(
              ListItemBlock(
                text: text,
                bulletPrefix: prefix,
                isOrdered: true,
                level: 1,
                provenance: BlockProvenance(
                  docId: docId,
                  page: currentPage,
                  readingOrder: itemIndex++,
                  sectionPath: currentSectionPath(),
                ),
              ),
            );
            i++;
          } else if (!isOrdered && uMatch != null) {
            final prefix = uMatch.group(1)!;
            final text = uMatch.group(2)!.trim();
            listItems.add(
              ListItemBlock(
                text: text,
                bulletPrefix: prefix,
                isOrdered: false,
                level: 1,
                provenance: BlockProvenance(
                  docId: docId,
                  page: currentPage,
                  readingOrder: itemIndex++,
                  sectionPath: currentSectionPath(),
                ),
              ),
            );
            i++;
          } else {
            // Continuation line of previous list item
            if (listItems.isNotEmpty) {
              final last = listItems.removeLast();
              listItems.add(
                ListItemBlock(
                  text: '${last.text} $curTrimmed',
                  bulletPrefix: last.bulletPrefix,
                  isOrdered: last.isOrdered,
                  level: last.level,
                  provenance: last.provenance,
                ),
              );
              i++;
            } else {
              break;
            }
          }
        }

        if (listItems.isNotEmpty) {
          blocks.add(
            ListBlock(
              isOrdered: isOrdered,
              items: listItems,
              provenance: BlockProvenance(
                docId: docId,
                page: currentPage,
                readingOrder: readingOrder++,
                sectionPath: currentSectionPath(),
              ),
            ),
          );
        }
        continue;
      }

      // 8. Chemical / Mathematical Formula Single Lines (e.g., C6H12O6 + 6O2 → 6CO2 + 6H2O + energy)
      if (_isStandaloneFormulaLine(trimmed)) {
        blocks.add(
          MathBlock(
            latex: trimmed,
            isDisplay: true,
            rawMathText: trimmed,
            provenance: BlockProvenance(
              docId: docId,
              page: currentPage,
              readingOrder: readingOrder++,
              sectionPath: currentSectionPath(),
            ),
          ),
        );
        i++;
        continue;
      }

      // 9. Prose Paragraphs
      final paragraphLines = <String>[rawLine];
      i++;
      while (i < lines.length) {
        final cur = lines[i];
        final curTrimmed = cur.trim();
        if (curTrimmed.isEmpty) break;
        if (_headingRegex.hasMatch(curTrimmed) ||
            _codeFenceRegex.hasMatch(curTrimmed) ||
            _displayMathStartRegex.hasMatch(curTrimmed) ||
            _imageRegex.hasMatch(curTrimmed) ||
            _unorderedListRegex.hasMatch(curTrimmed) ||
            _orderedListRegex.hasMatch(curTrimmed) ||
            _tableRowRegex.hasMatch(curTrimmed) ||
            _pageNumberRegex.hasMatch(curTrimmed) ||
            _isStandaloneFormulaLine(curTrimmed)) {
          break;
        }
        paragraphLines.add(cur);
        i++;
      }

      final fullParagraphText = paragraphLines.map((l) => l.trim()).join(' ').trim();
      final sentences = _splitSentences(fullParagraphText);

      blocks.add(
        ParagraphBlock(
          text: fullParagraphText,
          sentences: sentences,
          provenance: BlockProvenance(
            docId: docId,
            page: currentPage,
            readingOrder: readingOrder++,
            sectionPath: currentSectionPath(),
          ),
        ),
      );
    }

    return DocumentIR(
      docId: docId,
      filename: filename,
      blocks: blocks,
      metadata: {
        'parser': 'MarkdownIrParser',
        'line_count': lines.length,
        'page_count': currentPage,
      },
    );
  }

  static void _updateSectionStack(
    List<_HeadingLevelEntry> stack,
    int level,
    String title,
  ) {
    while (stack.isNotEmpty && stack.last.level >= level) {
      stack.removeLast();
    }
    stack.add(_HeadingLevelEntry(level, title));
  }

  static List<String> _parseTableRow(String line) {
    return line
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String? _extractFigureLabel(String? caption) {
    if (caption == null) return null;
    final match = RegExp(r'^(Figure\s+\d+|Fig\.\s*\d+)', caseSensitive: false).firstMatch(caption);
    return match?.group(0);
  }

  static bool _isStandaloneFormulaLine(String line) {
    if (line.contains('→') || line.contains('->') || line.contains(r'\to')) {
      return true;
    }
    if (RegExp(r'^[A-Za-z0-9_()]+\s*=\s*[A-Za-z0-9_()+\-*/^]+$').hasMatch(line) &&
        (line.contains('^') || line.contains('+') || line.contains('*') || line.contains('/'))) {
      return true;
    }
    return false;
  }

  static List<String> _splitSentences(String text) {
    if (text.isEmpty) return const [];
    final pattern = RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9])');
    final segments = text.split(pattern);
    return segments.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}

class _HeadingLevelEntry {
  const _HeadingLevelEntry(this.level, this.title);
  final int level;
  final String title;
}
