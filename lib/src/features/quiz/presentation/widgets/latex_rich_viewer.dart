import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/utils/latex_ast_cache.dart';
import 'package:kortex/src/features/quiz/domain/logic/formula_aware_text_formatter.dart';

/// A high-performance, language-aware Flutter widget that parses mixed natural text,
/// Markdown formatting, and LaTeX mathematics.
///
/// Features:
/// - Language-Aware: Auto-detects RTL scripts (Arabic) and African tonal scripts (Yoruba, Igbo, Hausa),
///   applying appropriate [TextDirection] and font fallbacks per paragraph.
/// - Markdown Support: Renders headings without `#`, bold `**...**`, italic `*...*`,
///   lists, and inline code without leaking raw syntax symbols or asterisks.
/// - LaTeX Math: Delimiters `\(...\)`, `$...$`, `\[...\]`, and `$$...$$` are typeset
///   using [Math.tex] with graceful fallback on syntax error.
class LatexRichViewer extends StatelessWidget {
  const LatexRichViewer({
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.forceRtl,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool? forceRtl;

  static final RegExp _rtlRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  static final RegExp _blockMathRegex = RegExp(
    r'(\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$)',
    multiLine: true,
  );

  static final RegExp _latexRegex = RegExp(
    r'(\\\([\s\S]*?\\\)|\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\]|\$(?!\$)[\s\S]*?\$)',
    multiLine: true,
  );

  /// Matches inline markdown tokens: bold-italic, bold, italic, code, strikethrough
  static final RegExp _inlineMarkdownRegex = RegExp(
    r'(\*\*\*(.+?)\*\*\*|___(.+?)___|\*\*(.+?)\*\*|__(.+?)__|(?<!\w)\*(?!\s)(.+?)(?<!\s)\*(?!\w)|(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)|`([^`]+)`|~~(.+?)~~)',
    multiLine: true,
  );

  static const List<String> _fontFamilyFallbacks = [
    'Geeza Pro',
    'Noto Naskh Arabic',
    'Noto Sans',
    'Roboto',
    'Arial',
  ];

  static bool isRtlString(String s) => _rtlRegex.hasMatch(s);

  /// Sanitizes raw HTML entities, prompt artifacts, and reasoning tags
  static String sanitizeRawText(String input) {
    if (input.trim().isEmpty) return '';
    return LatexAstCache.instance.getOrComputeSanitized(input, (raw) {
      var s = raw;

      // Strip reasoning tags & model prompt tokens
      s = s.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'<\/?think>', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'<\|[a-zA-Z0-9_\-]+\|>'), '');

      // Replace common HTML tags and entities
      s = s.replaceAll(RegExp(r'<\s*br\s*\/?\s*>', caseSensitive: false), '\n');
      s = s.replaceAll(RegExp(r'<\s*\/?\s*(?:b|strong)\s*>', caseSensitive: false), '**');
      s = s.replaceAll(RegExp(r'<\s*\/?\s*(?:i|em)\s*>', caseSensitive: false), '*');
      s = s.replaceAll('&quot;', '"');
      s = s.replaceAll('&#039;', "'");
      s = s.replaceAll('&#39;', "'");
      s = s.replaceAll('&amp;', '&');
      s = s.replaceAll('&lt;', '<');
      s = s.replaceAll('&gt;', '>');
      s = s.replaceAll('&nbsp;', ' ');

      s = FormulaAwareTextFormatter.formatFormulaAware(s);

      return s.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cleanText = sanitizeRawText(text);
    if (cleanText.isEmpty) {
      return const SizedBox.shrink();
    }

    final inheritedStyle = DefaultTextStyle.of(context).style;
    final defaultStyle = inheritedStyle.merge(style).copyWith(
      fontFamilyFallback: _fontFamilyFallbacks,
    );

    // Split text into structural blocks (paragraphs / block math)
    final hasBlockMath = _blockMathRegex.hasMatch(cleanText);
    if (hasBlockMath) {
      return _buildBlockAndInlineContent(context, cleanText, defaultStyle);
    }

    // Single or multi-line natural text with inline markdown and inline LaTeX
    return _buildParagraphLayout(context, cleanText, defaultStyle);
  }

  Widget _buildBlockAndInlineContent(
    BuildContext context,
    String content,
    TextStyle defaultStyle,
  ) {
    final widgets = <Widget>[];
    var lastIndex = 0;

    for (final match in _blockMathRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        final textChunk = content.substring(lastIndex, match.start).trim();
        if (textChunk.isNotEmpty) {
          widgets
            ..add(_buildParagraphLayout(context, textChunk, defaultStyle))
            ..add(const SizedBox(height: 8));
        }
      }

      final rawBlock = match.group(0) ?? '';
      var formula = rawBlock;
      if (formula.startsWith(r'\[') && formula.endsWith(r'\]')) {
        formula = formula.substring(2, formula.length - 2);
      } else if (formula.startsWith(r'$$') && formula.endsWith(r'$$')) {
        formula = formula.substring(2, formula.length - 2);
      }
      formula = formula.trim();

      if (formula.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: LatexFormulaBlock(
              formula: formula,
              textStyle: defaultStyle.copyWith(
                fontSize: (defaultStyle.fontSize ?? 15) * 1.05,
              ),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      final remaining = content.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        widgets
          ..add(const SizedBox(height: 8))
          ..add(_buildParagraphLayout(context, remaining, defaultStyle));
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

  Widget _buildParagraphLayout(
    BuildContext context,
    String content,
    TextStyle defaultStyle,
  ) {
    // Split by double newline to preserve paragraph separation
    final paragraphs = content.split(RegExp(r'\n{2,}'));
    if (paragraphs.length <= 1) {
      return _buildSingleParagraph(context, content, defaultStyle);
    }

    final children = <Widget>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i].trim();
      if (p.isEmpty) continue;
      children.add(_buildSingleParagraph(context, p, defaultStyle));
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

  Widget _buildSingleParagraph(
    BuildContext context,
    String paragraph,
    TextStyle defaultStyle,
  ) {
    final lines = paragraph.split('\n');
    final lineWidgets = <Widget>[];

    final isParagraphRtl = forceRtl ?? isRtlString(paragraph);
    final paragraphDirection =
        isParagraphRtl ? TextDirection.rtl : TextDirection.ltr;

    final isListParagraph = lines
        .where((l) => l.trim().isNotEmpty)
        .any((l) => RegExp(r'^\s*(?:(\*|-|•)\s+|[A-Ea-e][\.\)]\s+)').hasMatch(l.trim()));

    final effectiveTextAlign = textAlign == TextAlign.center
        ? (isListParagraph ? TextAlign.start : TextAlign.center)
        : (isParagraphRtl ? TextAlign.right : textAlign);

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      var lineStyle = defaultStyle;
      var contentToRender = line;

      // 1. Heading check: '#', '##', '###' -> style as bold heading without raw '#'
      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmedLine);
      if (headingMatch != null) {
        final level = headingMatch.group(1)?.length ?? 1;
        contentToRender = headingMatch.group(2) ?? '';
        final scale = level == 1 ? 1.25 : (level == 2 ? 1.15 : 1.08);
        lineStyle = defaultStyle.copyWith(
          fontSize: (defaultStyle.fontSize ?? 15) * scale,
          fontWeight: FontWeight.bold,
        );
      }

      // 2. Bullet list check: '-', '*', '•' -> style cleanly without loose asterisks
      final bulletMatch = RegExp(r'^(\*|-|•)\s+(.*)$').firstMatch(trimmedLine);
      if (bulletMatch != null) {
        contentToRender = '•  ${bulletMatch.group(2) ?? ''}';
      }

      // 3. Numbered list check: '1. ', '2. '
      final numMatch = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(trimmedLine);
      if (numMatch != null) {
        contentToRender = '${numMatch.group(1)} ${numMatch.group(2) ?? ''}';
      }

      // Render line with mixed Markdown & LaTeX spans
      final spans = _parseInlineMarkdownAndLatex(
        context,
        contentToRender,
        lineStyle,
      );

      lineWidgets.add(
        Directionality(
          textDirection: paragraphDirection,
          child: Text.rich(
            TextSpan(children: spans),
            textAlign: effectiveTextAlign,
            maxLines: maxLines,
            overflow: overflow,
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
              : (isParagraphRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start)),
      mainAxisSize: MainAxisSize.min,
      children: lineWidgets,
    );
  }

  List<InlineSpan> _parseInlineMarkdownAndLatex(
    BuildContext context,
    String content,
    TextStyle baseStyle,
  ) {
    final spans = <InlineSpan>[];
    var lastIndex = 0;

    // Scan for LaTeX math first
    for (final mathMatch in _latexRegex.allMatches(content)) {
      if (mathMatch.start > lastIndex) {
        final textChunk = content.substring(lastIndex, mathMatch.start);
        spans.addAll(_parseInlineMarkdownOnly(textChunk, baseStyle));
      }

      final rawMath = mathMatch.group(0) ?? '';
      var formula = rawMath;

      // Strip opening and closing delimiters
      if (formula.startsWith(r'\(') && formula.endsWith(r'\)')) {
        formula = formula.substring(2, formula.length - 2);
      } else if (formula.startsWith(r'\[') && formula.endsWith(r'\]')) {
        formula = formula.substring(2, formula.length - 2);
      } else if (formula.startsWith(r'$$') && formula.endsWith(r'$$')) {
        formula = formula.substring(2, formula.length - 2);
      } else if (formula.startsWith(r'$') && formula.endsWith(r'$')) {
        formula = formula.substring(1, formula.length - 1);
      }
      formula = formula.trim();

      if (formula.isNotEmpty) {
        final isLongFormula = formula.length > 35 || formula.split('=').length > 2;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: isLongFormula
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Math.tex(
                          formula,
                          textStyle: baseStyle,
                          mathStyle: MathStyle.text,
                          onErrorFallback: (err) =>
                              Text(rawMath, style: baseStyle),
                        ),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Math.tex(
                        formula,
                        textStyle: baseStyle,
                        mathStyle: MathStyle.text,
                        onErrorFallback: (err) =>
                            Text(rawMath, style: baseStyle),
                      ),
                    ),
            ),
          ),
        );
      }

      lastIndex = mathMatch.end;
    }

    if (lastIndex < content.length) {
      final remaining = content.substring(lastIndex);
      spans.addAll(_parseInlineMarkdownOnly(remaining, baseStyle));
    }

    return spans;
  }

  /// Parses inline markdown tokens (bold, italic, code, etc.) into styled [TextSpan]s
  List<InlineSpan> _parseInlineMarkdownOnly(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    var lastIndex = 0;

    for (final match in _inlineMarkdownRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final plain = text.substring(lastIndex, match.start);
        spans.add(TextSpan(text: _sanitizeLoneMarkdownSymbols(plain), style: baseStyle));
      }

      // 1. Bold Italic: ***text*** (group 2) or ___text___ (group 3)
      if (match.group(2) != null || match.group(3) != null) {
        final inner = match.group(2) ?? match.group(3) ?? '';
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      // 2. Bold: **text** (group 4) or __text__ (group 5)
      else if (match.group(4) != null || match.group(5) != null) {
        final inner = match.group(4) ?? match.group(5) ?? '';
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      // 3. Italic: *text* (group 6) or _text_ (group 7)
      else if (match.group(6) != null || match.group(7) != null) {
        final inner = match.group(6) ?? match.group(7) ?? '';
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      // 4. Inline Code: `text` (group 8)
      else if (match.group(8) != null) {
        final inner = match.group(8) ?? '';
        spans.add(
          TextSpan(
            text: ' $inner ',
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: (baseStyle.fontSize ?? 14) * 0.92,
              backgroundColor: baseStyle.color != null
                  ? baseStyle.color!.withAlpha(25)
                  : Colors.grey.withAlpha(40),
            ),
          ),
        );
      }
      // 5. Strikethrough: ~~text~~ (group 9)
      else if (match.group(9) != null) {
        final inner = match.group(9) ?? '';
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex);
      spans.add(TextSpan(text: _sanitizeLoneMarkdownSymbols(remaining), style: baseStyle));
    }

    return spans;
  }

  /// Removes stray unclosed asterisks or raw '#' symbols so users never see markdown artifacts
  static String _sanitizeLoneMarkdownSymbols(String s) {
    var out = s;
    // Strip leading '#' that may have slipped through
    out = out.replaceAll(RegExp(r'^#{1,6}\s*'), '');
    // Clean redundant double asterisks that have no closing tag
    out = out.replaceAll('***', '');
    out = out.replaceAll('**', '');
    return out;
  }
}

/// A dedicated block LaTeX display widget for standalone equations (e.g. formula box).
class LatexFormulaBlock extends StatelessWidget {
  const LatexFormulaBlock({
    required this.formula,
    this.textStyle,
    this.backgroundColor,
    this.borderColor,
    super.key,
  });

  final String formula;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final clean = LatexAstCache.instance.getOrCleanFormula(formula);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isDark ? Colors.black.withValues(alpha: 0.38) : theme.colorScheme.surface);
    final border = borderColor ?? theme.colorScheme.primary.withValues(alpha: 0.25);
    final style = textStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Math.tex(
          clean,
          textStyle: style,
          onErrorFallback: (err) => Text(
            formula,
            style: style?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}
