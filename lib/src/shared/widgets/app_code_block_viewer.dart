import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// A rich, syntax-highlighted code block card with language header and copy button.
///
/// Designed according to Kortex premium UI design principles for active-recall
/// flashcard presentation (front & back) and quiz / quick practice screens.
class AppCodeBlockViewer extends StatefulWidget {
  const AppCodeBlockViewer({
    required this.code,
    this.language,
    this.showLineNumbers = false,
    super.key,
  });

  final String code;
  final String? language;
  final bool showLineNumbers;

  @override
  State<AppCodeBlockViewer> createState() => _AppCodeBlockViewerState();
}

class _AppCodeBlockViewerState extends State<AppCodeBlockViewer> {
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String get _displayLanguage {
    final lang = widget.language?.trim().toUpperCase();
    if (lang == null || lang.isEmpty) return 'CODE';
    return lang;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final containerBg = isDark
        ? const Color(0xFF13171F)
        : const Color(0xFF1E222B);
    final headerBg = isDark
        ? const Color(0xFF0F1218)
        : const Color(0xFF171B22);
    final borderColor = isDark
        ? const Color(0xFF262C38)
        : const Color(0xFF2D3442);

    final cleanCode = widget.code.trimRight();

    return Semantics(
      label: '$_displayLanguage code block',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header Bar ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(
                  bottom: BorderSide(color: borderColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Language Badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _displayLanguage,
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFFADB5BD),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  // Copy Button
                  InkWell(
                    onTap: _handleCopy,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied
                                ? Icons.check_rounded
                                : Icons.content_copy_rounded,
                            size: 13,
                            color: _copied
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _copied ? 'COPIED' : 'COPY',
                            style: GoogleFonts.jetBrainsMono(
                              color: _copied
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFF94A3B8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Code Body with Horizontal Scroll ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SelectionArea(
                  child: _buildHighlightedCode(cleanCode),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedCode(String code) {
    final spans = _tokenizeCode(code);
    return Text.rich(
      TextSpan(children: spans),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 13.5,
        height: 1.5,
        color: const Color(0xFFE2E8F0),
      ),
    );
  }

  /// High-performance syntax tokenizer for programming languages (Dart, Python, JS, etc.)
  List<InlineSpan> _tokenizeCode(String code) {
    final spans = <InlineSpan>[];

    // Regex pattern matching comments, strings, numbers, keywords, and types
    final tokenRegex = RegExp(
      r'(//[^\n]*|#[^\n]*|/\*[\s\S]*?\*/)' // 1. Comments
      r'|("""[\s\S]*?"""|"""[\s\S]*?"""|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27)' // 2. Strings
      r'|\b(0x[a-fA-F0-9]+|\d+(?:\.\d+)?)\b' // 3. Numbers
      r'|(@\w+)' // 4. Annotations / Decorators
      r'|\b(class|extends|implements|with|mixin|void|return|final|const|var|let|function|def|import|from|as|export|package|async|await|yield|if|else|for|while|do|switch|case|break|continue|default|try|catch|finally|throw|rethrow|new|this|super|is|in|true|false|null|nil|undefined|static|abstract|override|get|set|typedef|enum|struct|interface|public|private|protected)\b' // 5. Keywords
      r'|\b([A-Z][a-zA-Z0-9_]*)\b' // 6. PascalCase types / classes
      r'|(=>|===|!==|==|!=|<=|>=|\+=|-=|\*=|/=|&&|\|\||\+\+|--|\?\.|\?\?|->|::)' // 7. Operators
      r'|([{}()\[\];,])', // 8. Punctuation
    );

    var lastIndex = 0;
    final matches = tokenRegex.allMatches(code);

    const commentStyle = TextStyle(
      color: Color(0xFF6B7280),
      fontStyle: FontStyle.italic,
    );
    const stringStyle = TextStyle(color: Color(0xFF98C379));
    const numberStyle = TextStyle(color: Color(0xFFD19A66));
    const annotationStyle = TextStyle(
      color: Color(0xFFE5C07B),
      fontWeight: FontWeight.w600,
    );
    const keywordStyle = TextStyle(
      color: Color(0xFF56B6C2),
      fontWeight: FontWeight.bold,
    );
    const typeStyle = TextStyle(
      color: Color(0xFF61AFEF),
      fontWeight: FontWeight.w600,
    );
    const operatorStyle = TextStyle(
      color: Color(0xFFC678DD),
      fontWeight: FontWeight.bold,
    );
    const punctuationStyle = TextStyle(color: Color(0xFF828997));

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(text: code.substring(lastIndex, match.start)),
        );
      }

      final text = match.group(0)!;
      TextStyle? matchedStyle;

      if (match.group(1) != null) {
        matchedStyle = commentStyle;
      } else if (match.group(2) != null) {
        matchedStyle = stringStyle;
      } else if (match.group(3) != null) {
        matchedStyle = numberStyle;
      } else if (match.group(4) != null) {
        matchedStyle = annotationStyle;
      } else if (match.group(5) != null) {
        matchedStyle = keywordStyle;
      } else if (match.group(6) != null) {
        matchedStyle = typeStyle;
      } else if (match.group(7) != null) {
        matchedStyle = operatorStyle;
      } else if (match.group(8) != null) {
        matchedStyle = punctuationStyle;
      }

      spans.add(TextSpan(text: text, style: matchedStyle));
      lastIndex = match.end;
    }

    if (lastIndex < code.length) {
      spans.add(TextSpan(text: code.substring(lastIndex)));
    }

    return spans;
  }
}
