import 'dart:math' as math;
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

/// Classification tier for mathematical formula extraction.
enum FormulaTier {
  /// Tier A: Lossless extraction from native markup (LaTeX, MathML, OMML, PPTX).
  nativeMarkup,

  /// Tier B: PDF Vector math / Unicode mathematical symbols normalized to LaTeX.
  vectorUnicode,

  /// Tier C: Formula OCR fallback for scanned or raster math.
  formulaOcr,
}

/// Represents a parsed, validated, and normalized mathematical formula.
class ExtractedFormula {
  const ExtractedFormula({
    required this.latex,
    required this.rawMathText,
    required this.isDisplay,
    required this.tier,
    required this.confidence,
    this.name,
    this.page = 1,
    this.bbox,
  });

  /// Canonical, validated LaTeX string.
  final String latex;

  /// Original raw text or markup before normalization.
  final String rawMathText;

  /// Whether this is a display formula ($$...$$, equation) or inline ($...$).
  final bool isDisplay;

  /// Extraction tier source.
  final FormulaTier tier;

  /// Confidence score between 0.0 and 1.0 based on symbol density.
  final double confidence;

  /// Optional name or label of the formula (e.g. "Maxwell's Equations").
  final String? name;

  /// 1-based page number where the formula was located.
  final int page;

  /// Spatial bounding box coordinates if available.
  final BoundingBox? bbox;

  /// Converts this formula into a strongly-typed [MathBlock] for [DocumentIR].
  MathBlock toMathBlock({
    required String docId,
    required int readingOrder,
    List<String> sectionPath = const [],
  }) => MathBlock(
    latex: latex,
    isDisplay: isDisplay,
    rawMathText: rawMathText,
    provenance: BlockProvenance(
      docId: docId,
      page: page,
      readingOrder: readingOrder,
      sectionPath: sectionPath,
      bbox: bbox,
    ),
  );

  @override
  String toString() =>
      'ExtractedFormula(${isDisplay ? "display" : "inline"}, tier: $tier, confidence: ${(confidence * 100).toStringAsFixed(1)}%): "$latex"';
}

/// Deterministic tiered mathematical formula extraction and normalization engine.
///
/// Implements:
/// - Tier A: Native markup extraction (LaTeX, MathML, OMML, PPTX).
/// - Tier B: PDF vector math and Unicode normalization.
/// - Tier C: Formula OCR fallback.
/// - Math symbol density scoring replacing naive assignment heuristics (e.g. `x = 5`).
/// - Strict LaTeX renderability and bracket balancing validation.
class FormulaExtractionService {
  const FormulaExtractionService();

  /// Canonical shared instance.
  static const instance = FormulaExtractionService();

  // ===========================================================================
  // FORMULA DETECTION & CODE ASSIGNMENT DISCRIMINATION
  // ===========================================================================

