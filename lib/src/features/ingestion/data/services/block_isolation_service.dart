import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';

/// Service providing strict block isolation for formulas, tables, and captions
/// to prevent hybrid artifacts from contaminating prose paragraphs and flashcards.
class BlockIsolationService {
  const BlockIsolationService();

  static final RegExp _captionRegex = RegExp(
    r'^(?:Table|Figure|Fig\.|Listing|Algorithm|Chart|Graph|Box|Equation|Eq\.)\s+(?:\d+[A-Za-z]?(?:\.\d+)*|[A-Z]|\b[IVXLCDM]+\b)(?:(?:\s*[.:\-—–]\s*|\s+)(?!(?:is|are|shows|illustrates|summarizes|provides|indicates|depicts|was|were)\b).*|$)',
    caseSensitive: false,
  );

  static final RegExp _bannedCaptionCloze = RegExp(
    r'\b(?:Table|Figure|Fig\.|Listing|Algorithm|Chart|Graph|Box)\s+\d+',
    caseSensitive: false,
  );

  static final RegExp _mathConstructsRegex = RegExp(
    r'(?:\\(?:sum|prod|int|iint|oint|frac|dfrac|sqrt|partial|nabla|mathbf|mathcal|mathbb|alpha|beta|gamma|theta|lambda|sigma|mu|pi|omega|Delta|Sigma|Omega|vec|hat|bar|dot|lim|infty|times|cdot|approx|neq|leq|geq|pm|left|right)\b|\$\$|\\\[|\\\]|\\\(|\\\)|\\begin\{|\\end\{)',
  );

  static final RegExp _mathOperatorStartRegex = RegExp(
    '^[±∓×÷·∑∏∫∂√∝∈∉⊆⊂∪∩∧∨¬⇒⇔→←↑↓∞=≈≠≤≥<>]',
  );

  static final RegExp _mathOperatorEndRegex = RegExp(
    r'[=+\-*/^±∓×÷·∑∏∫∂√≈≠≤≥]$',
  );

  static final RegExp _tableDividerRegex = RegExp(
    r'^\|?[\s\-:|]+\|?$',
  );

