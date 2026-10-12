import 'package:flutter/material.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_paragraph_builder.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_text_sanitizer.dart';

export 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_formula_block.dart';
export 'package:kortex/src/features/quiz/presentation/widgets/latex_viewer/latex_text_sanitizer.dart';

/// A high-performance, language-aware Flutter widget that parses mixed natural text,
/// Markdown formatting, and LaTeX mathematics.
///
/// Features:
/// - Language-Aware: Auto-detects RTL scripts (Arabic) and African tonal scripts (Yoruba, Igbo, Hausa),
///   applying appropriate [TextDirection] and font fallbacks per paragraph.
/// - Markdown Support: Renders headings without `#`, bold `**...**`, italic `*...*`,
///   lists, and inline code without leaking raw syntax symbols or asterisks.
/// - LaTeX Math: Delimiters `\(...\)`, `$...$`, `\[...\]`, and `$$...$$` are typeset
///   using `Math.tex` with graceful fallback on syntax error.
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

  /// Detects whether [s] contains Right-to-Left characters.
  static bool isRtlString(String s) => LatexTextSanitizer.isRtlString(s);

  /// Sanitizes raw HTML entities, prompt artifacts, and reasoning tags.
  static String sanitizeRawText(String input) =>
      LatexTextSanitizer.sanitizeRawText(input);

  /// Formats inline sequential lists into clean, line-by-line list items.
  static String formatInlineLists(String text) =>
      LatexTextSanitizer.formatInlineLists(text);

  @override
  Widget build(BuildContext context) {
    final cleanText = sanitizeRawText(text);
    if (cleanText.isEmpty) {
      return const SizedBox.shrink();
    }

    final inheritedStyle = DefaultTextStyle.of(context).style;
    final defaultStyle = inheritedStyle.merge(style).copyWith(
          fontFamilyFallback: LatexTextSanitizer.fontFamilyFallbacks,
        );

    // Fast-path for plain text without markdown, latex, or linebreaks
    if (!cleanText.contains(r'$') &&
        !cleanText.contains(r'\') &&
        !cleanText.contains('*') &&
        !cleanText.contains('_') &&
        !cleanText.contains('`') &&
        !cleanText.contains('~') &&
        !cleanText.contains('#') &&
        !cleanText.contains('>') &&
        !cleanText.contains('\n')) {
      final isRtl = forceRtl ?? isRtlString(cleanText);
      return Text(
        cleanText,
        style: defaultStyle,
        textAlign: textAlign == TextAlign.center
            ? TextAlign.center
            : (isRtl ? TextAlign.right : textAlign),
        maxLines: maxLines,
        overflow: overflow,
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      );
    }

    // Split text into structural blocks (code blocks / block math)
    final hasStructuralBlocks =
        LatexTextSanitizer.structuralBlockRegex.hasMatch(cleanText);
    if (hasStructuralBlocks) {
      return LatexParagraphBuilder.buildBlockAndInlineContent(
        context,
        cleanText,
        defaultStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        forceRtl: forceRtl,
      );
    }

    // Single or multi-line natural text with inline markdown and inline LaTeX
    return LatexParagraphBuilder.buildParagraphLayout(
      context,
      cleanText,
      defaultStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      forceRtl: forceRtl,
    );
  }
}
