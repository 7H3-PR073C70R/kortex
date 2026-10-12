import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_formula_block.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_inline_markdown_parser.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_text_sanitizer.dart';
import 'package:kortex/src/shared/widgets/app_code_block_viewer.dart';

/// Renders paragraphs, block quotes, headings, bullet/numbered lists,
/// and embedded code or LaTeX equation blocks.
class LatexParagraphBuilder {
  const LatexParagraphBuilder._();

  static Widget buildBlockAndInlineContent(
    BuildContext context,
    String content,
    TextStyle defaultStyle, {
    required TextAlign textAlign,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
    bool? forceRtl,
  }) {
    final widgets = <Widget>[];
    final matches =
        LatexTextSanitizer.structuralBlockRegex.allMatches(content);
    var lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final textBlock = content.substring(lastEnd, match.start).trim();
        if (textBlock.isNotEmpty) {
          widgets
            ..add(
              buildParagraphLayout(
                context,
                textBlock,
                defaultStyle,
                textAlign: textAlign,
                maxLines: maxLines,
                overflow: overflow,
                forceRtl: forceRtl,
              ),
            )
            ..add(const SizedBox(height: 8));
        }
      }

      final rawBlock = match.group(0) ?? '';

      // Check if this structural block is a fenced code block
      if (rawBlock.startsWith('```')) {
        final codeMatch = LatexTextSanitizer.codeBlockRegex.firstMatch(rawBlock);
        final lang = codeMatch?.group(1)?.trim();
        final code = codeMatch?.group(2) ?? '';
        widgets
          ..add(
            AppCodeBlockViewer(
              code: code,
              language: lang,
            ),
          )
          ..add(const SizedBox(height: 8));
      } else {
        // Block LaTeX math formula
        var cleanFormula = rawBlock;
        if (cleanFormula.startsWith(r'\[') && cleanFormula.endsWith(r'\]')) {
          cleanFormula = cleanFormula.substring(2, cleanFormula.length - 2);
        } else if (cleanFormula.startsWith(r'$$') &&
            cleanFormula.endsWith(r'$$')) {
          cleanFormula = cleanFormula.substring(2, cleanFormula.length - 2);
        }
        cleanFormula = cleanFormula.trim();

        if (cleanFormula.isNotEmpty) {
          widgets
            ..add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: LatexFormulaBlock(
                  formula: cleanFormula,
                  textStyle: defaultStyle,
                ),
              ),
            )
            ..add(const SizedBox(height: 8));
        }
      }

      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        widgets.add(
          buildParagraphLayout(
            context,
            remaining,
            defaultStyle,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            forceRtl: forceRtl,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  static Widget buildParagraphLayout(
    BuildContext context,
    String content,
    TextStyle defaultStyle, {
    required TextAlign textAlign,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
    bool? forceRtl,
  }) {
    // Split by double newline to preserve paragraph separation
    final paragraphs = content.split(RegExp(r'\n{2,}'));
    if (paragraphs.length <= 1) {
      return buildSingleParagraph(
        context,
        content,
        defaultStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        forceRtl: forceRtl,
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i].trim();
      if (p.isEmpty) continue;
      children.add(
        buildSingleParagraph(
          context,
          p,
          defaultStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          forceRtl: forceRtl,
        ),
      );
      if (i < paragraphs.length - 1) {
        children.add(const SizedBox(height: 10));
      }
    }

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static Widget buildSingleParagraph(
    BuildContext context,
    String paragraph,
    TextStyle defaultStyle, {
    required TextAlign textAlign,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
    bool? forceRtl,
  }) {
    final lines = paragraph.split('\n');
    final lineWidgets = <Widget>[];

    final isParagraphRtl =
        forceRtl ?? LatexTextSanitizer.isRtlString(paragraph);
    final paragraphDirection = isParagraphRtl
        ? TextDirection.rtl
        : TextDirection.ltr;

    final isListParagraph = lines
        .where((l) => l.trim().isNotEmpty)
        .any((l) => LatexTextSanitizer.listLineRegex.hasMatch(l.trim()));

    final effectiveTextAlign = textAlign == TextAlign.center
        ? (isListParagraph ? TextAlign.start : TextAlign.center)
        : (isParagraphRtl ? TextAlign.right : textAlign);

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      var lineStyle = defaultStyle;
      var contentToRender = line;

      // 1. Heading check: '#', '##', '###' -> style as bold heading without raw '#'
      final headingMatch =
          RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmedLine);
      if (headingMatch != null) {
        final level = headingMatch.group(1)?.length ?? 1;
        contentToRender = headingMatch.group(2) ?? '';
        final scale = level == 1 ? 1.25 : (level == 2 ? 1.15 : 1.08);
        lineStyle = defaultStyle.copyWith(
          fontSize: (defaultStyle.fontSize ?? 15) * scale,
          fontWeight: FontWeight.bold,
        );
      }

      // 2. Blockquote check: lines starting with '>' or '&gt;'
      final quoteMatch = RegExp(r'^(?:>|&gt;)\s*(.*)$', caseSensitive: false)
          .firstMatch(trimmedLine);
      if (quoteMatch != null) {
        final quoteBody = quoteMatch.group(1) ?? '';
        final spans = LatexInlineMarkdownParser.parseInlineMarkdownAndLatex(
          context,
          quoteBody,
          lineStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: context.colors.textSecondary,
          ),
        );

        lineWidgets.add(
          Directionality(
            textDirection: paragraphDirection,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: BoxDecoration(
                  color: context.colors.primary
                      .withAlpha(context.isDarkMode ? 30 : 18),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border(
                    left: BorderSide(
                      color: context.colors.primary,
                      width: 3.5,
                    ),
                  ),
                ),
                child: Text.rich(
                  TextSpan(children: spans),
                  textAlign: effectiveTextAlign,
                  maxLines: maxLines,
                  overflow: overflow,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // 3. Bullet list check: '-', '*', '•' -> style cleanly without loose asterisks
      final bulletMatch =
          RegExp(r'^(\*|-|•)\s+(.*)$').firstMatch(trimmedLine);
      if (bulletMatch != null) {
        contentToRender = '•  ${bulletMatch.group(2) ?? ''}';
      }

      // 4. Numbered / bracketed / lettered list check
      final numMatch = RegExp(
        r'^(\(?\d+[\.\)]|\[\d+\]|\(?[A-Za-z][\.\)]|\(?[ivxIVX]+[\.\)])\s+(.*)$',
      ).firstMatch(trimmedLine);
      if (numMatch != null) {
        final marker = numMatch.group(1)!;
        final body = numMatch.group(2) ?? '';
        contentToRender = '**$marker**  $body';
      }

      // Render line with mixed Markdown & LaTeX spans
      final spans = LatexInlineMarkdownParser.parseInlineMarkdownAndLatex(
        context,
        contentToRender,
        lineStyle,
      );

      final isItemInList = isListParagraph &&
          LatexTextSanitizer.listLineRegex.hasMatch(trimmedLine);
      lineWidgets.add(
        Directionality(
          textDirection: paragraphDirection,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: isItemInList ? 8.0 : 0.0,
              left: (isListParagraph && !isParagraphRtl) ? 4.0 : 0.0,
            ),
            child: Text.rich(
              TextSpan(children: spans),
              textAlign: effectiveTextAlign,
              maxLines: maxLines,
              overflow: overflow,
            ),
          ),
        ),
      );
    }

    if (lineWidgets.length == 1) {
      return lineWidgets.first;
    }

    return Column(
      crossAxisAlignment: (isListParagraph && !isParagraphRtl)
          ? CrossAxisAlignment.start
          : (effectiveTextAlign == TextAlign.center
              ? CrossAxisAlignment.center
              : (isParagraphRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start)),
      mainAxisSize: MainAxisSize.min,
      children: lineWidgets,
    );
  }
}
