import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// A high-performance Flutter widget that parses mixed natural text and LaTeX math
/// (supporting inline \(...\), $...$, and block \[...\], $$...$$ delimiters).
///
/// Plain text segments are rendered using standard typography while mathematical
/// expressions are typeset using [Math.tex] with graceful fallback on syntax error.
class LatexRichViewer extends StatelessWidget {
  const LatexRichViewer({
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  static final RegExp _blockMathRegex = RegExp(
    r'(\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$)',
    multiLine: true,
  );

  static final RegExp _latexRegex = RegExp(
    r'(\\\([\s\S]*?\\\)|\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\]|\$(?!\$)[\s\S]*?\$)',
    multiLine: true,
  );

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultStyle = DefaultTextStyle.of(context).style.merge(style);

    // Fast path: No LaTeX delimiters present in text
    if (!text.contains(r'\(') &&
        !text.contains(r'$$') &&
        !text.contains(r'\[') &&
        !text.contains(r'$')) {
      return Text(
        text,
        style: defaultStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Check if text contains display/block math (\[ ... \] or $$ ... $$)
    final hasBlockMath = _blockMathRegex.hasMatch(text);

    if (hasBlockMath) {
      return _buildBlockAndInlineContent(context, defaultStyle);
    }

    return _buildInlineRichText(context, text, defaultStyle);
  }

  Widget _buildBlockAndInlineContent(BuildContext context, TextStyle defaultStyle) {
    final widgets = <Widget>[];
    var lastIndex = 0;

    for (final match in _blockMathRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final textChunk = text.substring(lastIndex, match.start).trim();
        if (textChunk.isNotEmpty) {
          widgets
            ..add(_buildInlineRichText(context, textChunk, defaultStyle))
            ..add(const SizedBox(height: 6));
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

    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        widgets
          ..add(const SizedBox(height: 6))
          ..add(_buildInlineRichText(context, remaining, defaultStyle));
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

  Widget _buildInlineRichText(
    BuildContext context,
    String content,
    TextStyle defaultStyle,
  ) {
    final spans = <InlineSpan>[];
    var lastIndex = 0;

    for (final match in _latexRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        final plain = content.substring(lastIndex, match.start);
        spans.add(TextSpan(text: plain, style: defaultStyle));
      }

      final rawMath = match.group(0) ?? '';
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
        // If an inline formula is long or contains multiple equal signs, render with scaling protection
        final isLongFormula = formula.length > 35 || formula.split('=').length > 2;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: isLongFormula
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Math.tex(
                          formula,
                          textStyle: defaultStyle,
                          mathStyle: MathStyle.text,
                          onErrorFallback: (err) =>
                              Text(rawMath, style: defaultStyle),
                        ),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Math.tex(
                        formula,
                        textStyle: defaultStyle,
                        mathStyle: MathStyle.text,
                        onErrorFallback: (err) =>
                            Text(rawMath, style: defaultStyle),
                      ),
                    ),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      final remaining = content.substring(lastIndex);
      spans.add(TextSpan(text: remaining, style: defaultStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
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
    var clean = formula.trim();
    if (clean.startsWith(r'\(') && clean.endsWith(r'\)')) {
      clean = clean.substring(2, clean.length - 2).trim();
    } else if (clean.startsWith(r'\[') && clean.endsWith(r'\]')) {
      clean = clean.substring(2, clean.length - 2).trim();
    } else if (clean.startsWith(r'$$') && clean.endsWith(r'$$')) {
      clean = clean.substring(2, clean.length - 2).trim();
    } else if (clean.startsWith(r'$') && clean.endsWith(r'$')) {
      clean = clean.substring(1, clean.length - 1).trim();
    }

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