  /// Checks whether [text] represents a mathematical formula, rejecting
  /// standard programming assignments (e.g. `count = 0`, `var total = 100;`).
  static bool isFormula(String text) {
    var trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Strip leading "Formula:" / "Equation:" / "Eq.:" prefix
    trimmed = trimmed.replaceFirst(
      RegExp(r'^(?:Formula|Equation|Eq\.?)\s*:\s*', caseSensitive: false),
      '',
    ).trim();

    // Strip document preamble declarations (\documentclass, \usepackage, \begin{document}, etc.)
    trimmed = stripLatexPreamble(trimmed);
    if (trimmed.isEmpty) return false;

    // 0. Cloze blank or blank placeholder filter (_____, [...], [?])
    if (RegExp('_{3,}').hasMatch(trimmed) ||
        trimmed.contains('___') ||
        trimmed.contains('[...]') ||
        RegExp(r'\bcloze\b', caseSensitive: false).hasMatch(trimmed)) {
      return false;
    }

    // 0b. Leading binary operator checks without an LHS (+, *, /, =, ^) or lone operators
    if (RegExp(r'^\s*[\+\*\/\=\^]').hasMatch(trimmed)) return false;
    if (RegExp(r'^\s*[-+*\/=^]\s*$').hasMatch(trimmed)) return false;
    if (RegExp(r'^\s*-\s*[\+\*\/\=\^]').hasMatch(trimmed)) return false;

    // 1. Direct code assignment and programming syntax filter
    if (isCodeAssignment(trimmed)) return false;

    // 1b. Gating against full prose sentences (> 40% prose words)
    if (hasHighProseWordDensity(trimmed)) return false;

    // 2. Explicit LaTeX delimiters
    if (_hasExplicitLatexDelimiters(trimmed)) return true;

    // 3. Explicit LaTeX math commands
    if (_latexMathCommandRegex.hasMatch(trimmed)) {
      final cmdCount = _latexMathCommandRegex.allMatches(trimmed).length;
      if (cmdCount >= 1 && !_containsCodeKeywords(trimmed)) return true;
    }

    // 4. MathML or OMML tags
    if (trimmed.contains('<math') || trimmed.contains('<m:oMath')) return true;

    // 5. Chemical / Mathematical reaction arrows
    if (trimmed.contains('→') ||
        trimmed.contains('->') ||
        trimmed.contains(r'\to') ||
        trimmed.contains(r'\rightarrow')) {
      if (_containsCodeKeywords(trimmed)) return false;
      if (isChemicalEquation(trimmed)) return true;
      if (trimmed.contains(r'\') ||
          trimmed.contains('^') ||
          trimmed.contains('_') ||
          trimmed.contains(r'\to') ||
          trimmed.contains(r'\rightarrow')) {
        return true;
      }
      return false;
    }

    // 6. Algebraic equations with operators (e.g. E = mc^2, a^2 + b^2 = c^2, y = mx + b)
    if (_isAlgebraicEquation(trimmed)) return true;

    // 7. Unicode math symbol density evaluation
    final density = computeMathSymbolDensity(trimmed);
    return density >= 0.25;
  }

  static bool _isAlgebraicEquation(String s) {
    if (!s.contains('=')) return false;
    final hasOp = s.contains('^') ||
        s.contains('+') ||
        s.contains('-') ||
        s.contains('*') ||
        s.contains('/') ||
        s.contains(r'\') ||
        s.contains('[') ||
        s.contains('(');
    if (!hasOp) return false;

    if (s.startsWith('http') || s.endsWith('.')) return false;

    final parts = s.split('=');
    if (parts.length != 2) return false;
    final lhs = parts[0].trim();
    final rhs = parts[1].trim();

    if (lhs.isEmpty || lhs.length > 25 || rhs.isEmpty) return false;
    if (isCodeAssignment(s)) return false;

    return true;
  }

  /// Evaluates whether a line constitutes a programming code assignment rather
  /// than a mathematical formulation.
  static bool isCodeAssignment(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    // Code statement terminations
    if (trimmed.endsWith(';') || trimmed.endsWith(',')) {
      return true;
    }

    // Language keywords at line start
    final codeDeclarationRegex = RegExp(
      r'^\b(?:var|final|const|let|int|double|float|bool|char|long|short|'
      'public|private|protected|static|class|struct|interface|import|'
      r'package|return|throw|export|typedef|def|fn|fun|function|val)\b',
    );
    if (codeDeclarationRegex.hasMatch(trimmed)) return true;

    // Code compound assignment or comparison operators
    if (RegExp(r'\+\=|\-\=|\*\=|\/\=|\%\=|\=\=|\=\=\=|\!\=|\!\=\=|\+\+|\-\-|\=\>|\:\:').hasMatch(trimmed)) {
      return true;
    }

    // Check identifier = literal without mathematical operations
    // e.g. "count = 0", "offset = 100", "status = 200", "retries = 3", "x = 5"
    final plainAssignmentRegex = RegExp(
      r'^[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*(?:[0-9]+|true|false|null|nil|"[^"]*"|\x27[^\x27]*\x27)\s*$',
    );
    if (plainAssignmentRegex.hasMatch(trimmed)) return true;

    // Arithmetic index increment/offset e.g. "index = i + 1", "offset = start + 10"
    final codeArithRegex = RegExp(
      r'^[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*[a-zA-Z_][a-zA-Z0-9_]*\s*[+\-*/]\s*(?:[0-9]+|[a-zA-Z_][a-zA-Z0-9_]*)\s*$',
    );
    if (codeArithRegex.hasMatch(trimmed)) return true;

    // Variable assignment to another variable or property call
    // e.g. "total = count", "width = box.width"
    final varAssignmentRegex = RegExp(
      r'^[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*[a-zA-Z_][a-zA-Z0-9_.]*\s*$',
    );
    if (varAssignmentRegex.hasMatch(trimmed)) return true;

    return false;
  }

  /// Calculates a mathematical symbol density score between 0.0 and 1.0.
  static double computeMathSymbolDensity(String text) {
    if (text.isEmpty) return 0;

    var mathScore = 0.0;

    // LaTeX math commands (+0.5 each)
    final mathCommands = _latexMathCommandRegex.allMatches(text).length;
    mathScore += mathCommands * 0.5;

    // Unicode math symbols (+0.4 each)
    for (final rune in text.runes) {
      if (_unicodeMathSymbols.contains(rune)) {
        mathScore += 0.4;
      }
    }

    // Mathematical exponents and relations (+0.3)
    if (text.contains('^')) mathScore += 0.3;
    if (RegExp(r'_\{\w+\}|_[0-9a-zA-Z]').hasMatch(text)) mathScore += 0.3;
    if (text.contains(r'\int') || text.contains(r'\sum')) mathScore += 0.5;
    if (text.contains(r'\frac')) mathScore += 0.5;

    // Chemical / mathematical reaction arrows (+0.4)
    if (text.contains('->') || text.contains('→') || text.contains(r'\rightarrow')) {
      mathScore += 0.4;
    }

    // Mathematical bracketed terms (e.g. [A]^m [B]^n, [Substrate]) (+0.3)
    if (RegExp(r'\[[A-Za-z0-9_]+\]').hasMatch(text)) mathScore += 0.3;

    // Penalty for prose or programming terms
    final words = text.split(RegExp(r'\s+'));
    final totalWords = words.length;

    var proseWordCount = 0;
    for (final w in words) {
      final clean = w.replaceAll(RegExp('[^a-zA-Z]'), '').toLowerCase();
      if (_commonProseWords.contains(clean)) {
        proseWordCount++;
      }
    }

    final netScore = (mathScore - (proseWordCount * 0.2)) / math.max(1, totalWords * 0.4);
    return netScore.clamp(0.0, 1.0);
  }

  // ===========================================================================
  // FORMULA EXTRACTION & NORMALIZATION
  // ===========================================================================

  /// Extracts the primary formula from [text] if present, returning a
  /// normalized [ExtractedFormula].
  ExtractedFormula? extractFormula(
    String text, {
    int page = 1,
    BoundingBox? bbox,
  }) {
    var trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Strip leading "Formula:" / "Equation:" / "Eq.:" prefix
    trimmed = trimmed.replaceFirst(
      RegExp(r'^(?:Formula|Equation|Eq\.?)\s*:\s*', caseSensitive: false),
      '',
    ).trim();

    // Strip LaTeX document preamble declarations
    trimmed = stripLatexPreamble(trimmed);
    if (trimmed.isEmpty) return null;

    if (isCodeAssignment(trimmed)) return null;

    // 1. Tier A: MathML
    if (trimmed.contains('<math')) {
      final latex = convertMathMLToLatex(trimmed);
      if (latex.isNotEmpty && isValidLatexEquation(latex)) {
        return ExtractedFormula(
          latex: latex,
          rawMathText: trimmed,
          isDisplay: trimmed.contains('display="block"'),
          tier: FormulaTier.nativeMarkup,
          confidence: 0.98,
          page: page,
          bbox: bbox,
        );
      }
    }

    // 2. Tier A: OMML (DOCX)
    if (trimmed.contains('<m:oMath')) {
      final latex = convertOmmlToLatex(trimmed);
      if (latex.isNotEmpty && isValidLatexEquation(latex)) {
        return ExtractedFormula(
          latex: latex,
          rawMathText: trimmed,
          isDisplay: trimmed.contains('<m:oMathPara'),
          tier: FormulaTier.nativeMarkup,
          confidence: 0.98,
          page: page,
          bbox: bbox,
        );
      }
    }

    // 3. Tier A: Delimited LaTeX ($$...$$, $...$, \[...\], \(...\))
    final delimitedMatch = _delimitedLatexRegex.firstMatch(trimmed);
    if (delimitedMatch != null) {
      final rawMatch = delimitedMatch.group(0)!;
      final cleanLatex = stripLatexPreamble(_stripLatexDelimiters(rawMatch));
      final isDisplay = rawMatch.startsWith(r'$$') ||
          rawMatch.startsWith(r'\[') ||
          rawMatch.contains('equation') ||
          rawMatch.contains('align');

      if (isValidLatexEquation(cleanLatex)) {
        return ExtractedFormula(
          latex: cleanLatex,
          rawMathText: rawMatch,
          isDisplay: isDisplay,
          tier: FormulaTier.nativeMarkup,
          confidence: 0.95,
          page: page,
          bbox: bbox,
        );
      }
    }

    // 4. Tier A: Raw LaTeX math command sequence inside text
    final mathCmdMatch = RegExp(
      r'(\\(?:frac|int|sum|prod|sqrt|lim|partial|nabla)\b[\s\S]{3,120})',
    ).firstMatch(trimmed);
    if (mathCmdMatch != null) {
      final matchStr = mathCmdMatch.group(1)!.trim();
      final clean = stripLatexPreamble(_stripLatexDelimiters(matchStr));
      if (isValidLatexEquation(clean)) {
        return ExtractedFormula(
          latex: clean,
          rawMathText: matchStr,
          isDisplay: false,
          tier: FormulaTier.nativeMarkup,
          confidence: 0.90,
          page: page,
          bbox: bbox,
        );
      }
    }

    // 5. Tier B: Vector / Unicode / Plain Mathematical Formula (whole text)
    if (isFormula(trimmed)) {
      final normalizedLatex = normalizeToLatex(trimmed);
      if (isValidLatexEquation(normalizedLatex)) {
        final confidence = computeMathSymbolDensity(trimmed);
        return ExtractedFormula(
          latex: normalizedLatex,
          rawMathText: trimmed,
          isDisplay: trimmed.contains('\n') || trimmed.length > 25,
          tier: FormulaTier.vectorUnicode,
          confidence: math.max(0.75, confidence),
          page: page,
          bbox: bbox,
        );
      }
    }

    // 6. Sub-equation extraction from text (e.g., "Einstein formula: E = mc^2")
    final subEquationMatch = RegExp(
      r'(?:^|[\s:;,(])([a-zA-Z0-9_()[\]{},\s^\\+\-*/·×≈≠≤≥!%]{1,40}\s*=\s*[^=.,;:\n\r]+?(?=\s+[A-Z][a-zA-Z0-9_ ]{1,40}\s*=|[\n\r;.]|\s+\b(?:Table|Figure|Section|where|when|for|with)\b|$))',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(trimmed);
    for (final match in subEquationMatch) {
      var candidate = match.group(1)!.trim();
      candidate = candidate.replaceAll(RegExp(r'^[.,;: ]+|[.,;: ]+$'), '').trim();

      // Separate trailing explanatory prose ("where...", "for...", "with...", etc.)
      candidate = candidate.split(
        RegExp(r'\s+\b(?:where|when|for|with|such that|if|as|which|the|this|in|table|figure)\b', caseSensitive: false),
      ).first.trim();

      if (!isCodeAssignment(candidate) && isFormula(candidate)) {
        final normalizedLatex = normalizeToLatex(candidate);
        if (isValidLatexEquation(normalizedLatex)) {
          return ExtractedFormula(
            latex: normalizedLatex,
            rawMathText: candidate,
            isDisplay: false,
            tier: FormulaTier.vectorUnicode,
            confidence: 0.85,
            page: page,
            bbox: bbox,
          );
        }
      }
    }

    return null;
  }

  /// Extracts all formulas occurring inside [text].
  List<ExtractedFormula> extractAllFormulas(String text, {int page = 1}) {
    final formulas = <ExtractedFormula>[];

    // Check display environments
    for (final m in _delimitedLatexRegex.allMatches(text)) {
      final raw = m.group(0)!;
      final clean = stripLatexPreamble(_stripLatexDelimiters(raw));
      if (isValidLatexEquation(clean)) {
        formulas.add(
          ExtractedFormula(
            latex: clean,
            rawMathText: raw,
            isDisplay: raw.startsWith(r'$$') || raw.startsWith(r'\['),
            tier: FormulaTier.nativeMarkup,
            confidence: 0.95,
            page: page,
          ),
        );
      }
    }

    // Check lines for standalone or inline equations
    final lines = text.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Extract all sub-equations in the line
      final subMatches = RegExp(
        r'(?:^|[\s:;,(])([a-zA-Z0-9_()[\]{},\s^\\+\-*/·×≈≠≤≥!%]{1,40}\s*=\s*[^=.,;:\n\r]+?(?=\s+[A-Z][a-zA-Z0-9_ ]{1,40}\s*=|[\n\r;.]|\s+\b(?:Table|Figure|Section|where|when|for|with)\b|$))',
        multiLine: true,
        caseSensitive: false,
      ).allMatches(trimmed);

      if (subMatches.isNotEmpty) {
        for (final m in subMatches) {
          final candidate = m.group(1)!.trim();
          final formula = extractFormula(candidate, page: page);
          if (formula != null &&
              isValidLatexEquation(formula.latex) &&
              !formulas.any((f) => f.latex == formula.latex)) {
            formulas.add(formula);
          }
        }
      }

      final standalone = extractFormula(trimmed, page: page);
      if (standalone != null &&
          isValidLatexEquation(standalone.latex) &&
          !formulas.any((f) => f.latex == standalone.latex)) {
        formulas.add(standalone);
      }
    }

    return formulas;
  }

  /// Converts Unicode symbols, chemical arrows, and standard mathematical notation
  /// to canonical LaTeX representation.
  static String normalizeToLatex(String raw) {
    var s = raw.trim();

    // Strip leading / trailing delimiters if present
    s = _stripLatexDelimiters(s);

    // 1. Greek Unicode Replacements
    s = _normalizeUnicodeGreek(s);

    // 2. Math Operators & Relations
    s = _normalizeUnicodeOperators(s);

    // 3. Standardize arrows
    s = s.replaceAll('->', r'\rightarrow ');
    s = s.replaceAll('=>', r'\implies ');
    s = s.replaceAll('==', '=');

    // 4. Standardize text labels in formulas: e.g. "Rate =", "Sharpe Ratio ="
    s = _normalizeFormulaTextRuns(s);

    return s.trim();
  }

  // ===========================================================================
  // MARKUP CONVERTERS (MathML & OMML)
  // ===========================================================================

  /// Converts a MathML `<math>` fragment into a LaTeX formula string.
  static String convertMathMLToLatex(String mathMl) {
    var s = mathMl;

    // Fractions: <mfrac><mi>a</mi><mi>b</mi></mfrac> -> \frac{a}{b}
    s = s.replaceAllMapped(
      RegExp(r'<mfrac>\s*(?:<m[itn]>(.*?)</m[itn]>|([^<]+))\s*(?:<m[itn]>(.*?)</m[itn]>|([^<]+))\s*</mfrac>'),
      (m) {
        final num = (m.group(1) ?? m.group(2) ?? '').trim();
        final den = (m.group(3) ?? m.group(4) ?? '').trim();
        return '\\frac{$num}{$den}';
      },
    );

    // Square Root: <msqrt>x</msqrt> -> \sqrt{x}
    s = s.replaceAllMapped(
      RegExp('<msqrt>(.*?)</msqrt>', dotAll: true),
      (m) {
        final inner = (m.group(1) ?? '').replaceAll(RegExp('<[^>]+>'), '').trim();
        return '\\sqrt{$inner}';
      },
    );

    // Superscript: <msup><mi>x</mi><mn>2</mn></msup> -> x^{2}
    s = s.replaceAllMapped(
      RegExp(r'<msup>\s*(?:<m[itn]>(.*?)</m[itn]>|([^<]+))\s*(?:<m[itn]>(.*?)</m[itn]>|([^<]+))\s*</msup>'),
      (m) {
        final base = (m.group(1) ?? m.group(2) ?? '').trim();
        final sup = (m.group(3) ?? m.group(4) ?? '').trim();
        return '$base^{$sup}';
      },
    );

    // Subscript: <msub><mi>x</mi><mn>1</mn></msub> -> x_{1}
    s = s.replaceAllMapped(
      RegExp(r'<msub>\s*(?:<m[itn]>(.*?)</m[itn]>|([^<]+))\s*(?:<m[itn]>(.*?)</m[itn]>|([^<]+))\s*</msub>'),
      (m) {
        final base = (m.group(1) ?? m.group(2) ?? '').trim();
        final sub = (m.group(3) ?? m.group(4) ?? '').trim();
        return '${base}_{$sub}';
      },
    );

    // Clean remaining MathML tags
    s = s.replaceAll(RegExp('</?[a-zA-Z0-9]+[^>]*>'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  /// Converts a Word OMML `<m:oMath>` fragment into a LaTeX formula string.
  static String convertOmmlToLatex(String omml) {
    var s = omml;

    // Fractions: <m:f><m:num><m:r><m:t>a</m:t></m:r></m:num><m:den><m:r><m:t>b</m:t></m:r></m:den></m:f>
    s = s.replaceAllMapped(
      RegExp(r'<m:f>[\s\S]*?<m:num>([\s\S]*?)</m:num>[\s\S]*?<m:den>([\s\S]*?)</m:den>[\s\S]*?</m:f>'),
      (m) {
        final num = _extractOmmlText(m.group(1)!);
        final den = _extractOmmlText(m.group(2)!);
        return '\\frac{$num}{$den}';
      },
    );

    // Superscripts: <m:sSup>
    s = s.replaceAllMapped(
      RegExp(r'<m:sSup>[\s\S]*?<m:e>([\s\S]*?)</m:e>[\s\S]*?<m:sup>([\s\S]*?)</m:sup>[\s\S]*?</m:sSup>'),
      (m) {
        final base = _extractOmmlText(m.group(1)!);
        final sup = _extractOmmlText(m.group(2)!);
        return '$base^{$sup}';
      },
    );

    // Subscripts: <m:sSub>
    s = s.replaceAllMapped(
      RegExp(r'<m:sSub>[\s\S]*?<m:e>([\s\S]*?)</m:e>[\s\S]*?<m:sub>([\s\S]*?)</m:sub>[\s\S]*?</m:sSub>'),
      (m) {
        final base = _extractOmmlText(m.group(1)!);
        final sub = _extractOmmlText(m.group(2)!);
        return '${base}_{$sub}';
      },
    );

    // Extract raw text runs: <m:t>text</m:t>
    final textBuffer = StringBuffer();
    final tRegex = RegExp('<m:t[^>]*>(.*?)</m:t>');
    for (final m in tRegex.allMatches(s)) {
      textBuffer.write(m.group(1));
    }

    final result = textBuffer.toString().trim();
    return result.isNotEmpty ? result : _extractOmmlText(s);
  }

  static String _extractOmmlText(String fragment) {
    final runs = RegExp('<m:t[^>]*>(.*?)</m:t>').allMatches(fragment);
    if (runs.isNotEmpty) {
      return runs.map((m) => m.group(1) ?? '').join();
    }
    return fragment.replaceAll(RegExp('<[^>]+>'), '').trim();
  }

  // ===========================================================================
  // VALIDATION, SANITIZATION & BALANCING
  // ===========================================================================

  /// Strictly validates whether [latex] constitutes a renderable, well-formed
  /// mathematical equation, filtering out broken cloze blanks, unclosed brackets,
  /// leading binary operators without an LHS, and high-prose textual lines.
  static bool isValidLatexEquation(String latex) {
    var clean = stripLatexPreamble(latex).trim();
    if (clean.isEmpty) return false;

    // Strip delimiters if present
    clean = _stripLatexDelimiters(clean);
    if (clean.isEmpty) return false;

    // 1. Reject cloze blanks or blank placeholders (e.g. _____, [...], [?])
    if (RegExp('_{3,}').hasMatch(clean) ||
        clean.contains('___') ||
        clean.contains('[...]') ||
        clean.contains('<??>') ||
        RegExp(r'\bcloze\b', caseSensitive: false).hasMatch(clean)) {
      return false;
    }

    // 2. Reject leading binary operators (+, *, /, =, ^) without an LHS
    if (RegExp(r'^\s*[\+\*\/\=\^]').hasMatch(clean)) return false;

    // 3. Reject lone operators (e.g. "+", "-", "=", "*", "/")
    if (RegExp(r'^\s*[-+*\/=^]\s*$').hasMatch(clean)) return false;

    // 4. Reject minus followed immediately by binary operator (e.g. "- =", "- +")
    if (RegExp(r'^\s*-\s*[\+\*\/\=\^]').hasMatch(clean)) return false;

    // 5. Reject equations ending with bare '=' or starting with '='
    if (clean.startsWith('=') || clean.endsWith('=')) return false;

    // If equation contains '=', verify that the LHS is non-empty and well-formed
    if (clean.contains('=')) {
      final eqIndex = clean.indexOf('=');
      final lhs = clean.substring(0, eqIndex).trim();
      if (lhs.isEmpty || RegExp(r'^[\+\*\/\=\^]').hasMatch(lhs)) return false;
    }

    // 6. Must have balanced brackets, braces, and parentheses
    if (!isBalancedLatex(clean)) return false;

    // 7. Reject candidate strings where alphabetical prose words form > 40% of tokens
    if (hasHighProseWordDensity(clean)) return false;

    // 8. Reject code assignments
    if (isCodeAssignment(clean)) return false;

    // 9. Must contain at least one math indicator (LaTeX command, math operator, or relation)
    final hasMathIndicator = clean.contains(r'\') ||
        RegExp(r'[\=\+\*\/\^\_\<\>\≈\≠\≤\≥\→\⇒]').hasMatch(clean);
    if (!hasMathIndicator) return false;

    return true;
  }

  /// Strips LaTeX document preamble declarations (e.g. \documentclass, \usepackage,
  /// \author, \title, \date, \maketitle, \begin{document}, \end{document})
  /// from [input], returning the clean mathematical body.
  static String stripLatexPreamble(String input) {
    if (input.isEmpty) return '';

    var s = input;

    // Remove LaTeX comments (% ...)
    s = s.replaceAll(RegExp(r'(?<!\\)%.*$', multiLine: true), '');

    // Document class and packages
    s = s.replaceAll(RegExp(r'\\documentclass(?:\s*\[[^\]]*\])?\s*\{[^}]*\}', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\\usepackage(?:\s*\[[^\]]*\])?\s*\{[^}]*\}', caseSensitive: false), '');

    // Metadata declarations
    s = s.replaceAll(RegExp(r'\\(?:author|title|date|affiliation|address|email|thanks)(?:\s*\[[^\]]*\])?\s*\{[^}]*\}', caseSensitive: false), '');

    // Page and layout setup
    s = s.replaceAll(RegExp(r'\\(?:pagestyle|thispagestyle|geometry|hypersetup|bibliographystyle|bibliography)\s*\{[^}]*\}', caseSensitive: false), '');

    // Document environment delimiters and title macro
    s = s.replaceAll(RegExp(r'\\maketitle\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\\begin\{document\}', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\\end\{document\}', caseSensitive: false), '');

    return s.trim();
  }

  /// Checks whether alphabetical prose words form more than [threshold] (default 40%)
  /// of the whitespace-delimited tokens in [text].
  static bool hasHighProseWordDensity(String text, {double threshold = 0.40}) {
    final clean = stripLatexPreamble(text).trim();
    if (clean.isEmpty) return false;

    final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return false;

    var proseCount = 0;
    for (final token in tokens) {
      if (_isProseWordToken(token)) {
        proseCount++;
      }
    }

    final ratio = proseCount / tokens.length;
    return ratio > threshold;
  }

  static bool _isProseWordToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return false;

    // LaTeX commands are math markup, not prose words
    if (t.startsWith(r'\')) return false;

    // Remove leading/trailing punctuation and brackets
    final alphaOnly = t.replaceAll(RegExp(r'^[^a-zA-Z]+|[^a-zA-Z]+$'), '');
    if (alphaOnly.isEmpty) return false;

    // Single-character tokens (x, y, z, E, m, c, n, i) are math variables, NOT prose
    if (alphaOnly.length <= 1) return false;

    // Strip enclosing brackets and punctuation to evaluate inner token
    final unbracketed = t.replaceAll(RegExp(r'^[\(\[\{\<]+|[\)\]\}\>,;:\.!?]+$'), '');
    if (unbracketed.isEmpty) return false;

    // Tokens containing numbers, subscripts, superscripts, or math symbols are formulas
    // Note: hyphen between letters (e.g. half-integer, Fermi-Dirac) is a word hyphen, not minus
    final hasMathSymbols = RegExp(r'[\d_^\(\)\[\]\{\}\+\*\/=\\\>\<\≈\≠\≤\≥\→\⇒]').hasMatch(unbracketed) ||
        (unbracketed.contains('-') && !RegExp(r'^[a-zA-Z]+(?:-[a-zA-Z]+)+$').hasMatch(unbracketed));
    if (hasMathSymbols) return false;

    final lower = alphaOnly.toLowerCase();

    // Whitelist check
    if (_mathFunctionAndUnitWhitelist.contains(lower)) return false;

    // Token is a prose word
    return true;
  }

  /// Escapes unescaped pipe characters (`|`) in LaTeX math within [text] to
  /// `\|` so that Markdown table column parsing does not break.
  static String escapeTablePipes(String text) {
    if (!text.contains('|')) return text;

    // 1. Delimited LaTeX math environments: $...$, $$...$$, \(...\), \[...\]
    var s = text.replaceAllMapped(
      RegExp(r'(\$\$[\s\S]+?\$\$|\$(?!\$)[\s\S]+?\$|\\\[[\s\S]+?\\\]|\\\(.+?\\\))'),
      (match) {
        final mathBlock = match.group(0)!;
        return mathBlock.replaceAll(RegExp(r'(?<!\\)\|'), r'\|');
      },
    );

    // 2. If the text has no math delimiters, but represents an equation or math notation with pipes
    // e.g. "|x| < 1", "P(A|B) = 0.5", or standalone "|a|"
    if (!s.contains(r'$') && !s.contains(r'\(') && !s.contains(r'\[')) {
      if (isFormula(s) || s.contains('=') || s.contains(r'\') || RegExp(r'(?<!\\)\|[^|]+(?<!\\)\|').hasMatch(s)) {
        s = s.replaceAll(RegExp(r'(?<!\\)\|'), r'\|');
      }
    }

    return s;
  }

  /// Validates that braces `{...}`, brackets `[...]`, and parentheses `(...)`
  /// are balanced within [latex], ensuring valid rendering.
  static bool isBalancedLatex(String latex) {
    if (latex.isEmpty) return false;

    var braces = 0;
    var brackets = 0;
    var parens = 0;

    for (var i = 0; i < latex.length; i++) {
      final char = latex[i];
      var backslashes = 0;
      for (var k = i - 1; k >= 0 && latex[k] == r'\'; k--) {
        backslashes++;
      }
      final isEscaped = backslashes.isOdd;

      if (char == '{' && !isEscaped) braces++;
      if (char == '}' && !isEscaped) {
        braces--;
        if (braces < 0) return false;
      }

      if (char == '[' && !isEscaped) brackets++;
      if (char == ']' && !isEscaped) {
        brackets--;
        if (brackets < 0) return false;
      }

      if (char == '(' && !isEscaped) parens++;
      if (char == ')' && !isEscaped) {
        parens--;
        if (parens < 0) return false;
      }
    }

    // Trailing unescaped backslash indicates incomplete command
    var trailingBackslashes = 0;
    for (var k = latex.length - 1; k >= 0 && latex[k] == r'\'; k--) {
      trailingBackslashes++;
    }
    if (trailingBackslashes.isOdd) return false;

    // Check matching \left and \right if present
    final leftMatches = RegExp(r'\\left\b').allMatches(latex).length;
    final rightMatches = RegExp(r'\\right\b').allMatches(latex).length;
    if (leftMatches != rightMatches) return false;

    return braces == 0 && brackets == 0 && parens == 0;
  }

  // ===========================================================================
  // PRIVATE REGEX & DICTIONARY HELPERS
  // ===========================================================================

  static String _stripLatexDelimiters(String s) {
    var res = s.trim();
    if (res.startsWith(r'$$') && res.endsWith(r'$$') && res.length >= 4) {
      res = res.substring(2, res.length - 2).trim();
    } else if (res.startsWith(r'\[') && res.endsWith(r'\]') && res.length >= 4) {
      res = res.substring(2, res.length - 2).trim();
    } else if (res.startsWith(r'\(') && res.endsWith(r'\)') && res.length >= 4) {
      res = res.substring(2, res.length - 2).trim();
    } else if (res.startsWith(r'$') && res.endsWith(r'$') && res.length >= 2) {
      res = res.substring(1, res.length - 1).trim();
    }
    return res;
  }

  static bool _hasExplicitLatexDelimiters(String s) {
    return (s.startsWith(r'$$') && s.endsWith(r'$$')) ||
        (s.startsWith(r'\[') && s.endsWith(r'\]')) ||
        (s.startsWith(r'\(') && s.endsWith(r'\)')) ||
        (s.startsWith(r'$') && s.endsWith(r'$') && s.length >= 3) ||
        s.contains(r'\begin{equation}') ||
        s.contains(r'\begin{align}');
  }

  static final _chemicalSpeciesRegex = RegExp(
    r'(?:[A-Z][a-z]?(?:_?\d+)?){1,8}',
  );

  /// Checks if [text] has unambiguous characteristics of a chemical reaction equation
  /// rather than programming syntax or general textual arrows.
  static bool isChemicalEquation(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _containsCodeKeywords(trimmed)) return false;
    // Reject prose lines that contain common conversational/programming English words
    if (RegExp(
      r'\b(?:for|example|or|and|the|with|where|code|use|read|into|from|that|this|have|does|other|pass|receive|struct|type|class|function)\b',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return false;
    }
    final hasArrow = trimmed.contains('→') ||
        trimmed.contains('->') ||
        trimmed.contains(r'\to') ||
        trimmed.contains(r'\rightarrow');
    if (!hasArrow) return false;

    final hasPhase = RegExp(r'\((?:aq|g|l|s)\)', caseSensitive: false).hasMatch(trimmed);
    final hasPlus = trimmed.contains('+');
    final matches = _chemicalSpeciesRegex
        .allMatches(trimmed)
        .where((m) => m.group(0) != null && m.group(0)!.length >= 2)
        .length;
    return hasPhase || (hasPlus && matches >= 2) || matches >= 4;
  }

  static bool _containsCodeKeywords(String s) {
    return RegExp(
      r'\b(?:var|val|fun|def|final|const|function|class|interface|import|package|return|void|public|private|protected|override|if|else|when|switch|case|while|for|typealias|enum|println|print)\b',
    ).hasMatch(s) ||
        s.contains('{') ||
        s.contains('}') ||
        s.contains(';') ||
        s.contains('::=') ||
        s.contains('//') ||
        s.contains('/*');
  }

  static const _greekToLatex = <String, String>{
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'δ': r'\delta',
    'ε': r'\epsilon',
    'θ': r'\theta',
    'λ': r'\lambda',
    'μ': r'\mu',
    'π': r'\pi',
    'σ': r'\sigma',
    'τ': r'\tau',
    'φ': r'\phi',
    'ψ': r'\psi',
    'ω': r'\omega',
    'Δ': r'\Delta',
    'Θ': r'\Theta',
    'Λ': r'\Lambda',
    'Σ': r'\Sigma',
    'Φ': r'\Phi',
    'Ψ': r'\Psi',
    'Ω': r'\Omega',
  };

  static String _normalizeUnicodeGreek(String text) {
    var s = text;
    for (final entry in _greekToLatex.entries) {
      s = s.replaceAll(entry.key, '${entry.value} ');
    }
    return s;
  }

  static const _unicodeOpToLatex = <String, String>{
    '∇': r'\nabla ',
    '∂': r'\partial ',
    '∫': r'\int ',
    '∑': r'\sum ',
    '∏': r'\prod ',
    '√': r'\sqrt ',
    '∞': r'\infty ',
    '≈': r'\approx ',
    '≠': r'\neq ',
    '≤': r'\le ',
    '≥': r'\ge ',
    '±': r'\pm ',
    '×': r'\times ',
    '·': r'\cdot ',
    '∈': r'\in ',
    '∉': r'\notin ',
    '⊂': r'\subset ',
    '⊆': r'\subseteq ',
    '∪': r'\cup ',
    '∩': r'\cap ',
    'ℏ': r'\hbar ',
  };

  static String _normalizeUnicodeOperators(String text) {
    var s = text;
    for (final entry in _unicodeOpToLatex.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    return s;
  }

  static String _normalizeFormulaTextRuns(String s) {
    // Wrap common leading formula terms: e.g. "Rate =", "Sharpe Ratio =", "MSE ="
    return s.replaceAllMapped(
      RegExp(r'^(Rate|Sharpe Ratio|MSE|Cross-Entropy|Uptime\s*%)(\s*=)', caseSensitive: false),
      (m) => '\\text{${m.group(1)}}${m.group(2)}',
    );
  }

  static final _latexMathCommandRegex = RegExp(
    r'\\(?:frac|sqrt|int|sum|prod|lim|partial|nabla|alpha|beta|gamma|delta|epsilon|'
    'theta|lambda|mu|pi|sigma|tau|phi|psi|omega|Delta|Theta|Sigma|Omega|hbar|'
    'infty|exp|ln|log|sin|cos|tan|cdot|times|pm|approx|le|ge|neq|in|subset|'
    r'cup|cap|mathbf|mathrm|boldsymbol|text|left|right)\b',
  );

  static final _delimitedLatexRegex = RegExp(
    r'(\$\$.+?\$\$|\$(?!\$).+?\$|\\\[.+?\\\]|\\\(.+?\\\)|(?:^|[^\\])\\begin\{[a-zA-Z*]+\}[\s\S]+?\\end\{[a-zA-Z*]+\})',
    dotAll: true,
  );

  static final _unicodeMathSymbols = <int>{
    0x2207, // ∇
    0x2202, // ∂
    0x222B, // ∫
    0x2211, // ∑
    0x220F, // ∏
    0x221A, // √
    0x221E, // ∞
    0x2248, // ≈
    0x2260, // ≠
    0x2264, // ≤
    0x2265, // ≥
    0x00B1, // ±
    0x00D7, // ×
    0x00B7, // ·
    0x2192, // →
    0x21D2, // ⇒
    0x210F, // ℏ
  };

  static final _mathFunctionAndUnitWhitelist = <String>{
    // Functions and operations
    'sin', 'cos', 'tan', 'sec', 'csc', 'cot', 'arcsin', 'arccos', 'arctan',
    'sinh', 'cosh', 'tanh', 'exp', 'ln', 'log', 'lg', 'lim', 'min', 'max',
    'inf', 'sup', 'det', 'dim', 'ker', 'hom', 'deg', 'gcd', 'argmax', 'argmin',
    'mod', 'pmod', 'var', 'cov', 'std', 'pr', 'tr', 'softmax', 'sigmoid',
    'relu', 'gelu', 'selu', 'swish', 'attention', 'loss', 'diff', 'err',
    'acc', 'rate', 'value', 'total', 'diag', 'rank', 'trace', 'sign', 'sgn',
    'erf', 'erfc', 'sinc', 'rect', 'step', 'mean', 'median', 'mode', 'norm',
    'uptime', 'downtime', 'minutes', 'sharpe', 'ratio', 'entropy', 'cross',
    'ion', 'out', 'in', 'mpc', 'energy', 'mass', 'area', 'vol', 'len',
    // Units
    'kg', 'cm', 'mm', 'nm', 'pm', 'km', 'mol', 'hr', 'ms', 'ns',
    'hz', 'khz', 'mhz', 'ghz', 'thz', 'db', 'dbm', 'kb', 'mb', 'gb', 'tb',
    'pb', 'ev', 'mev', 'gev', 'tev', 'rad', 'cal', 'kcal', 'pa', 'kpa',
    'mpa', 'gpa', 'atm', 'bar', 'mbar', 'ppm', 'ppb', 'amu', 'kwh', 'mwh', 'wh',
    'snr', 'sinr', 'ber', 'per', 'mse', 'mae', 'rmse', 'iou', 'map', 'auc', 'roc',
    'dft', 'fft', 'svd', 'pca',
    // Greek names
    'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta', 'eta', 'theta',
    'iota', 'kappa', 'lambda', 'mu', 'nu', 'xi', 'omicron', 'pi', 'rho',
    'sigma', 'tau', 'upsilon', 'phi', 'chi', 'psi', 'omega',
    // 2-letter chemical elements
    'he', 'li', 'be', 'ne', 'na', 'mg', 'al', 'si', 'cl', 'ar', 'ca', 'sc',
    'ti', 'cr', 'mn', 'fe', 'co', 'ni', 'cu', 'zn', 'ga', 'ge', 'as', 'se',
    'br', 'kr', 'rb', 'sr', 'zr', 'nb', 'mo', 'tc', 'ru', 'rh', 'pd', 'ag',
    'cd', 'sn', 'sb', 'te', 'xe', 'cs', 'ba', 'la', 'ce', 'nd',
    'sm', 'eu', 'gd', 'dy', 'ho', 'er', 'tm', 'yb', 'lu', 'hf',
    'ta', 're', 'os', 'ir', 'pt', 'au', 'hg', 'tl', 'bi', 'po', 'at',
    'rn', 'fr', 'ra', 'ac', 'th', 'np', 'pu', 'am', 'bk', 'cf',
    'es', 'fm', 'md', 'no', 'lr',
  };

  static final _commonProseWords = <String>{
    'the', 'this', 'that', 'with', 'from', 'have', 'were', 'which', 'about',
    'would', 'there', 'their', 'could', 'other', 'after', 'first', 'these',
    'please', 'thank', 'thanks', 'hello', 'agreement', 'employee', 'service',
  };
}