  /// Returns true if [text] is a caption line (e.g. "Table 1: Metrics", "Figure 2.1: Flow").
  static bool isCaptionLine(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > 200) return false; // Captions are typically concise
    return _captionRegex.hasMatch(trimmed);
  }

  /// Returns true if [text] is a standalone formula line (TeX constructs, math operators, equations).
  static bool isFormulaLine(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Hyphenated word break across lines (e.g. "infor-", "class-") is not a formula
    if (RegExp(r'[A-Za-z]{2,}\s*[-–—]$').hasMatch(trimmed)) {
      return false;
    }

    // Direct delimiters
    if (trimmed.startsWith(r'$$') ||
        trimmed.startsWith(r'\[') ||
        trimmed.startsWith(r'\begin{')) {
      return true;
    }
    if (trimmed.endsWith(r'$$') ||
        trimmed.endsWith(r'\]') ||
        (trimmed.endsWith('}') && trimmed.contains(r'\end{'))) {
      return true;
    }

    // TeX constructs / commands
    if (_mathConstructsRegex.hasMatch(trimmed)) {
      if (!FormulaExtractionService.isCodeAssignment(trimmed)) {
        return true;
      }
    }

    // Math operator at start or end
    if (_mathOperatorStartRegex.hasMatch(trimmed) ||
        _mathOperatorEndRegex.hasMatch(trimmed)) {
      if (!FormulaExtractionService.isCodeAssignment(trimmed)) {
        return true;
      }
    }

    // Mathematical formula verification
    if (FormulaExtractionService.isFormula(trimmed)) {
      return true;
    }

    return false;
  }

  /// Returns true if [text] is a Markdown table row, divider, or columnar table line.
  static bool isTableRowLine(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Explicit markdown table divider (|---|---|)
    if (_tableDividerRegex.hasMatch(trimmed) && trimmed.contains('-')) {
      return true;
    }

    // Markdown table row with pipes (| col 1 | col 2 |)
    if (trimmed.contains('|')) {
      // Ignore double pipes (|| logical OR or norm) when counting table cell dividers
      final withoutDoublePipes = trimmed.replaceAll(r'\|', '').replaceAll('||', '  ');
      final pipeMatches = RegExp(r'\|').allMatches(withoutDoublePipes).length;

      if (trimmed.startsWith('|') || trimmed.endsWith('|')) {
        return pipeMatches >= 1;
      }
      // If no leading/trailing pipe, require at least 2 distinct separating pipes with non-empty column content
      if (pipeMatches >= 2) {
        // Verify it's not a prose sentence that happens to mention pipes
        final isSentence = RegExp(r'[.!?]$').hasMatch(trimmed) &&
            RegExp('^[A-Z][a-z]').hasMatch(trimmed) &&
            !trimmed.endsWith('|');
        if (!isSentence) {
          return true;
        }
      }
    }

    // Tab-separated table line
    if (trimmed.contains('\t') && trimmed.split('\t').length >= 2) {
      return true;
    }

    return false;
  }

  /// Returns true if consecutive lines should not be welded into one sentence because
  /// they form non-punctuated structural blocks (e.g. definitions, attributes, equations).
  static bool isNonPunctuatedBlock({
    required String currentLine,
    required String nextLine,
    double? gap,
    double? medianLineHeight,
  }) {
    final curr = currentLine.trim();
    final next = nextLine.trim();
    if (curr.isEmpty || next.isEmpty) return false;

    // If current ends with sentence punctuation, it is a natural sentence boundary
    if (RegExp(r'[.!?:]$').hasMatch(curr)) return false;

    // If current ends with hyphen, it is a line-broken hyphenated word or range
    if (curr.endsWith('-') || curr.endsWith('—') || curr.endsWith('–')) return false;

    // If next line starts with a lowercase letter, it is a continuation of the sentence
    if (RegExp('^[a-z]').hasMatch(next)) return false;

    // If either line is a formula, caption, table, or code line
    if (isFormulaLine(curr) ||
        isFormulaLine(next) ||
        isCaptionLine(curr) ||
        isCaptionLine(next) ||
        isTableRowLine(curr) ||
        isTableRowLine(next)) {
      return true;
    }

    // Key-value pairs or structural definitions (e.g. "Input: int[]", "Complexity: O(n)")
    final isStructuralCurr = RegExp('^[A-Za-z0-9_ -]{1,25}:').hasMatch(curr);
    final isStructuralNext = RegExp('^[A-Za-z0-9_ -]{1,25}:').hasMatch(next);
    if (isStructuralCurr || isStructuralNext) {
      return true;
    }

    // Significant vertical gap between non-punctuated lines indicates discrete items
    if (gap != null && medianLineHeight != null && gap > medianLineHeight * 0.4) {
      return true;
    }

    return false;
  }

  /// Returns true if [sentence] contains a mixture of equations, table syntax, or captions,
  /// making it an invalid hybrid cloze candidate.
  static bool isHybridClozeCandidate(String sentence) {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return false;

    // Contains table markup
    if (trimmed.contains('|')) return true;

    // Contains caption label
    if (_bannedCaptionCloze.hasMatch(trimmed)) return true;

    // Contains display or inline LaTeX math delimiters
    if (trimmed.contains(r'$$') ||
        trimmed.contains(r'\[') ||
        trimmed.contains(r'\begin{')) {
      return true;
    }

    // Contains LaTeX math commands
    if (RegExp(r'\\(?:frac|sum|int|sqrt|partial|alpha|beta|theta|lambda|sigma)\b')
        .hasMatch(trimmed)) {
      return true;
    }

    // Matches mathematical formula criteria
    if (FormulaExtractionService.isFormula(trimmed)) {
      return true;
    }

    return false;
  }
}
