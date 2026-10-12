import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/utils/latex_ast_cache.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_text_sanitizer.dart';

/// Parses inline Markdown styling (bold, italic, strikethrough, monospace)
/// and typesets inline LaTeX math equations into [InlineSpan] lists.
class LatexInlineMarkdownParser {
  const LatexInlineMarkdownParser._();

  /// Scans [content] for LaTeX math formulas, formatting surrounding text
  /// with inline Markdown rules.
  static List<InlineSpan> parseInlineMarkdownAndLatex(
    BuildContext context,
    String content,
    TextStyle baseStyle,
  ) {
    if (!content.contains(r'$') &&
        !content.contains(r'\') &&
        !content.contains('*') &&
        !content.contains('_') &&
        !content.contains('`') &&
        !content.contains('~')) {
      return [TextSpan(text: content, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    var lastIndex = 0;

    // Scan for LaTeX math first
    for (final mathMatch in LatexTextSanitizer.latexRegex.allMatches(content)) {
      if (mathMatch.start > lastIndex) {
        final textChunk = content.substring(lastIndex, mathMatch.start);
        spans.addAll(parseInlineMarkdownOnly(context, textChunk, baseStyle));
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
      final cleanFormula =
          LatexAstCache.instance.getOrCleanFormula(formula);

      if (cleanFormula.isNotEmpty) {
        final isLongFormula =
            cleanFormula.length > 35 || cleanFormula.split('=').length > 2;

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
                        physics: const ClampingScrollPhysics(),
                        child: Math.tex(
                          cleanFormula,
                          textStyle: baseStyle,
                          mathStyle: MathStyle.text,
                          onErrorFallback: (err) {
                            final fallback = LatexAstCache.instance
                                .formatLatexHumanReadableFallback(rawMath);
                            return Text(
                              fallback.isNotEmpty ? fallback : rawMath,
                              style: baseStyle,
                            );
                          },
                        ),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Math.tex(
                        cleanFormula,
                        textStyle: baseStyle,
                        mathStyle: MathStyle.text,
                        onErrorFallback: (err) {
                          final fallback = LatexAstCache.instance
                              .formatLatexHumanReadableFallback(rawMath);
                          return Text(
                            fallback.isNotEmpty ? fallback : rawMath,
                            style: baseStyle,
                          );
                        },
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
      spans.addAll(parseInlineMarkdownOnly(context, remaining, baseStyle));
    }

    return spans;
  }

  /// Parses inline markdown tokens (bold, italic, code, strikethrough) into styled [TextSpan]s.
  static List<InlineSpan> parseInlineMarkdownOnly(
    BuildContext context,
    String text,
    TextStyle baseStyle,
  ) {
    final spans = <InlineSpan>[];
    var lastIndex = 0;

    for (final match in LatexTextSanitizer.inlineMarkdownRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final plain = text.substring(lastIndex, match.start);
        spans.add(
          TextSpan(
            text: LatexTextSanitizer.sanitizeLoneMarkdownSymbols(plain),
            style: baseStyle,
          ),
        );
      }

      // 1. Bold Italic: ***text*** (group 2) or ___text___ (group 3)
      if (match.group(2) != null || match.group(3) != null) {
        final rawInner = match.group(2) ?? match.group(3) ?? '';
        final leadingSpace = rawInner.startsWith(' ') ? ' ' : '';
        final trailingSpace = rawInner.endsWith(' ') ? ' ' : '';
        final inner = rawInner.trim();
        if (leadingSpace.isNotEmpty) {
          spans.add(TextSpan(text: leadingSpace, style: baseStyle));
        }
        if (inner.isNotEmpty) {
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
        if (trailingSpace.isNotEmpty) {
          spans.add(TextSpan(text: trailingSpace, style: baseStyle));
        }
      }
      // 2. Bold: **text** (group 4) or __text__ (group 5)
      else if (match.group(4) != null || match.group(5) != null) {
        final rawInner = match.group(4) ?? match.group(5) ?? '';
        final leadingSpace = rawInner.startsWith(' ') ? ' ' : '';
        final trailingSpace = rawInner.endsWith(' ') ? ' ' : '';
        final inner = rawInner.trim();
        if (leadingSpace.isNotEmpty) {
          spans.add(TextSpan(text: leadingSpace, style: baseStyle));
        }
        if (inner.isNotEmpty) {
          spans.add(
            TextSpan(
              text: inner,
              style: baseStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        if (trailingSpace.isNotEmpty) {
          spans.add(TextSpan(text: trailingSpace, style: baseStyle));
        }
      }
      // 3. Italic: *text* (group 6) or _text_ (group 7)
      else if (match.group(6) != null || match.group(7) != null) {
        final rawInner = match.group(6) ?? match.group(7) ?? '';
        final leadingSpace = rawInner.startsWith(' ') ? ' ' : '';
        final trailingSpace = rawInner.endsWith(' ') ? ' ' : '';
        final inner = rawInner.trim();
        if (leadingSpace.isNotEmpty) {
          spans.add(TextSpan(text: leadingSpace, style: baseStyle));
        }
        if (inner.isNotEmpty) {
          spans.add(
            TextSpan(
              text: inner,
              style: baseStyle.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
        if (trailingSpace.isNotEmpty) {
          spans.add(TextSpan(text: trailingSpace, style: baseStyle));
        }
      }
      // 4. Inline Code: `text` (group 8)
      else if (match.group(8) != null) {
        final inner = match.group(8) ?? '';
        final primaryColor = Theme.of(context)
                .extension<AppThemeColorsExtension>()
                ?.primary ??
            Theme.of(context).colorScheme.primary;
        spans.add(
          TextSpan(
            text: ' $inner ',
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: (baseStyle.fontSize ?? 14) * 0.92,
              fontWeight: FontWeight.w600,
              color: primaryColor,
              backgroundColor: primaryColor.withAlpha(
                (Theme.of(context).brightness == Brightness.dark) ? 45 : 22,
              ),
            ),
          ),
        );
      }
      // 5. Strikethrough: ~~text~~ (group 9)
      else if (match.group(9) != null) {
        final rawInner = match.group(9) ?? '';
        final leadingSpace = rawInner.startsWith(' ') ? ' ' : '';
        final trailingSpace = rawInner.endsWith(' ') ? ' ' : '';
        final inner = rawInner.trim();
        if (leadingSpace.isNotEmpty) {
          spans.add(TextSpan(text: leadingSpace, style: baseStyle));
        }
        if (inner.isNotEmpty) {
          spans.add(
            TextSpan(
              text: inner,
              style: baseStyle.copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: baseStyle.color ?? context.colors.textPrimary,
                decorationStyle: TextDecorationStyle.solid,
                decorationThickness: 2,
              ),
            ),
          );
        }
        if (trailingSpace.isNotEmpty) {
          spans.add(TextSpan(text: trailingSpace, style: baseStyle));
        }
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex);
      spans.add(
        TextSpan(
          text: LatexTextSanitizer.sanitizeLoneMarkdownSymbols(remaining),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }
}
